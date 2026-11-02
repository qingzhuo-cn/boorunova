// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'dart:ui';

import 'package:boorunova/presentation/provider/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全应用共享的模糊滤镜：只创建一次引擎侧滤镜对象，
/// 供所有玻璃表面复用，避免每次 build 重建滤镜带来的合成开销。
final ImageFilter glassBlurFilter = ImageFilter.blur(sigmaX: 18, sigmaY: 18);

/// 液态玻璃容器：背景实时模糊 + 半透明渐变填充 + 高光描边。
///
/// 性能约束：
/// - 只用于悬浮在滚动内容之上的少量静态部件（底栏/顶栏/操作条），
///   绝不放进滚动列表项里，否则每帧重算模糊会拖垮瀑布流滚动。
/// - 「减少动画」开启时跳过 [BackdropFilter]（实时模糊是玻璃最贵的部分），
///   退化为高不透明度实色表面，低端设备依然流畅。
class GlassContainer extends ConsumerWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
    this.tint,
    this.fillOpacity,
    this.blur = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  /// 覆盖默认底色：用于沉浸式查看器等需要固定深色玻璃的界面
  /// （查看器背景恒为黑色，浅色主题下若用白色玻璃会破坏氛围）。
  final Color? tint;

  /// 覆盖填充不透明度（默认见 [build]）。只改透明度不改底色：
  /// 侧栏里每一格都要比整块抽屉面板更透一点，才能读成「浮在上面的玻璃」。
  final double? fillOpacity;

  /// 是否自己再叠一层 [BackdropFilter]。
  ///
  /// 用于「上层已经有玻璃」的场景（例如抽屉里的菜单项）：抽屉自身已经
  /// 模糊了下层内容，再模糊一次采样的还是那层模糊结果，视觉几乎没有变化，
  /// 却要多付 N 次模糊的合成开销。此时传 false，只保留玻璃的填充/描边/高光。
  final bool blur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final skipBlur =
        ref.watch(settingsProvider.select((s) => s.reduceAnimations));

    final base = (tint ?? (dark ? Colors.black : colorScheme.surface))
        .withOpacity(fillOpacity ?? (skipBlur ? 0.92 : 0.55));
    final sheen = Colors.white.withOpacity(dark ? 0.10 : 0.30);
    final stroke = Colors.white.withOpacity(dark ? 0.14 : 0.50);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.fromBorderSide(BorderSide(color: stroke, width: 0.8)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(sheen, base),
            base,
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (skipBlur || !blur) return decorated;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: glassBlurFilter,
        child: decorated,
      ),
    );
  }
}

/// 液态玻璃侧栏（Drawer / endDrawer 面板）。
///
/// 高度撑满、只圆右侧边缘（贴合从侧边滑出的形态），背景实时模糊，
/// 让抽屉滑出时透出下层滚动内容，与底栏/顶栏的玻璃语言一致。
/// 同样遵循「减少动画」降级与共享模糊单例的约束。
class GlassDrawer extends ConsumerWidget {
  const GlassDrawer({super.key, required this.child, this.right = false});

  final Widget child;

  /// 是否从右侧滑出（endDrawer）。左侧抽屉圆右缘，右侧抽屉圆左缘。
  final bool right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    final skipBlur =
        ref.watch(settingsProvider.select((s) => s.reduceAnimations));

    // 侧栏底色：浅色用高反差的白玻璃，深色用黑玻璃，均半透明。
    // 0.62 → 0.52：抽屉里的每个菜单项现在自己也是一块玻璃，面板再压得
    // 那么实，下面那层模糊内容就透不出来，菜单项会和面板糊成同一种颜色。
    // 让面板更透一点，下层滚动内容才在菜单项背后留下可被「折射」的纹理。
    final base = (dark ? Colors.black : colorScheme.surface)
        .withOpacity(skipBlur ? 0.94 : 0.52);
    final sheen = Colors.white.withOpacity(dark ? 0.08 : 0.25);
    final stroke = Colors.white.withOpacity(dark ? 0.12 : 0.40);

    final radius = BorderRadius.only(
      topLeft: Radius.circular(right ? 20 : 0),
      topRight: Radius.circular(right ? 0 : 20),
      bottomLeft: Radius.circular(right ? 20 : 0),
      bottomRight: Radius.circular(right ? 0 : 20),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border(
          // 高光描边只画在朝外的边缘：右抽屉贴右屏，亮边应在左侧。
          // 此前两侧都画右边，右抽屉那条亮边落在屏幕外，等于没有。
          left: right ? BorderSide(color: stroke, width: 0.8) : BorderSide.none,
          right:
              right ? BorderSide.none : BorderSide(color: stroke, width: 0.8),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(sheen, base), base],
        ),
      ),
      child: SizedBox.expand(child: child),
    );

    if (skipBlur) return ClipRRect(borderRadius: radius, child: decorated);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(filter: glassBlurFilter, child: decorated),
    );
  }
}
