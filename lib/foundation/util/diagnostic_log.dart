// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:collection';

/// 本地诊断日志：只在内存里保留最近若干条错误，供用户**主动**导出分享。
///
/// 为什么不上报：应用的核心承诺是「数据不出设备」。此前 release 下的未捕获
/// 异常只走 debugPrint —— 用户看到白屏/闪退，开发者一无所知。折中方案是
/// 本地滚动记录 + 设置页「导出诊断」（用户主动通过系统分享面板发给我们），
/// 既不违反承诺，又让偶发崩溃可被定位。
class DiagnosticLog {
  DiagnosticLog._();

  /// 保留条数上限（环形）。日志是内存对象，无上限会在长会话里一直涨。
  static const int maxEntries = 50;

  static final Queue<_Entry> _entries = Queue<_Entry>();

  static void record(Object error, [StackTrace? stackTrace]) {
    final now = DateTime.now();
    final buffer = StringBuffer('[${now.toIso8601String()}] $error');
    if (stackTrace != null) {
      // 栈只留前若干行：完整栈对定位足够了，太长反而没人看
      final lines = stackTrace.toString().split('\n');
      buffer.write('\n  ${lines.take(12).join('\n  ')}');
    }
    _entries.addLast(_Entry(now, buffer.toString()));
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  /// 已记录的条数。
  static int get length => _entries.length;

  static bool get isEmpty => _entries.isEmpty;

  /// 导出为可直接贴进 issue 的文本（最新在后）。
  static String export() {
    if (_entries.isEmpty) return '';
    final buffer = StringBuffer('BooruNova diagnostics\n');
    buffer.writeln('entries: ${_entries.length}');
    buffer.writeln('-' * 40);
    for (final entry in _entries) {
      buffer.writeln(entry.text);
    }
    return buffer.toString();
  }

  /// 导出文件名（时间戳避免多次导出互相覆盖）。
  static String exportFileName() =>
      'boorunova_diagnostics_${DateTime.now().millisecondsSinceEpoch}.txt';

  static void clear() => _entries.clear();
}

class _Entry {
  _Entry(this.at, this.text);
  final DateTime at;
  final String text;
}
