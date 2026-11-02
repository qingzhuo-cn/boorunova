import 'package:boorunova/presentation/widgets/common/brand_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 生成应用品牌图标资源（flutter test --update-goldens 运行后输出到 test/goldens/）。
///
/// 绘制源在 lib/presentation/widgets/common/brand_icon.dart（应用内启动
/// 过渡复用同一 Widget）。改图形后需重跑本测试刷新 golden，并同步
/// 缩放部署到 android/app/src/main/res（见仓库脚本/说明）。
///
/// 三个变体：
///  - ic_launcher.png    带圆角底的完整图标（各密度 mipmap 从它缩放）
///  - ic_launcher_fg.png 自适应图标前景（透明底、无底框，图形占中央 61%）
///  - splash_logo.png    启动画面居中 logo（透明底、图形铺满画布）
void main() {
  testWidgets('generate brand icon assets', (tester) async {
    const canvas = 1024.0;
    tester.view.physicalSize = const Size(canvas, canvas);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<void> snap(String name, Widget child) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: ValueKey(name),
          child: SizedBox(width: canvas, height: canvas, child: child),
        ),
      );
      await expectLater(
        find.byKey(ValueKey(name)),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    // 1) 完整圆角图标
    await snap('ic_launcher', const FittedBox(child: BrandIcon()));

    // 2) 自适应前景：透明底、无圆角方框（背景由渐变 vector 提供）
    await snap(
      'ic_launcher_fg',
      const Center(
        child: SizedBox(
          width: canvas * 0.61,
          height: canvas * 0.61,
          child: FittedBox(child: BrandIcon(withBackground: false)),
        ),
      ),
    );

    // 3) 启动 logo：透明底的图形，铺满整块画布。
    //    native splash 里按 200dp 绘制（见 launch_background.xml 的 layer 尺寸），
    //    与 BrandSplash 的 200dp 画布一一对应，原生 splash 交给品牌过渡时
    //    图形尺寸不会跳变。
    await snap(
      'splash_logo',
      const FittedBox(child: BrandIcon(withBackground: false)),
    );
  });
}
