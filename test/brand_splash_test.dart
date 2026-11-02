import 'package:boorunova/presentation/widgets/common/brand_icon.dart';
import 'package:boorunova/presentation/widgets/common/brand_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 启动过渡的行为约束：四颗新星要真的逐帧往里飞，播完必须自己收尾，
/// 且全程不抢触摸（否则启动瞬间点不动界面）。
void main() {
  Future<void> pumpSplash(
    WidgetTester tester, {
    required void Function() onFinished,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const SizedBox.expand(),
            BrandSplash(onFinished: onFinished, dark: dark),
          ],
        ),
      ),
    );
  }

  double flightOf(WidgetTester tester) =>
      tester.widget<BrandIcon>(find.byType(BrandIcon)).flight;

  testWidgets('新星从环外飞入：flight 单调推进，落位后收尾', (tester) async {
    var finished = false;
    await pumpSplash(tester, onFinished: () => finished = true);

    // 起手：四颗星还在环外（flight 接近 0），而不是直接摆成图标。
    expect(flightOf(tester), 0.0);

    await tester.pump(const Duration(milliseconds: 90));
    final appear = flightOf(tester);
    expect(appear, greaterThan(0));
    expect(appear, lessThan(0.2));

    await tester.pump(const Duration(milliseconds: 400));
    final mid = flightOf(tester);
    expect(mid, greaterThan(appear));
    expect(mid, lessThan(1.0));

    // 落位：flight 收敛到 1，图形与静态图标完全一致。
    await tester.pump(const Duration(milliseconds: 450));
    expect(flightOf(tester), 1.0);
    expect(finished, isFalse, reason: '淡出这一拍还没走完');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('过渡层不拦交互', (tester) async {
    await pumpSplash(tester, onFinished: () {});
    expect(
      find.descendant(
        of: find.byType(BrandSplash),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('深色场景用提亮配色', (tester) async {
    await pumpSplash(tester, onFinished: () {}, dark: true);
    expect(tester.widget<BrandIcon>(find.byType(BrandIcon)).onDark, isTrue);
    expect(
      tester.widget<BrandIcon>(find.byType(BrandIcon)).withBackground,
      isFalse,
    );
  });
}
