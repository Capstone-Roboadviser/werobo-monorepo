import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'risk_gauge.dart';

// ============================================================================
// Interpolation helpers — pure functions of `progress` (PageController.page).
// progress ∈ [0.0, 6.0]; integer values land exactly on a page.
// Exported (no underscore) so the helper tests can reach them.
// ============================================================================

double _lerpClamped(double a, double b, double t) =>
    lerpDouble(a, b, t.clamp(0.0, 1.0))!;

double storyGaugeOpacity(double p) {
  // Visible across spec pages 2-3 (progress 1.0–2.0). Fades in 0.7→1.0,
  // out 2.0→2.5.
  if (p < 0.7) return 0;
  if (p < 1.0) return (p - 0.7) / 0.3;
  if (p < 2.0) return 1.0;
  if (p < 2.5) return 1 - (p - 2.0) / 0.5;
  return 0;
}

double storyGaugeValue(double p) {
  // 40 on spec page 2 (progress 1.0), eases to 30 on spec page 3 (2.0).
  if (p < 1.0) return 40;
  if (p < 2.0) return 40 - (p - 1.0) * 10;
  return 30;
}

double storyCtaOpacity(double p) {
  // Fades in across [5.7, 6.0] so the CTA is fully visible AT spec page 7
  // (progress 6.0). The event chips on page 6 are already fading out by 5.7,
  // so there is no overlap conflict.
  if (p < 5.7) return 0;
  if (p < 6.0) return (p - 5.7) / 0.3;
  return 1.0;
}

/// 0 → 1 across [3.5, 4.0] (curve draws as user enters page 5);
/// stays at 1 through 4.5; fades back to 0 across [4.5, 5.0]
/// as the frontier scene exits toward page 6.
double storyCurveDrawProgress(double p) {
  if (p < 3.5) return 0;
  if (p < 4.0) return (p - 3.5) / 0.5;
  if (p < 4.5) return 1.0;
  if (p < 5.0) return 1 - (p - 4.5) / 0.5;
  return 0;
}

/// Opacity for each of the 4 story dots.
/// - All 4 visible on spec page 1 (progress 0).
/// - Dot 0 (red) is the "lead" — it scales into the page-2 circle so its
///   own dot opacity drops to 0 across [0.7, 1.0] (the circle takes over).
/// - Dots 1-3 fade out across [0.3, 0.8].
/// - All 4 reappear on spec page 5 (frontier scene) across [3.7, 4.0]
///   at on-curve positions, then fade out across [4.7, 5.0].
double storyDotOpacity(int index, double p) {
  // Frontier scene visibility window (spec page 5, progress 4.0)
  if (p >= 3.7 && p < 5.0) {
    if (p < 4.0) return (p - 3.7) / 0.3;
    if (p < 4.7) return 1.0;
    return 1 - (p - 4.7) / 0.3;
  }

  // Intro scene (spec page 1, progress 0)
  if (index == 0) {
    if (p < 0.7) return 1.0;
    if (p < 1.0) return 1 - (p - 0.7) / 0.3;
    return 0;
  }
  if (p < 0.3) return 1.0;
  if (p < 0.8) return 1 - (p - 0.3) / 0.5;
  return 0;
}

/// Staggered fade-in (chip 0 leads, chip 3 trails by 0.05 progress units).
/// All chips fully visible by progress 4.85, well before spec page 6
/// (progress 5.0). Fades out across [5.5, 6.0] as the user moves to page 7.
double storyChipOpacity(int index, double p) {
  final start = 4.5 + index * 0.05;
  final end = start + 0.2;
  if (p < start) return 0;
  if (p < end) return (p - start) / (end - start);
  if (p < 5.5) return 1.0;
  if (p < 6.0) return 1 - (p - 5.5) / 0.5;
  return 0;
}

// ============================================================================
// StoryCanvas — visual layer for the onboarding story.
// `progress` is `PageController.page ?? 0.0` from the host screen.
// ============================================================================

/// Story scene constants. Page-relative positions are unitless fractions
/// of the canvas; the painter scales them to actual pixels.
const _kDotColors = [
  Color(0xFFFF4141), // red
  Color(0xFF5568E3), // blue
  Color(0xFFE6CC0B), // yellow
  Color(0xFF85C410), // green
];

const _kEventLabels = ['유가 변동', '관세 전쟁', '인플레이션', '전쟁'];

class StoryCanvas extends StatelessWidget {
  final double progress;
  final VoidCallback? onStartPressed;

  const StoryCanvas({
    super.key,
    required this.progress,
    this.onStartPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centerY = size.height * 0.45;
        final ctaY = size.height * 0.62;

        return Stack(
          children: [
            // Paint layer: dots, pie/circle, ?? marks, EF curve
            Positioned.fill(
              child: CustomPaint(painter: _StoryPainter(progress: progress)),
            ),

            // Gauge widget layer (pages 2-3)
            Positioned(
              left: 0,
              right: 0,
              top: centerY - 110,
              child: Opacity(
                opacity: storyGaugeOpacity(progress),
                child: Center(
                  child: RiskGauge(
                    value: storyGaugeValue(progress),
                    size: 140,
                  ),
                ),
              ),
            ),

            // Event chips (page 6) — 2x2 grid
            ..._buildEventChips(centerY, size.width),

            // CTA button (page 7)
            Positioned(
              left: 0,
              right: 0,
              top: ctaY,
              child: IgnorePointer(
                ignoring: storyCtaOpacity(progress) < 0.99,
                child: Opacity(
                  opacity: storyCtaOpacity(progress),
                  child: Center(
                    child: _StartButton(onPressed: onStartPressed),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildEventChips(double centerY, double width) {
    return List.generate(_kEventLabels.length, (i) {
      final col = i % 2;
      final row = i ~/ 2;
      final x = col == 0 ? width * 0.18 : width * 0.55;
      final y = centerY - 30 + row * 50.0;
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: storyChipOpacity(i, progress),
          child: Text(
            _kEventLabels[i],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WeRoboColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _StartButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WeRoboColors.primaryLight,
        foregroundColor: WeRoboColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      child: const Text(
        '투자 시작하기',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// _StoryPainter — draws dots, pie/circle, ?? marks, EF curve.
// Repaints on every progress change (every PageView scroll frame).
// ============================================================================

class _StoryPainter extends CustomPainter {
  final double progress;

  _StoryPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    _paintDots(canvas, size);
    _paintCircleOrPie(canvas, size);
    _paintQuestionMarks(canvas, size);
    _paintFrontierCurve(canvas, size);
  }

  void _paintDots(Canvas canvas, Size size) {
    // Page 1 layout: scattered positions (fractions of canvas).
    // Page 5 layout: positions along the frontier curve.
    const scattered = [
      Offset(0.62, 0.32), // red
      Offset(0.25, 0.42), // blue
      Offset(0.38, 0.40), // yellow
      Offset(0.50, 0.38), // green
    ];
    const onCurve = [
      Offset(0.78, 0.34), // red — top-right
      Offset(0.22, 0.55), // blue — lower-left
      Offset(0.55, 0.43), // yellow — middle
      Offset(0.40, 0.48), // green — left-middle
    ];

    for (var i = 0; i < 4; i++) {
      final op = storyDotOpacity(i, progress);
      if (op <= 0) continue;

      // Pick scattered vs on-curve based on progress range.
      // On-curve positions kick in once the frontier scene starts fading in.
      final pos = progress >= 3.7 ? onCurve[i] : scattered[i];
      final paint = Paint()
        ..color = _kDotColors[i].withValues(alpha: op)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(pos.dx * size.width, pos.dy * size.height),
        12,
        paint,
      );
    }
  }

  void _paintCircleOrPie(Canvas canvas, Size size) {
    // Visible across spec pages 2-4 (progress 1.0-3.0). Fades in 0.7-1.0,
    // fades out 3.0-3.5.
    if (progress < 0.7 || progress > 3.5) return;

    final center = Offset(size.width / 2, size.height * 0.45 + 30);
    // Radius grows 0 → 60 across [0.7, 1.0]; steady thereafter.
    final radius = progress < 1.0
        ? _lerpClamped(0, 60, (progress - 0.7) / 0.3)
        : 60.0;

    // Green-slice angle grows across [1.0, 2.0] (page 2 → page 3).
    final greenSweep = progress < 1.0
        ? 0.0
        : progress < 2.0
            ? _lerpClamped(0, math.pi * 2 * 0.32, progress - 1.0)
            : math.pi * 2 * 0.32;

    // Overall alpha: fades out as we leave spec page 4 (progress 3.0 → 3.5).
    final alpha = progress < 3.0 ? 1.0 : 1 - (progress - 3.0) / 0.5;
    final clampedAlpha = alpha.clamp(0.0, 1.0);

    final redPaint = Paint()
      ..color = const Color(0xFFFF4141).withValues(alpha: clampedAlpha);
    final greenPaint = Paint()
      ..color = const Color(0xFF85C410).withValues(alpha: clampedAlpha);

    // Red full disc, then green wedge over it.
    canvas.drawCircle(center, radius, redPaint);
    if (greenSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        greenSweep,
        true,
        greenPaint,
      );
    }
  }

  void _paintQuestionMarks(Canvas canvas, Size size) {
    // Visible on spec page 4 (progress 3.0). Fades in 2.5-3.0, out 3.0-3.5.
    if (progress < 2.5 || progress > 3.5) return;

    final fade = progress < 3.0
        ? (progress - 2.5) / 0.5
        : 1 - (progress - 3.0) / 0.5;
    final alpha = fade.clamp(0.0, 1.0);
    if (alpha <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.45 + 30);
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < 2; i++) {
      final angle = -math.pi / 4 + i * (math.pi / 2);
      final pos = Offset(
        center.dx + 90 * math.sin(angle),
        center.dy - 90 * math.cos(angle),
      );
      tp.text = TextSpan(
        text: '??',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: WeRoboColors.textPrimary.withValues(alpha: alpha),
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintFrontierCurve(Canvas canvas, Size size) {
    final drawT = storyCurveDrawProgress(progress);
    if (drawT <= 0) return;

    // The curve fades out as we leave spec page 5 (progress 4.0) toward
    // spec page 6 (progress 5.0).
    final overallAlpha = (progress < 4.5
            ? 1.0
            : 1 - (progress - 4.5) / 0.5)
        .clamp(0.0, 1.0);

    // Hardcoded illustrative EF curve: cubic bezier sweeping from
    // lower-left to upper-right.
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.60)
      ..cubicTo(
        size.width * 0.30, size.height * 0.55,
        size.width * 0.55, size.height * 0.32,
        size.width * 0.85, size.height * 0.30,
      );

    // Truncate to drawT fraction using PathMetric.
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * drawT);

    final paint = Paint()
      ..color = WeRoboColors.textPrimary.withValues(alpha: overallAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(covariant _StoryPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
