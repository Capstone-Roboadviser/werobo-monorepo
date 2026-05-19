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
/// - Dot 0 (red) is the "lead" — it grows and migrates to the pie center
///   across [0.7, 1.0], staying fully opaque through the morph. At p=1.0 the
///   pie circle takes over and the dot's opacity snaps to 0.
/// - Dots 1-3 fade out across [0.3, 0.8].
/// - All 4 reappear on spec page 5 (frontier scene) across [3.7, 4.0]
///   at on-curve positions, then fade out across [4.7, 5.0].
double storyDotOpacity(int index, double p) {
  if (p >= 3.7 && p < 5.0) {
    if (p < 4.0) return (p - 3.7) / 0.3;
    if (p < 4.7) return 1.0;
    return 1 - (p - 4.7) / 0.3;
  }

  if (index == 0) {
    if (p < 1.0) return 1.0;
    return 0;
  }
  if (p < 0.3) return 1.0;
  if (p < 0.8) return 1 - (p - 0.3) / 0.5;
  return 0;
}

/// Scales the page-1 floating wobble: full on the intro, settled by the time
/// the red dot starts its migration to the pie center.
double storyWobbleScale(double p) {
  if (p < 0.3) return 1.0;
  if (p < 0.7) return 1.0 - (p - 0.3) / 0.4;
  return 0.0;
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

class StoryCanvas extends StatefulWidget {
  final double progress;
  final VoidCallback? onStartPressed;

  const StoryCanvas({
    super.key,
    required this.progress,
    this.onStartPressed,
  });

  @override
  State<StoryCanvas> createState() => _StoryCanvasState();
}

class _StoryCanvasState extends State<StoryCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centerY = size.height * 0.45;

        return Stack(
          children: [
            // Paint layer: dots, pie/circle, ?? marks, EF curve
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, _) => CustomPaint(
                  painter: _StoryPainter(
                    progress: widget.progress,
                    time: _floatController.value,
                  ),
                ),
              ),
            ),

            // Gauge widget layer (pages 2-3)
            Positioned(
              left: 0,
              right: 0,
              top: centerY - 110,
              child: Opacity(
                opacity: storyGaugeOpacity(widget.progress),
                child: Center(
                  child: RiskGauge(
                    value: storyGaugeValue(widget.progress),
                    size: 140,
                  ),
                ),
              ),
            ),

            // Event chips (page 6) — 2x2 spread with seamless floating wobble.
            // Wrapped in AnimatedBuilder so positions update each tick.
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, _) => Stack(
                children: _buildEventChips(centerY, size.width),
              ),
            ),

            // CTA button (page 7) — anchored to the bottom of the canvas.
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: IgnorePointer(
                ignoring: storyCtaOpacity(widget.progress) < 0.99,
                child: Opacity(
                  opacity: storyCtaOpacity(widget.progress),
                  child: Center(
                    child: _StartButton(onPressed: widget.onStartPressed),
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
    final cycle = _floatController.value * 2 * math.pi;
    return List.generate(_kEventLabels.length, (i) {
      final col = i % 2;
      final row = i ~/ 2;
      final baseX = col == 0 ? width * 0.22 : width * 0.55;
      final baseY = centerY - 35 + row * 70.0;
      final wx = math.sin(cycle * _kChipFreqsX[i] + _kChipPhases[i]) *
          _kChipAmplitude;
      final wy = math.cos(cycle * _kChipFreqsY[i] + _kChipPhases[i]) *
          _kChipAmplitude;
      return Positioned(
        left: baseX + wx,
        top: baseY + wy,
        child: Opacity(
          opacity: storyChipOpacity(i, widget.progress),
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
    // Override the global elevatedButtonTheme's minimumSize so the button
    // shrinks to fit its content instead of spanning full width.
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WeRoboColors.primaryLight,
        foregroundColor: WeRoboColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

// Per-dot wobble shape: distinct phases and integer-cycle frequencies so each
// dot traces its own Lissajous-ish path AND the motion loops seamlessly with
// the controller (integer cycles per period → sin/cos value matches at wrap).
const _kWobblePhases = [0.0, 1.3, 2.6, 4.1];
const _kWobbleFreqsX = [1, 2, 1, 3];
const _kWobbleFreqsY = [3, 1, 2, 2];
const _kWobbleAmplitude = 10.0; // px

// Pie/asset circle layout. Centered horizontally. While the gauge is visible
// (pages 2-3) the pie sits below it; as the gauge fades out (page 3 → 4) the
// pie rises to centerY so the page-4 ?? composition reads as vertically
// centered. Shared by the pie, the red-dot morph target, and the ?? marks.
const _kPieYOffset = 130.0; // px below centerY when gauge fully visible
const _kPieRadius = 50.0;

// Page-4 ?? mark wobble — same integer-cycle pattern as the dots so the loop
// is seamless. Distinct phases keep the two marks from moving in sync.
const _kQmarkPhases = [0.0, math.pi];
const _kQmarkFreqsX = [1, 2];
const _kQmarkFreqsY = [2, 1];
const _kQmarkAmplitude = 7.0; // px

// Page-6 event chip wobble — same integer-cycle pattern. Amplitude is smaller
// than the dots because the chips are text and large motion reads as jitter.
const _kChipPhases = [0.0, 1.7, 3.4, 5.1];
const _kChipFreqsX = [1, 2, 1, 2];
const _kChipFreqsY = [2, 1, 2, 1];
const _kChipAmplitude = 5.0; // px

class _StoryPainter extends CustomPainter {
  final double progress;
  final double time; // 0–1, loops with the float controller

  _StoryPainter({required this.progress, required this.time});

  /// Vertical center for the pie/?? composition. Sits below the gauge on
  /// pages 2-3, then rises to centerY across the ?? fade-in window [2.5, 3.0]
  /// so the rise and the ?? appearance feel like one motion.
  Offset _pieCenter(Size size) {
    final riseT = ((progress - 2.5) / 0.5).clamp(0.0, 1.0);
    final yOffset = lerpDouble(_kPieYOffset, 0, riseT)!;
    return Offset(size.width / 2, size.height * 0.45 + yOffset);
  }

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
      Offset(0.78, 0.26), // red — top-right
      Offset(0.15, 0.55), // blue — bottom-left
      Offset(0.32, 0.30), // yellow — top-left
      Offset(0.62, 0.52), // green — bottom-right
    ];
    // Page-5 dot positions ported from the design mockup (werobo_graph.html).
    // The mockup graph-wrap is 402x270, placed at canvas y-frac 0.32-0.65.
    // Per-dot fractions: x = htmlX/402; y = 0.32 + (htmlY/270) * 0.33.
    // Dots intentionally do NOT all sit on the curve — blue/yellow/green sit
    // below it (suboptimal assets), red sits above the right end.
    const onCurve = [
      Offset(0.828, 0.364), // red    — html (333,  36)
      Offset(0.338, 0.562), // blue   — html (136, 198)
      Offset(0.463, 0.484), // yellow — html (186, 134)
      Offset(0.701, 0.498), // green  — html (282, 146)
    ];

    final pieCenter = _pieCenter(size);
    final wobble = storyWobbleScale(progress);
    final angle = time * 2 * math.pi;

    for (var i = 0; i < 4; i++) {
      final op = storyDotOpacity(i, progress);
      if (op <= 0) continue;

      final base = progress >= 3.7 ? onCurve[i] : scattered[i];
      var pixel = Offset(base.dx * size.width, base.dy * size.height);
      var radius = 12.0;

      if (wobble > 0) {
        final wx = math.sin(angle * _kWobbleFreqsX[i] + _kWobblePhases[i]) *
            _kWobbleAmplitude *
            wobble;
        final wy = math.cos(angle * _kWobbleFreqsY[i] + _kWobblePhases[i]) *
            _kWobbleAmplitude *
            wobble;
        pixel = pixel + Offset(wx, wy);
      }

      // Red dot migrates to pie center and grows to pie radius across [0.7, 1.0].
      if (i == 0 && progress >= 0.7 && progress < 1.0) {
        final t = (progress - 0.7) / 0.3;
        final startPixel =
            Offset(scattered[0].dx * size.width, scattered[0].dy * size.height);
        pixel = Offset.lerp(startPixel, pieCenter, t)!;
        radius = lerpDouble(12, _kPieRadius, t)!;
      }

      final paint = Paint()
        ..color = _kDotColors[i].withValues(alpha: op)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pixel, radius, paint);
    }
  }

  void _paintCircleOrPie(Canvas canvas, Size size) {
    // The red dot grows into this pie across [0.7, 1.0], so the pie starts
    // drawing once that morph completes. Fades out across [3.0, 3.5].
    if (progress < 1.0 || progress > 3.5) return;

    final center = _pieCenter(size);
    const radius = _kPieRadius;

    // Green-slice angle grows across [1.0, 2.0] (page 2 → page 3).
    final greenSweep = progress < 2.0
        ? _lerpClamped(0, math.pi * 2 * 0.32, progress - 1.0)
        : math.pi * 2 * 0.32;

    // Overall alpha: fades out as we leave spec page 4 (progress 3.0 → 3.5).
    final alpha = progress < 3.0 ? 1.0 : 1 - (progress - 3.0) / 0.5;
    final clampedAlpha = alpha.clamp(0.0, 1.0);

    final redPaint = Paint()
      ..color = const Color(0xFFFF4141).withValues(alpha: clampedAlpha);
    final greenPaint = Paint()
      ..color = const Color(0xFF85C410).withValues(alpha: clampedAlpha);

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

    final center = _pieCenter(size);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final cycle = time * 2 * math.pi;

    for (var i = 0; i < 2; i++) {
      final orbitAngle = -math.pi / 4 + i * (math.pi / 2);
      final basePos = Offset(
        center.dx + 90 * math.sin(orbitAngle),
        center.dy - 90 * math.cos(orbitAngle),
      );
      final wx = math.sin(cycle * _kQmarkFreqsX[i] + _kQmarkPhases[i]) *
          _kQmarkAmplitude;
      final wy = math.cos(cycle * _kQmarkFreqsY[i] + _kQmarkPhases[i]) *
          _kQmarkAmplitude;
      final pos = basePos + Offset(wx, wy);

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

    // EF curve ported directly from the design mockup (werobo_graph.html).
    // Two cubic-bezier segments. Source path (in 402x270 graph coords):
    //   M 47 223 C 58 150, 126 98, 217 78  C 269 66, 319 67, 364 70
    // Mapped via x = htmlX/402, y = 0.32 + (htmlY/270) * 0.33 to canvas frac.
    double gx(double htmlX) => size.width * (htmlX / 402.0);
    double gy(double htmlY) => size.height * (0.32 + (htmlY / 270.0) * 0.33);
    final path = Path()
      ..moveTo(gx(47), gy(223))
      ..cubicTo(gx(58), gy(150), gx(126), gy(98), gx(217), gy(78))
      ..cubicTo(gx(269), gy(66), gx(319), gy(67), gx(364), gy(70));

    // Truncate to drawT fraction using PathMetric.
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * drawT);

    final paint = Paint()
      ..color = WeRoboColors.textSecondary.withValues(alpha: overallAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(covariant _StoryPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.time != time;

  // CustomPaint with no child claims hits by default (painter.hitTest
  // returns null which the framework reads as true). Override to false
  // so swipe gestures fall through to the PageView underneath.
  @override
  bool? hitTest(Offset position) => false;
}
