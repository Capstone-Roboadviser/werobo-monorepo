import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Step 1 visual: four labeled asset dots scattered across the central area.
///
/// 주식 (red), 금 (gold/yellow), 부동산 (green), 채권 (blue). Each is a ~22px
/// filled circle with a small gray label centered just below it. Rough layout:
/// 금 upper-center, 주식 left-middle, 부동산 right-middle, 채권 lower-center.
///
/// On entrance the dots stagger fade + scale in, each one slightly delayed,
/// driven by the orchestrator's [entrance] animation (0→1).
class AssetScatterView extends StatelessWidget {
  /// 0→1 entrance animation, driven by the orchestrator when this page is
  /// active.
  final Animation<double> entrance;

  const AssetScatterView({
    super.key,
    required this.entrance,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    // Drawn ~22px diameter; the painter scales each dot up to this radius.
    const dotRadius = 11.0;

    // Fractional centers within the body box, clustered in the upper-middle to
    // match the Figma (금 top-right-of-center; 주식 left, 부동산 right; 채권
    // center just below — with open space beneath).
    final dots = <_ScatterDot>[
      // 금 — upper, right of center, yellow/gold.
      const _ScatterDot(
        label: '금',
        color: WeRoboColors.assetGold,
        center: Offset(0.61, 0.16),
      ),
      // 주식 — left, red.
      const _ScatterDot(
        label: '주식',
        color: WeRoboColors.assetNewGrowth,
        center: Offset(0.17, 0.40),
      ),
      // 부동산 — right, green.
      const _ScatterDot(
        label: '부동산',
        color: WeRoboColors.assetInfraBond,
        center: Offset(0.80, 0.36),
      ),
      // 채권 — center, just below the middle row, blue.
      const _ScatterDot(
        label: '채권',
        color: WeRoboColors.assetShortBond,
        center: Offset(0.40, 0.52),
      ),
    ];

    return Semantics(
      label: dots.map((d) => d.label).join(', '),
      child: AnimatedBuilder(
        animation: entrance,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _AssetScatterPainter(
              dots: dots,
              progress: entrance.value,
              dotRadius: dotRadius,
              labelColor: tc.textTertiary,
            ),
          );
        },
      ),
    );
  }
}

/// One scattered asset: its label, fill color, and fractional center within
/// the available box (0–1 in each axis).
@immutable
class _ScatterDot {
  final String label;
  final Color color;
  final Offset center;

  const _ScatterDot({
    required this.label,
    required this.color,
    required this.center,
  });
}

/// Paints the four asset dots + labels, applying a per-dot staggered
/// fade + scale-in keyed off [progress] (0→1).
class _AssetScatterPainter extends CustomPainter {
  final List<_ScatterDot> dots;
  final double progress;
  final double dotRadius;
  final Color labelColor;

  _AssetScatterPainter({
    required this.dots,
    required this.progress,
    required this.dotRadius,
    required this.labelColor,
  });

  // Each dot reveals over this fraction of the timeline; successive dots start
  // [_stagger] later so they pop in one after another.
  static const double _segment = 0.55;
  static const double _stagger = 0.15;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset so dots + labels never clip the Expanded box edges.
    const double margin = 32.0;
    const double left = margin;
    const double top = margin;
    final double usableW =
        (size.width - margin * 2).clamp(0.0, size.width).toDouble();
    final double usableH =
        (size.height - margin * 2).clamp(0.0, size.height).toDouble();

    for (var i = 0; i < dots.length; i++) {
      final dot = dots[i];
      final double start = i * _stagger;
      // Local 0→1 reveal for this dot, eased for a soft settle.
      final double raw =
          ((progress - start) / _segment).clamp(0.0, 1.0).toDouble();
      final double t = WeRoboMotion.enter.transform(raw);
      if (t <= 0) continue;

      final double scale = 0.6 + 0.4 * t; // 60%→100%
      final double opacity = t;

      final double cx = left + dot.center.dx * usableW;
      final double cy = top + dot.center.dy * usableH;
      final center = Offset(cx, cy);
      final double r = dotRadius * scale;

      // Soft halo behind each dot for a touch of depth.
      canvas.drawCircle(
        center,
        r * 1.7,
        Paint()..color = dot.color.withValues(alpha: 0.12 * opacity),
      );
      // The filled dot.
      canvas.drawCircle(
        center,
        r,
        Paint()..color = dot.color.withValues(alpha: opacity),
      );

      _paintLabel(canvas, dot.label, center, r, opacity);
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset center,
    double r,
    double opacity,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: WeRoboTypography.caption.copyWith(
          color: labelColor.withValues(alpha: opacity),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    // Centered just below the dot.
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy + r + WeRoboSpacing.sm),
    );
  }

  @override
  bool shouldRepaint(covariant _AssetScatterPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.dots != dots;
}
