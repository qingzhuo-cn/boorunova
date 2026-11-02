// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

class HiveSetup {
  static const String serversBoxName = 'servers';
  static const String settingsBoxName = 'settings';

  static String _dirPath = '';

  /// 本次启动是否从损坏的 box 里恢复过。UI 可据此提示用户「有本地数据已损坏
  /// 并隔离」，而不是让用户以为数据凭空消失。
  static bool recoveredFromCorruption = false;

  /// [dirPath] 仅供测试注入临时目录；生产路径由 path_provider 决定
  /// （测试环境下 path_provider 会落到真实用户目录，不能真去写）。
  static Future<void> init({String? dirPath}) async {
    final dir = dirPath ?? (await getApplicationDocumentsDirectory()).path;
    _dirPath = dir;
    Hive.init(_dirPath);
    await _openBoxes();
  }

  /// 清掉跨用例残留的进程内状态。
  @visibleForTesting
  static void resetForTest() {
    _dirPath = '';
    recoveredFromCorruption = false;
  }

  static Future<void> _openBoxes() async {
    // 串行打开：并行打开时一个损坏会让另一个半开，Hive 的状态更难收拾。
    await _openBox(serversBoxName);
    await _openBox(settingsBoxName);
  }

  /// 打开单个 box；整体损坏时把文件**改名留证**后重建空 box。
  ///
  /// 此前这里是裸 `openBox`：box 一旦损坏，启动阶段直接抛 HiveError，
  /// `main` 的 `await HiveSetup.init()` 又没有 try/catch，应用永远停在白屏，
  /// 用户只能「清除应用数据」——那等于把还能人工找回的文件一起判死刑。
  static Future<void> _openBox(String name) async {
    try {
      // crashRecovery 让 Hive 尽量跳过损坏的帧，而不是整个 box 打不开。
      await Hive.openBox(name, crashRecovery: true);
      return;
    } catch (_) {
      // 只关**这一个** box。这里不能 Hive.close()：它会关掉所有已注册的 box，
      // 而 _openBoxes 先开 servers 再开 settings —— settings 损坏时 servers
      // 会被连带关闭且永不重开，此后每次 HiveSetup.serversBox 都抛
      // "Box not found"，而 init() 又不抛错、降级页也不出现，
      // 用户面对的是「服务器列表整个会话全坏」。
      if (Hive.isBoxOpen(name)) {
        try {
          await Hive.box(name).close();
        } catch (_) {}
      }
      _quarantine(name);
      recoveredFromCorruption = true;
      // 重建空 box：应用能起来，比白屏强；原文件以 .corrupt.<ts> 保留在原地。
      await Hive.openBox(name);
    }
  }

  static void _quarantine(String name) {
    if (_dirPath.isEmpty) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    // .hive 与 .hivec 必须一起隔离：只改 .hive 时残留的 .hivec（compact 的
    // 中间文件）会在下次 open 时被当成有效数据，损坏的 box 直接复活。
    for (final suffix in const ['.hive', '.hivec']) {
      final file = File('$_dirPath${Platform.pathSeparator}$name$suffix');
      if (!file.existsSync()) continue;
      final target = '${file.path}.corrupt.$stamp';
      try {
        file.renameSync(target);
        continue;
      } catch (e) {
        // 改名失败（权限/被占用）不能让启动流程崩掉，但必须留下线索
        debugPrint('HiveSetup: rename $name$suffix failed: $e');
      }
      // 实测：帧头级损坏时 hive_ce 会在 _manager.open 抛错，而它只对已构造
      // 好的 box 调 close()（此时 newBox 还是 null）——半开 backend 的文件
      // 句柄被永久泄漏，Windows 下表现为「另一个程序正在使用此文件」。
      // 于是改名必然失败，直接重建又会再次抛错、启动降级页出现。
      // 退路：先复制一份留证，再把原文件清空——空文件是合法的空 box，
      // 随后 openBox 必然成功，用户拿回可用应用，证据也仍在磁盘上。
      try {
        file.copySync(target);
        file.writeAsBytesSync(const <int>[], flush: true);
      } catch (e2) {
        debugPrint('HiveSetup: neutralize $name$suffix failed: $e2');
      }
    }
  }

  /// 启动后在后台 compact 一次。
  ///
  /// box 文件只增不减：长会话里反复 add/remove（下载记录、浏览历史）会让
  /// 无效帧占比越来越高，文件跟着膨胀。compact 把有效数据重写一遍。
  ///
  /// 只在启动时做一次、失败静默——这是后台优化，不该挡住启动路径。
  static Future<void> compactInBackground() async {
    for (final name in const [serversBoxName, settingsBoxName]) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        await Hive.box(name).compact();
      } catch (e) {
        debugPrint('HiveSetup: compact $name failed: $e');
      }
    }
  }

  /// 把内存里的待写数据落盘。App 进入后台时调用，减少进程被杀导致丢数据。
  static Future<void> flush() async {
    for (final name in const [serversBoxName, settingsBoxName]) {
      if (!Hive.isBoxOpen(name)) continue;
      try {
        await Hive.box(name).flush();
      } catch (_) {
        // flush 失败不影响前台使用
      }
    }
  }

  static Box get serversBox => Hive.box(serversBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}
