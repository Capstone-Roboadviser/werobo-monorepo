import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../widgets/efficient_frontier_chart.dart' show frontierCurvePointForT;

/// Step 5 visual (display-only): an efficient-frontier scatter cloud + a bold
/// navy frontier curve that draws on entrance, ending in a right arrowhead,
/// with a highlighted `추천 포트폴리오` dot + pill tooltip on the curve's
/// upper-middle.
///
/// Illustrative static data only: no API, no drag. The frontier curve reuses
/// the shared [frontierCurvePointForT] math (lower-left to upper-right,
/// concave down); none of the interactive chart's gestures are reused here.
///
/// The body fills the [Expanded] region the scaffold gives below the headline
/// and caption, so it sizes to the available box via [LayoutBuilder]/
/// [CustomPaint] and adds no headline of its own.
class OnboardingFrontierView extends StatelessWidget {
  /// 0→1 entrance animation, driven by the orchestrator when this page is
  /// active.
  final Animation<double> entrance;

  const OnboardingFrontierView({
    super.key,
    required this.entrance,
  });

  // Axis labels — kept as named constants so the test can assert them without
  // duplicating raw strings.
  static const String yAxisLabel = '기대 수익';
  static const String xAxisLabel = '위험 (변동성)';
  static const String highLabel = '높음';
  static const String lowLabel = '낮음';
  static const String tooltipLabel = '추천 포트폴리오';

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, child) {
        final t = entrance.value.clamp(0.0, 1.0);
        // Whole-visual reveal: fade + a small upward translate + subtle
        // scale-in, driven by `entrance` (the orchestrator already curves it
        // with WeRoboMotion.enter).
        final opacity = t;
        final dy = (1 - t) * 16;
        final scale = 0.97 + 0.03 * t;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      // Child is built once; only the painter listens to `entrance` for the
      // curve-draw fraction so the scatter/axes stay put while the curve grows.
      child: Semantics(
        label: '$yAxisLabel · $xAxisLabel · $tooltipLabel',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WeRoboSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              color: tc.card,
              borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
              border: Border.all(color: tc.border),
              boxShadow: WeRoboElevation.subtle,
            ),
            padding: const EdgeInsets.fromLTRB(
              WeRoboSpacing.md,
              WeRoboSpacing.lg,
              WeRoboSpacing.lg,
              WeRoboSpacing.md,
            ),
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _FrontierPainter(
                      entrance: entrance,
                      curveColor: WeRoboColors.primary,
                      scatterColor: WeRoboColors.assetUSValue,
                      axisColor: tc.textTertiary,
                      axisLabelColor: tc.textSecondary,
                      tickColor: tc.textTertiary,
                      tooltipFill: WeRoboColors.primary,
                      tooltipTextColor: WeRoboColors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the static efficient-frontier illustration:
/// - L-shaped axis with the Y label `기대 수익` and X label `위험 (변동성)`,
///   높음/낮음 ticks, and a right-pointing arrowhead on the X axis,
/// - a light-blue scatter cloud in the interior/lower region,
/// - a bold navy frontier curve drawn left→right on `entrance` with a right
///   arrowhead at its tip,
/// - a highlighted navy dot on the upper-middle of the curve with a rounded
///   pill tooltip (`추천 포트폴리오`) and a short leader to the dot.
class _FrontierPainter extends CustomPainter {
  final Animation<double> entrance;
  final Color curveColor;
  final Color scatterColor;
  final Color axisColor;
  final Color axisLabelColor;
  final Color tickColor;
  final Color tooltipFill;
  final Color tooltipTextColor;

  _FrontierPainter({
    required this.entrance,
    required this.curveColor,
    required this.scatterColor,
    required this.axisColor,
    required this.axisLabelColor,
    required this.tickColor,
    required this.tooltipFill,
    required this.tooltipTextColor,
  }) : super(repaint: entrance);

  // The plot rectangle is inset inside the painter so axis labels/ticks have
  // room. The frontier math (frontierCurvePointForT) is evaluated against this
  // inner plot size, then offset into place.
  static const double _leftPad = 36;
  static const double _rightPad = 14;
  static const double _topPad = 14;
  static const double _bottomPad = 42;

  // `추천 포트폴리오` dot sits on the upper-middle of the curve.
  static const double _highlightT = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final t = entrance.value.clamp(0.0, 1.0);

    final plot = Rect.fromLTRB(
      _leftPad,
      _topPad,
      size.width - _rightPad,
      size.height - _bottomPad,
    );
    if (plot.width <= 0 || plot.height <= 0) return;
    final plotSize = Size(plot.width, plot.height);

    _paintAxes(canvas, size, plot);

    // Scatter and axes fade in over the first 45% of the entrance; the curve
    // draws over the back ~70%; the highlight dot + tooltip pop near the end.
    final scatterT = _interval(t, 0.0, 0.45);
    final curveT = _interval(t, 0.30, 1.0);
    final dotT = _interval(t, 0.78, 1.0);

    _paintFrontierFill(canvas, plot, plotSize, curveT);
    _paintScatter(canvas, plot, plotSize, scatterT);
    _paintFrontier(canvas, plot, plotSize, curveT);
    _paintHighlight(canvas, plot, plotSize, dotT);
  }

  /// Linear sub-progress of [t] mapped from [begin]..[end] → 0..1.
  double _interval(double t, double begin, double end) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return (t - begin) / (end - begin);
  }

  Offset _curvePoint(double tween, Rect plot, Size plotSize) {
    final local = frontierCurvePointForT(tween, plotSize);
    return plot.topLeft + local;
  }

  void _paintAxes(Canvas canvas, Size size, Rect plot) {
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Y axis (left, vertical) and X axis (bottom, horizontal) forming an L.
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);

    // Right-pointing arrowhead at the X-axis tip.
    final xTip = plot.bottomRight;
    final arrow = Path()
      ..moveTo(xTip.dx, xTip.dy)
      ..lineTo(xTip.dx - 7, xTip.dy - 4)
      ..lineTo(xTip.dx - 7, xTip.dy + 4)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = axisColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // Up-pointing arrowhead at the Y-axis tip.
    final yTip = plot.topLeft;
    final yArrow = Path()
      ..moveTo(yTip.dx, yTip.dy)
      ..lineTo(yTip.dx - 4, yTip.dy + 7)
      ..lineTo(yTip.dx + 4, yTip.dy + 7)
      ..close();
    canvas.drawPath(
      yArrow,
      Paint()
        ..color = axisColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // Y-axis label, rotated to read bottom-to-top along the axis.
    canvas.save();
    canvas.translate(plot.left - 22, plot.center.dy);
    canvas.rotate(-pi / 2);
    _paintText(
      canvas,
      OnboardingFrontierView.yAxisLabel,
      Offset.zero,
      _labelStyle(axisLabelColor),
      anchor: _TextAnchor.center,
    );
    canvas.restore();

    // Y ticks sit just inside the top/bottom of the plot, hugging the Y axis:
    // 높음 near the top, 낮음 near the bottom.
    _paintText(
      canvas,
      OnboardingFrontierView.highLabel,
      Offset(plot.left + 4, plot.top + 2),
      _tickStyle(tickColor),
      anchor: _TextAnchor.topLeft,
    );
    _paintText(
      canvas,
      OnboardingFrontierView.lowLabel,
      Offset(plot.left + 4, plot.bottom - 4),
      _tickStyle(tickColor),
      anchor: _TextAnchor.bottomLeft,
    );

    // X ticks sit just below the axis line so they don't collide with the Y
    // ticks at the origin: 낮음 toward the left, 높음 toward the right.
    _paintText(
      canvas,
      OnboardingFrontierView.lowLabel,
      Offset(plot.left + 2, plot.bottom + 6),
      _tickStyle(tickColor),
      anchor: _TextAnchor.topLeft,
    );
    _paintText(
      canvas,
      OnboardingFrontierView.highLabel,
      Offset(plot.right - 2, plot.bottom + 6),
      _tickStyle(tickColor),
      anchor: _TextAnchor.topRight,
    );

    // X-axis label `위험 (변동성)` centered on its own line below the ticks.
    _paintText(
      canvas,
      OnboardingFrontierView.xAxisLabel,
      Offset(plot.center.dx, plot.bottom + 22),
      _labelStyle(axisLabelColor),
      anchor: _TextAnchor.topCenter,
    );
  }

  /// A deterministic light-blue scatter cloud (~24 dots) of sub-optimal
  /// portfolios. Each dot is anchored on the frontier at a random t, then
  /// pushed DOWN-RIGHT so it can never sit above the curve (the frontier is the
  /// optimal upper boundary). Seeded for stability; dots fade in with
  /// [progress].
  void _paintScatter(Canvas canvas, Rect plot, Size plotSize, double progress) {
    if (progress <= 0) return;
    final rng = Random(57);
    const count = 24;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final anchor = _curvePoint(rng.nextDouble(), plot, plotSize);
      // dx ≥ 0 and dy ≥ 0 keep the dot below the (monotonically rising) curve.
      final dx = rng.nextDouble() * plot.width * 0.10;
      final dy = plot.height * 0.04 + rng.nextDouble() * plot.height * 0.34;
      final cx = (anchor.dx + dx).clamp(plot.left, plot.right);
      final cy = (anchor.dy + dy).clamp(plot.top, plot.bottom);
      final r = (1.8 + rng.nextDouble() * 1.8) * progress;
      final localT =
          ((progress - i / count * 0.4) / (1 - 0.4)).clamp(0.0, 1.0);
      dotPaint.color = scatterColor.withValues(alpha: 0.38 * localT);
      canvas.drawCircle(Offset(cx, cy), r, dotPaint);
    }
  }

  /// A subtle navy→transparent gradient filling the area beneath the frontier
  /// curve (down to the X axis), revealed alongside the curve via [progress].
  void _paintFrontierFill(
    Canvas canvas,
    Rect plot,
    Size plotSize,
    double progress,
  ) {
    if (progress <= 0) return;
    const sampleCount = 72;
    final start = _curvePoint(0, plot, plotSize);
    final path = Path()..moveTo(start.dx, start.dy);
    var last = start;
    for (var i = 1; i <= sampleCount; i++) {
      final tween = i / sampleCount;
      if (tween >= progress) {
        last = _curvePoint(progress, plot, plotSize);
        path.lineTo(last.dx, last.dy);
        break;
      }
      final p = _curvePoint(tween, plot, plotSize);
      path.lineTo(p.dx, p.dy);
      last = p;
    }
    path
      ..lineTo(last.dx, plot.bottom)
      ..lineTo(start.dx, plot.bottom)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          curveColor.withValues(alpha: 0.10),
          curveColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(plot.left, plot.top, plot.right, plot.bottom));
    canvas.drawPath(path, fill);
  }

  /// Strokes the frontier as a dense polyline sampled from
  /// [frontierCurvePointForT], revealed up to [progress] (0..1). At full
  /// progress an arrowhead is drawn at the tip.
  void _paintFrontier(
    Canvas canvas,
    Rect plot,
    Size plotSize,
    double progress,
  ) {
    if (progress <= 0) return;
    const sampleCount = 72;
    final start = _curvePoint(0, plot, plotSize);
    final path = Path()..moveTo(start.dx, start.dy);
    Offset tip = start;
    Offset prev = start;

    for (var i = 1; i <= sampleCount; i++) {
      final tween = i / sampleCount;
      if (tween >= progress) {
        tip = _curvePoint(progress, plot, plotSize);
        path.lineTo(tip.dx, tip.dy);
        break;
      }
      final p = _curvePoint(tween, plot, plotSize);
      path.lineTo(p.dx, p.dy);
      prev = p;
      tip = p;
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Arrowhead at the leading tip, oriented along the curve's local heading.
    if (progress >= 0.999) {
      final dir = tip - prev;
      final angle = dir.distance < 0.001 ? 0.0 : atan2(dir.dy, dir.dx);
      _paintArrowhead(canvas, tip, angle, curveColor);
    }
  }

  void _paintArrowhead(Canvas canvas, Offset tip, double angle, Color color) {
    const len = 9.0;
    const half = 5.0;
    final back = Offset(
      tip.dx - cos(angle) * len,
      tip.dy - sin(angle) * len,
    );
    final normal = Offset(-sin(angle), cos(angle));
    final p1 = back + normal * half;
    final p2 = back - normal * half;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Highlighted navy dot on the upper-middle of the curve with a soft glow
  /// and a rounded pill tooltip above it (`추천 포트폴리오`), joined by a
  /// short leader line. Scales/fades in with [progress].
  void _paintHighlight(
    Canvas canvas,
    Rect plot,
    Size plotSize,
    double progress,
  ) {
    if (progress <= 0) return;
    final dot = _curvePoint(_highlightT, plot, plotSize);

    // Glow.
    canvas.drawCircle(
      dot,
      14 * progress,
      Paint()..color = curveColor.withValues(alpha: 0.18 * progress),
    );
    // Core dot + white ring.
    canvas.drawCircle(
      dot,
      6 * progress,
      Paint()..color = curveColor.withValues(alpha: progress),
    );
    canvas.drawCircle(
      dot,
      6 * progress,
      Paint()
        ..color = WeRoboColors.white.withValues(alpha: progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Pill tooltip above-left of the dot.
    final tp = _layoutText(
      OnboardingFrontierView.tooltipLabel,
      _tooltipStyle(tooltipTextColor.withValues(alpha: progress)),
    );
    const padH = 9.0;
    const padV = 5.0;
    final pillW = tp.width + padH * 2;
    final pillH = tp.height + padV * 2;

    // Prefer placing the pill up-and-left of the dot; clamp into the plot.
    var pillLeft = dot.dx - pillW * 0.5;
    var pillTop = dot.dy - 16 - pillH;
    pillLeft = pillLeft.clamp(plot.left, plot.right - pillW);
    pillTop = pillTop.clamp(plot.top, plot.bottom - pillH);
    final pillRect = Rect.fromLTWH(pillLeft, pillTop, pillW, pillH);

    // Leader line from pill bottom-center to the dot.
    canvas.drawLine(
      Offset(pillRect.center.dx, pillRect.bottom),
      dot,
      Paint()
        ..color = curveColor.withValues(alpha: 0.55 * progress)
        ..strokeWidth = 1.2,
    );

    final rrect = RRect.fromRectAndRadius(
      pillRect,
      const Radius.circular(WeRoboColors.radiusFull),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = tooltipFill.withValues(alpha: progress),
    );
    _paintText(
      canvas,
      OnboardingFrontierView.tooltipLabel,
      pillRect.center,
      _tooltipStyle(tooltipTextColor.withValues(alpha: progress)),
      anchor: _TextAnchor.center,
    );
  }

  // ---- text helpers ----

  TextStyle _labelStyle(Color color) => WeRoboTypography.caption.copyWith(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  TextStyle _tickStyle(Color color) => WeRoboTypography.caption.copyWith(
        color: color,
        fontSize: 10,
      );

  TextStyle _tooltipStyle(Color color) => WeRoboTypography.caption.copyWith(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  TextPainter _layoutText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    return tp;
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    required _TextAnchor anchor,
  }) {
    final tp = _layoutText(text, style);
    final dx = switch (anchor) {
      _TextAnchor.center || _TextAnchor.topCenter => at.dx - tp.width / 2,
      _TextAnchor.topLeft || _TextAnchor.bottomLeft => at.dx,
      _TextAnchor.topRight || _TextAnchor.bottomRight => at.dx - tp.width,
    };
    final dy = switch (anchor) {
      _TextAnchor.center => at.dy - tp.height / 2,
      _TextAnchor.topLeft ||
      _TextAnchor.topCenter ||
      _TextAnchor.topRight =>
        at.dy,
      _TextAnchor.bottomLeft || _TextAnchor.bottomRight => at.dy - tp.height,
    };
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _FrontierPainter old) {
    return old.entrance.value != entrance.value ||
        old.curveColor != curveColor ||
        old.scatterColor != scatterColor ||
        old.axisColor != axisColor ||
        old.axisLabelColor != axisLabelColor ||
        old.tickColor != tickColor ||
        old.tooltipFill != tooltipFill ||
        old.tooltipTextColor != tooltipTextColor;
  }
}

enum _TextAnchor {
  center,
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomRight,
}
