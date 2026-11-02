import 'package:boorunova/foundation/util/diagnostic_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// OPT 4.3 的守卫：本地滚动诊断日志有上限、可导出、可清空。
void main() {
  setUp(DiagnosticLog.clear);
  tearDown(DiagnosticLog.clear);

  test('没有记录时导出为空串', () {
    expect(DiagnosticLog.isEmpty, isTrue);
    expect(DiagnosticLog.export(), isEmpty);
  });

  test('记录错误与栈，导出里能同时看到', () {
    DiagnosticLog.record('boom', StackTrace.current);
    final text = DiagnosticLog.export();
    expect(text, contains('boom'));
    expect(text, contains('entries: 1'));
    expect(text, contains('diagnostics'));
  });

  test('超出上限后丢最旧的，长度恒定', () {
    for (var i = 0; i < DiagnosticLog.maxEntries + 10; i++) {
      DiagnosticLog.record('e$i');
    }
    expect(DiagnosticLog.length, DiagnosticLog.maxEntries);
    final text = DiagnosticLog.export();
    expect(text, contains('e${DiagnosticLog.maxEntries + 9}'),
        reason: '最新的必须在');
    expect(text.contains('e0\n'), isFalse, reason: '最旧的必须被丢掉');
  });

  test('clear 清空', () {
    DiagnosticLog.record('x');
    DiagnosticLog.clear();
    expect(DiagnosticLog.isEmpty, isTrue);
  });

  test('导出文件名带时间戳，不互相覆盖', () {
    expect(DiagnosticLog.exportFileName(), startsWith('boorunova_diagnostics_'));
    expect(DiagnosticLog.exportFileName(), endsWith('.txt'));
  });
}
