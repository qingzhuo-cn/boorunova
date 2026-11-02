// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 BooruNova contributors

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 品牌图标：四颗新星（nova）沿一条**不闭合的圆轨**旋转排布，拖尾由深到淡、
/// 由粗到细，合起来读作一个「旋转中的不完整圆形」。
///
/// 使用 256 逻辑坐标的正方形，图形铺满整块：
///  - 圆角方底：柔和的雾蓝 → 淡紫对角渐变（不过深，也不用纯紫）
///  - 四条弧形拖尾：头部深靛紫、尾部淡到透明，颜色与宽度同步收细
///  - 四颗四角新星：白芯 + 淡紫边缘 + 柔和光晕，落在各自拖尾的头部
///  - 环心一层很淡的光 + 一小粒暖色：给「新星正在点亮」的层次
///
/// 同一份绘制源既是图标资源的权威来源（`test/icon_golden_test.dart` 生成
/// 各密度 PNG），也是启动过渡动画（`BrandSplash`）的绘制源：`flight`
/// 0→1 时四颗星从环外四个方向同时淡入、螺旋收拢，最终落位成图标。
class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    this.withBackground = true,
    this.flight = 1.0,
    this.onDark = false,
  });

  /// 自适应图标前景置 false：不画圆角方底，只画图形（背景由系统提供）。
  final bool withBackground;

  /// 新星飞入进度：0 = 还在环外、完全透明；1 = 已落位（静态图标恒为 1）。
  final double flight;

  /// 深色背景上使用：拖尾与星光整体提亮，避免深紫糊在近黑底上。
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 256,
      child: CustomPaint(
        painter: _BrandPainter(
          withBackground: withBackground,
          flight: flight,
          palette: onDark ? _NovaPalette.dark : _NovaPalette.light,
        ),
      ),
    );
  }
}

/// 品牌配色。刻意避开原来 #C026D3 → #6D28D9 那种又深又纯的紫：
/// 底色是「雾蓝 → 淡紫」的浅渐变，拖尾从靛紫过渡到近白，星光偏暖。
class _NovaPalette {
  const _NovaPalette({
    required this.bgStart,
    required this.bgMid,
    required this.bgEnd,
    required this.trailHead,
    required this.trailMid,
    required this.trailTail,
    required this.starEdge,
    required this.halo,
    required this.warm,
    required this.lift,
    required this.liftAlpha,
    required this.warmAlpha,
  });

  final Color bgStart;
  final Color bgMid;
  final Color bgEnd;
  final Color trailHead;
  final Color trailMid;
  final Color trailTail;
  final Color starEdge;
  final Color halo;
  final Color warm;

  /// 环内那层提亮光：浅底用白色，深底用淡紫（白色在近黑上会糊成灰雾）。
  final Color lift;
  final double liftAlpha;

  /// 环心暖光的强度：深底要更亮才看得出是暖的。
  final double warmAlpha;

  /// 浅色场景（启动器图标、浅色启动画面）：浅雾光底 + 靛紫拖尾 + 暖星光。
  static const _NovaPalette light = _NovaPalette(
    bgStart: Color(0xFFD7D1FC),
    bgMid: Color(0xFFC6CCFC),
    bgEnd: Color(0xFFB6CEFB),
    trailHead: Color(0xFF3B29B4),
    trailMid: Color(0xFF6E51E4),
    trailTail: Color(0xFFC8BCF6),
    starEdge: Color(0xFF6046DE),
    halo: Color(0xFFA98CFF),
    warm: Color(0xFFFFC98C),
    lift: Color(0xFFFFFFFF),
    liftAlpha: 0.26,
    warmAlpha: 0.34,
  );

  /// 深色场景（夜间启动画面）：整体提亮，在近黑底上仍然发光。
  static const _NovaPalette dark = _NovaPalette(
    bgStart: Color(0xFF252238),
    bgMid: Color(0xFF1E1B2E),
    bgEnd: Color(0xFF191726),
    trailHead: Color(0xFFB7A4FF),
    trailMid: Color(0xFF9C86FA),
    trailTail: Color(0xFF6F5FD8),
    starEdge: Color(0xFFC9B8FF),
    halo: Color(0xFFB9A6FF),
    warm: Color(0xFFFFD9A8),
    lift: Color(0xFF6E5BD8),
    liftAlpha: 0.26,
    warmAlpha: 0.82,
  );
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter({
    required this.withBackground,
    required this.flight,
    required this.palette,
  });

  final bool withBackground;
  final double flight;
  final _NovaPalette palette;

  /// 四颗星的落位角（弧度；屏幕坐标 y 轴向下，0 = 正右）。
  static const List<double> _headAngles = <double>[
    -1.082, // -62°，右上
    0.524, // 30°，右下
    2.130, // 122°，左下
    3.735, // 214°，左上
  ];

  /// 各自拖尾的张角（弧度）。三条长尾两两之间只留 8–10° 的细缝，
  /// 左下那颗（214°）刻意用短尾，留出约 52° 的主开口——眼睛读到的就是
  /// 「旋转中的不完整圆」，而不是一个闭合的环。
  static const List<double> _trailSpans = <double>[1.34, 1.44, 1.42, 0.70];

  /// 四颗星的大小（相对边长）。刻意不等，图标才不显得机械。
  static const List<double> _starSizes = <double>[0.080, 0.069, 0.075, 0.062];

  /// 轨道半径（相对边长）。
  static const double _orbit = 0.268;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * 0.5, s * 0.5);
    final t = flight.clamp(0.0, 1.0);

    _paintBackground(canvas, size);
    _paintNovaCore(canvas, center, s);

    // 飞入：前 10% 在环外淡入（「从四处同时出现」），其余时间螺旋收拢。
    // 角度做的是**顺时针**收拢（角度递增），所以拖尾挂在头部的逆时针一侧，
    // 飞行途中和落位后读到的都是「星在前、尾在后」。
    final appear = Curves.easeOut.transform((t / 0.10).clamp(0.0, 1.0));
    final fly =
        Curves.easeOutCubic.transform(((t - 0.08) / 0.92).clamp(0.0, 1.0));
    final orbit = s * _orbit * (1 + 2.0 * (1 - fly));
    final spin = 1.10 * (1 - fly);
    final trailMul = 0.16 + 0.84 * fly;
    final widthMul = 0.45 + 0.55 * trailMul;
    final starMul = 0.72 + 0.28 * fly;

    if (appear <= 0.001) return;

    for (var i = 0; i < _headAngles.length; i++) {
      _paintTrail(
        canvas,
        center,
        s,
        orbit,
        _headAngles[i] - spin,
        _trailSpans[i],
        trailMul,
        widthMul,
        appear,
      );
    }
    for (var i = 0; i < _headAngles.length; i++) {
      final head = _headAngles[i] - spin;
      final pos = center +
          Offset(math.cos(head) * orbit, math.sin(head) * orbit);
      _paintStar(canvas, pos, s * _starSizes[i] * starMul, appear);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    if (!withBackground) return;
    final rect = Offset.zero & size;
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[palette.bgStart, palette.bgMid, palette.bgEnd],
      stops: const <double>[0.0, 0.52, 1.0],
    ).createShader(rect);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.225),
    );
    canvas.drawRRect(rrect, Paint()..shader = shader);
    // 极淡的径向暗角：四角略沉，环轨才不贴在纸上。
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0x00000000),
            Color(0x004A3FA8),
            Color(0x0F4A3FA8),
          ],
          stops: <double>[0.55, 0.86, 1.0],
        ).createShader(rect),
    );
  }

  /// 环心的光：外层是一圈很淡的白光把环内提亮，中心再点一小粒暖色——
  /// 既给构图一个光源，又不会在淡底上糊成一块发灰的圆斑。
  void _paintNovaCore(Canvas canvas, Offset center, double s) {
    final liftRadius = s * 0.42;
    canvas.drawCircle(
      center,
      liftRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.lift.withOpacity(palette.liftAlpha),
            palette.lift.withOpacity(palette.liftAlpha * 0.35),
            palette.lift.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 0.62, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: liftRadius)),
    );

    final coreRadius = s * 0.16;
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.warm.withOpacity(palette.warmAlpha),
            palette.warm.withOpacity(palette.warmAlpha * 0.30),
            palette.warm.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreRadius)),
    );
  }

  /// 一条拖尾：以圆心为原点，从 [head] 往回铺 [span] 弧度；颜色深→淡、
  /// 宽度粗→细，尾端完全透明，所以看不到生硬的断口。
  void _paintTrail(
    Canvas canvas,
    Offset center,
    double s,
    double orbit,
    double head,
    double span,
    double lenMul,
    double widthMul,
    double alpha,
  ) {
    final sweep = span * lenMul;
    final headWidth = s * 0.036 * widthMul;
    final tailWidth = s * 0.0045;
    final shaderRadius = orbit + headWidth * 3;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(head - sweep);

    // 主体：深靛紫 → 淡紫 → 透明，宽度同步收细。
    canvas.drawPath(
      _trailBand(sweep, orbit, headWidth, tailWidth),
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: <Color>[
            palette.trailTail.withOpacity(0.0),
            palette.trailMid.withOpacity(0.55 * alpha),
            palette.trailHead.withOpacity(0.95 * alpha),
          ],
          stops: const <double>[0.0, 0.62, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: shaderRadius),
        ),
    );

    canvas.restore();
  }

  /// 拖尾的锥形带：外沿 + 内沿两条弧拼成闭合路径（在已旋转的局部坐标里，
  /// 角度 0 就是尾端，正角度方向指向头部）。
  Path _trailBand(
    double sweep,
    double radius,
    double headWidth,
    double tailWidth,
  ) {
    const steps = 44;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final angle = sweep * u;
      final width =
          tailWidth + (headWidth - tailWidth) * math.pow(u, 0.72).toDouble();
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      outer.add(Offset((radius + width / 2) * cos, (radius + width / 2) * sin));
      inner.add(Offset((radius - width / 2) * cos, (radius - width / 2) * sin));
    }
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (var i = 1; i < outer.length; i++) {
      path.lineTo(outer[i].dx, outer[i].dy);
    }
    for (var i = inner.length - 1; i >= 0; i--) {
      path.lineTo(inner[i].dx, inner[i].dy);
    }
    return path..close();
  }

  /// 一颗新星：柔和光晕 + 四角星（白芯、淡紫边缘）。
  void _paintStar(Canvas canvas, Offset center, double r, double alpha) {
    final haloRadius = r * 2.2;
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.halo.withOpacity(0.32 * alpha),
            palette.halo.withOpacity(0.0),
          ],
          stops: const <double>[0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    canvas.drawPath(
      _sparkle(center, r),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withOpacity(alpha),
            const Color(0xFFC9B8FF).withOpacity(alpha),
            palette.starEdge.withOpacity(alpha),
          ],
          stops: const <double>[0.0, 0.26, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  /// 四角新星：四个尖角之间用二次贝塞尔向圆心收腰，得到有腰身的星芒。
  Path _sparkle(Offset center, double r) {
    const waist = 0.26;
    const tips = <Offset>[
      Offset(0, -1),
      Offset(1, 0),
      Offset(0, 1),
      Offset(-1, 0),
    ];
    final path = Path()
      ..moveTo(center.dx + tips[0].dx * r, center.dy + tips[0].dy * r);
    for (var i = 0; i < tips.length; i++) {
      final a = tips[i];
      final b = tips[(i + 1) % tips.length];
      // 控制点落在两尖角的对角线上、按 waist 拉向圆心 → 凹边。
      path.quadraticBezierTo(
        center.dx + (a.dx + b.dx) * r * waist,
        center.dy + (a.dy + b.dy) * r * waist,
        center.dx + b.dx * r,
        center.dy + b.dy * r,
      );
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground ||
      oldDelegate.flight != flight ||
      oldDelegate.palette != palette;
}
