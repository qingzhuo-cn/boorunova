// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:async';

import 'package:boorunova/data/repository/server/user_server_repo.dart';
import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/foundation/util/diagnostic_log.dart';
import 'package:boorunova/foundation/util/image_cache_manager.dart';
import 'package:boorunova/presentation/booru_nova.dart';
import 'package:boorunova/presentation/provider/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 内存图片缓存上限（OPT §2.1）：必须在 runApp 之前设好，否则首屏就会按
  // Flutter 的默认上限（1000 张 / 100MB）开始积累解码后的位图。
  ImageCacheManager.configureMemoryCache();

  // 全局错误出口。此前全项目一个都没有：release 下未捕获异常只留在系统日志，
  // 用户看到的是白屏或闪退，开发者一无所知。这里先保证「不静默」。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    // 同时留在本地滚动日志里：release 下 debugPrint 没人看得到，
    // 用户可以在设置页主动导出诊断（数据不出设备）。
    DiagnosticLog.record(details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('未捕获异步异常: $error\n$stack');
    DiagnosticLog.record(error, stack);
    return true;
  };

  // Hive 是首帧必需的数据，但**不能**让它把应用锁死在启动前：
  // 一旦 box 损坏或磁盘异常，旧的裸 await 会让 runApp 永不执行 —— 永久白屏，
  // 用户只能清除应用数据。这里把失败收起来交给 UI 渲染降级页。
  Object? bootError;
  try {
    await HiveSetup.init();
    // 凭据必须在首帧之前就位：home_page 的第一次请求就要带它们，晚一步会以
    // 未认证身份先打一枪（部分站点直接 401）。里面含一次性明文迁移。
    try {
      await UserServerRepo.initCredentials();
    } catch (e) {
      // 安全存储不可用（设备策略 / Keystore 密钥失效）不能让应用起不来：
      // 凭据停在「未加载」状态，Hive 里的旧明文也保持原样（迁移是写后删）。
      debugPrint('凭据初始化失败: $e');
      DiagnosticLog.record(e, StackTrace.current);
    }
    // 首帧不等它：compact 是低频后台维护，失败也不影响使用
    unawaited(HiveSetup.compactInBackground());
    // 磁盘图片缓存超过上限时按 LRU 清最旧的（OPT §2.2）。同样不等它：
    // 这是缓存治理，晚几百毫秒没有任何影响，但绝不能拖慢首帧。
    unawaited(
      Future<void>.delayed(const Duration(seconds: 3))
          .then((_) => ImageCacheManager.enforceLimit())
          .then((plan) {
        if (plan.toDelete.isNotEmpty) {
          debugPrint(
              '图片缓存清理：删除 ${plan.toDelete.length} 个，释放 ${plan.freedBytes} 字节');
        }
      }).catchError((Object e) {
        debugPrint('图片缓存治理失败: $e');
      }),
    );
  } catch (e) {
    bootError = e;
  }

  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: BooruNova(bootError: bootError),
    ),
  );

  // 首帧渲染后再填充版本号（StateProvider 更新会通知监听方，无需 override）
  unawaited(PackageInfo.fromPlatform().then((info) {
    container.read(appVersionProvider.notifier).state = info.version;
  }));

  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]));
}
