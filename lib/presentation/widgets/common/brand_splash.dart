// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 BooruNova contributors

import 'package:boorunova/presentation/widgets/common/brand_icon.dart';
import 'package:flutter/material.dart';

/// 启动过渡：原生 splash（Android 启动画面）之后、首页首帧之前的品牌层。
///
/// 动画顺序（总时长 1250ms）：
///  1. 四颗新星在环外的四个方向同时淡入（约 90ms，「从四处出现」）；
///  2. 顺时针螺旋内收、拖尾随之拉长，飞向各自的落位点（约 780ms）；
///  3. 落位后停一瞬，整层淡出交还界面（约 280ms）。
///
/// 纯视觉层：IgnorePointer 不拦截交互，也不阻塞任何初始化（Hive 等已在
/// main 完成）；播完通过 onFinished 让调用方把本层从树上摘掉。
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key, this.onFinished, this.dark = false});

  /// 过渡完全结束后回调（用于从树上移除本层）。
  final VoidCallback? onFinished;

  /// 是否深色背景。由调用方（BooruNova）依据主题决定，不能在此处读
  /// Theme.of(context)：BrandSplash 位于 MaterialApp 之外，拿不到真实主题，
  /// 否则会恒以浅色渲染（深色模式启动闪白）。
  final bool dark;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  /// 0→1 的飞入进度：前 70% 走完（875ms），之后一直停在落位状态
  /// （含最后 22% 的淡出，避免淡出过程中图形还在动）。
  /// 曲线在 painter 里做（easeOutCubic），这里保持线性，避免双重缓动。
  late final Animation<double> _flight = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 70),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 8),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 22),
  ]).animate(_controller);

  /// 整层透明度：起手即满（底色与原生 splash 同色，交接不会闪），
  /// 落位后 22%（275ms）淡出。
  late final Animation<double> _fade = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 78),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 22,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_fade.value <= 0.01) return const SizedBox.shrink();
          return Opacity(
            opacity: _fade.value,
            // SizedBox.expand 让背景铺满整个 Stack（全屏），否则 Stack
            // 的 loose fit 会让 ColoredBox 收缩到 logo 大小、露出底下内容。
            child: SizedBox.expand(
              child: ColoredBox(
                color: dark
                    ? const Color(0xFF17141F)
                    : const Color(0xFFF1EFFE),
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: FittedBox(
                      child: BrandIcon(
                        withBackground: false,
                        flight: _flight.value,
                        onDark: dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
