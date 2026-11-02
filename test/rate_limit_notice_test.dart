import 'package:boorunova/presentation/l10n/app_strings.dart';
import 'package:boorunova/presentation/widgets/common/download_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 限流提示（OPT §3.8）的节流与安全性。
///
/// 批量下载并发 3–6 个条目，服务端限流时它们几乎同时命中 429。逐条弹提示会
/// 排成一长串、下载早就结束了提示还在刷——所以同一批里只说一次。
void main() {
  setUp(resetRateLimitNoticeThrottle);

  Future<int> countNotices(
    WidgetTester tester, {
    required List<DateTime> times,
  }) async {
    var shown = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                for (final at in times) {
                  showRateLimitNotice(
                    context,
                    const Duration(seconds: 3),
                    now: at,
                  );
                }
                shown = times.length;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(shown, times.length);
    return find
        .text(T.rateLimitedRetry(3))
        .evaluate()
        .length;
  }

  testWidgets('有 Scaffold 时确实弹出提示', (tester) async {
    final visible = await countNotices(tester, times: [DateTime(2026, 3, 1, 12)]);
    expect(visible, 1);
  });

  testWidgets('没有 Scaffold 时不崩（静默跳过）', (tester) async {
    // MaterialApp 会在根上装一个 ScaffoldMessenger，但**没有 Scaffold**：
    // 此时 showSnackBar 会因 _scaffolds.isNotEmpty 断言失败。修复前这里直接崩。
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox.shrink(),
    ));
    showRateLimitNotice(
      tester.element(find.byType(SizedBox)),
      const Duration(seconds: 2),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });
  group('节流判断（纯函数，SnackBar 会排队所以只能这么测）', () {
    test('第一次允许，窗口内一律丢掉，过了窗口再允许', () {
      final base = DateTime(2026, 3, 1, 12);
      expect(consumeRateLimitNoticeSlot(base), isTrue, reason: '第一次要提示');
      expect(
        consumeRateLimitNoticeSlot(base.add(const Duration(milliseconds: 200))),
        isFalse,
      );
      expect(
        consumeRateLimitNoticeSlot(
          base.add(kRateLimitNoticeGap - const Duration(milliseconds: 1)),
        ),
        isFalse,
        reason: '刚好差 1ms 仍在窗口内',
      );
      expect(
        consumeRateLimitNoticeSlot(base.add(kRateLimitNoticeGap)),
        isTrue,
        reason: '窗口一过就该允许（长批量下载需要更新状态）',
      );
    });
  });
}
