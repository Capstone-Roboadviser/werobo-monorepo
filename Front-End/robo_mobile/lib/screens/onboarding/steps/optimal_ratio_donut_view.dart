import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Cool blue-gray segment shades for the donut (varying so the ring reads as a
/// real, if unknowable, allocation). Lengths match [_kSegmentFractions].
const List<Color> _kSegmentColors = [
  Color(0xFFDFE3EE),
  Color(0xFFC9CFE0),
  Color(0xFFE6E9F1),
  Color(0xFFD2D7E6),
  Color(0xFFBFC6D9),
];

/// Segment sweep fractions of the full circle (sum to 1.0).
const List<double> _kSegmentFractions = [0.24, 0.17, 0.27, 0.15, 0.17];

/// Step 4 visual: a SEGMENTED gray donut (varying blue-gray arcs with small
/// gaps) centered in the body, with bold center text `최적의 비율`. Thin gray
/// leader lines run diagonally from the ring out to four labels — `수익률?`
/// (upper-left), `?` (upper-right), `리스크?` (lower-right), `?` (lower-left).
///
/// The message: the optimal ratio is unknowable by hand — every slice is a
/// question mark. On entrance the ring sweeps in (0 → 2π) while the labels fade
/// in; the whole visual also fades and lifts slightly off the shared
/// [entrance] animation.
class OptimalRatioDonutView extends StatelessWidget {
  /// 0→1 entrance animation, driven by the orchestrator when this page is
  /// active.
  final Animation<double> entrance;

  const OptimalRatioDonutView({
    super.key,
    required this.entrance,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);

    // Labels read as muted "unknowns" — gray, not brand navy.
    final labelStyle = WeRoboTypography.body.copyWith(
      color: tc.textTertiary,
      fontWeight: FontWeight.w600,
    );
    final centerStyle = WeRoboTypography.heading3.copyWith(
      color: tc.textPrimary,
      fontWeight: FontWeight.w700,
    );

    return AnimatedBuilder(
      animation: entrance,
      builder: (context, child) {
        final t = entrance.value.clamp(0.0, 1.0).toDouble();
        final reveal = Curves.easeOut.transform(t);
        return Opacity(
          opacity: reveal,
          child: Transform.translate(
            offset: Offset(0, (1 - reveal) * 16),
            child: child,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _DonutLayout(
            constraints: constraints,
            entrance: entrance,
            labelStyle: labelStyle,
            centerStyle: centerStyle,
            leaderColor: tc.textTertiary,
          );
        },
      ),
    );
  }
}

/// Lays out the segmented ring, its center label, and the four diagonal
/// leader-line labels within the available body box.
class _DonutLayout extends StatelessWidget {
  final BoxConstraints constraints;
  final Animation<double> entrance;
  final TextStyle labelStyle;
  final TextStyle centerStyle;
  final Color leaderColor;

  const _DonutLayout({
    required this.constraints,
    required this.entrance,
    required this.labelStyle,
    required this.centerStyle,
    required this.leaderColor,
  });

  // Unit diagonals: upper-left, upper-right, lower-right, lower-left.
  static const double _diag = math.sqrt1_2;
  static const List<Offset> _dirs = [
    Offset(-_diag, -_diag),
    Offset(_diag, -_diag),
    Offset(_diag, _diag),
    Offset(-_diag, _diag),
  ];

  @override
  Widget build(BuildContext context) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    final diameter =
        math.min(w * 0.52, h * 0.42).clamp(150.0, 240.0).toDouble();
    final radius = diameter / 2;
    const stroke = 26.0;
    final center = Offset(w / 2, h * 0.44);
    final outer = radius + stroke / 2;
    const leaderLen = 18.0;

    Offset leaderEnd(Offset d) => center + d * (outer + leaderLen);
    final ul = leaderEnd(_dirs[0]);
    final ur = leaderEnd(_dirs[1]);
    final lr = leaderEnd(_dirs[2]);
    final ll = leaderEnd(_dirs[3]);

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: entrance,
            builder: (context, _) {
              final t = entrance.value.clamp(0.0, 1.0).toDouble();
              return CustomPaint(
                painter: _DonutRingPainter(
                  center: center,
                  radius: radius,
                  stroke: stroke,
                  sweep: Curves.easeOutCubic.transform(t) * 2 * math.pi,
                  leaderProgress:
                      ((t - 0.4) / 0.6).clamp(0.0, 1.0).toDouble(),
                  dirs: _dirs,
                  segmentColors: _kSegmentColors,
                  segmentFractions: _kSegmentFractions,
                  leaderColor: leaderColor,
                ),
              );
            },
          ),
        ),
        Positioned(
          left: center.dx - radius,
          top: center.dy - radius,
          width: diameter,
          height: diameter,
          child: Center(
            child: Text('최적의 비율',
                textAlign: TextAlign.center, style: centerStyle),
          ),
        ),
        // 수익률? — upper-left (label right edge near the leader end).
        Positioned(
          right: w - ul.dx,
          top: ul.dy - 12,
          child: _FadeLabel(
            entrance: entrance,
            child: Text('수익률?', style: labelStyle),
          ),
        ),
        // ? — upper-right.
        Positioned(
          left: ur.dx,
          top: ur.dy - 12,
          child: _FadeLabel(
            entrance: entrance,
            child: Text('?', style: labelStyle),
          ),
        ),
        // 리스크? — lower-right.
        Positioned(
          left: lr.dx,
          top: lr.dy - 12,
          child: _FadeLabel(
            entrance: entrance,
            child: Text('리스크?', style: labelStyle),
          ),
        ),
        // ? — lower-left.
        Positioned(
          right: w - ll.dx,
          top: ll.dy - 12,
          child: _FadeLabel(
            entrance: entrance,
            child: Text('?', style: labelStyle),
          ),
        ),
      ],
    );
  }
}

/// Fades [child] in on the back half of [entrance] so labels trail the ring.
class _FadeLabel extends StatelessWidget {
  final Animation<double> entrance;
  final Widget child;

  const _FadeLabel({required this.entrance, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, child) {
        final t = entrance.value.clamp(0.0, 1.0).toDouble();
        final opacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0).toDouble();
        return Opacity(opacity: opacity, child: child);
      },
      child: child,
    );
  }
}

/// Paints the segmented gray ring (sweeping in 0 → 2π, with small gaps between
/// segments) and the four diagonal leader lines from the ring's edge.
class _DonutRingPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double stroke;

  /// Current ring sweep in radians (0 → 2π over the entrance).
  final double sweep;

  /// 0→1 draw fraction for the leader lines (trails the ring).
  final double leaderProgress;

  final List<Offset> dirs;
  final List<Color> segmentColors;
  final List<double> segmentFractions;
  final Color leaderColor;

  _DonutRingPainter({
    required this.center,
    required this.radius,
    required this.stroke,
    required this.sweep,
    required this.leaderProgress,
    required this.dirs,
    required this.segmentColors,
    required this.segmentFractions,
    required this.leaderColor,
  });

  // Angular gap between segments (radians).
  static const double _gap = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    if (sweep <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final maxAngle = -math.pi / 2 + sweep;

    var startAngle = -math.pi / 2;
    for (var i = 0; i < segmentFractions.length; i++) {
      final segSweep = segmentFractions[i] * 2 * math.pi;
      final a0 = startAngle + _gap / 2;
      final a1 = startAngle + segSweep - _gap / 2;
      if (a0 < maxAngle && a1 > a0) {
        final drawEnd = math.min(a1, maxAngle);
        canvas.drawArc(
          rect,
          a0,
          drawEnd - a0,
          false,
          Paint()
            ..color = segmentColors[i % segmentColors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt,
        );
      }
      startAngle += segSweep;
    }

    if (leaderProgress > 0) {
      final leaderPaint = Paint()
        ..color = leaderColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final outer = radius + stroke / 2;
      for (final d in dirs) {
        final from = center + d * outer;
        final to = center + d * (outer + 16);
        canvas.drawLine(from, Offset.lerp(from, to, leaderProgress)!,
            leaderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutRingPainter old) =>
      old.sweep != sweep ||
      old.leaderProgress != leaderProgress ||
      old.center != center ||
      old.radius != radius ||
      old.stroke != stroke ||
      old.leaderColor != leaderColor;
}
