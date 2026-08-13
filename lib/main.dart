import 'dart:async';

import 'package:boorunova/foundation/database/hive_setup.dart';
import 'package:boorunova/presentation/booru_nova.dart';
import 'package:boorunova/presentation/provider/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 仅首帧必需的数据在此 await（Hive 是本地 IO，约几十毫秒）。
  // PackageInfo / 方向锁定移出关键路径，runApp 后异步完成，缩短冷启动白屏。
  await HiveSetup.init();

  final container = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BooruNova(),
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
