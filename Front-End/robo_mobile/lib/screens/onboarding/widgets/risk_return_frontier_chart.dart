import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

/// Bright accent blue for the in-range selection (callout, handle, curve
/// highlight). Matches the Figma 포트폴리오 설계 chart — distinct from the
/// deep-navy brand CTA color so the interactive point reads as "live".
const Color kFrontierAccentBlue = Color(0xFF3182F6);

/// Amber shown when the selected point sits past the suitable risk band
/// (over-risking). Matches the orange callout in the out-of-range state.
const Color kFrontierAccentOrange = Color(0xFFF59E0B);

/// Coral for the out-of-range hatched zones. Re-used by the screen for the
/// drawdown stat values and the warning banner so the danger cue is one hue.
const Color kFrontierDangerCoral = Color(0xFFF04452);

/// Returns the upper, economically efficient boundary of a frontier feed.
///
/// Optimizer output can contain duplicate-volatility points, tiny return
/// reversals, or locally convex numerical noise. Connecting those samples
/// directly makes the curve bend downward near its high-risk end. The chart
/// should only offer portfolios on the increasing, concave upper envelope:
/// more risk never produces a lower expected return, and marginal return
/// gradually diminishes as risk rises.
List<MobileFrontierPreviewPoint> efficientFrontierDisplayPoints(
  List<MobileFrontierPreviewPoint> points,
) {
  const epsilon = 1e-9;
  final ordered = points
      .where(
        (point) => point.volatility.isFinite && point.expectedReturn.isFinite,
      )
      .toList()
    ..sort((a, b) {
      final byVolatility = a.volatility.compareTo(b.volatility);
      if (byVolatility != 0) return byVolatility;
      return b.expectedReturn.compareTo(a.expectedReturn);
    });

  if (ordered.length < 2) {
    return List<MobileFrontierPreviewPoint>.unmodifiable(ordered);
  }

  final increasing = <MobileFrontierPreviewPoint>[];
  var bestReturn = -double.infinity;
  var previousVolatility = -double.infinity;
  for (final point in ordered) {
    if ((point.volatility - previousVolatility).abs() <= epsilon) {
      continue;
    }
    previousVolatility = point.volatility;
    if (point.expectedReturn <= bestReturn + epsilon) {
      continue;
    }
    increasing.add(point);
    bestReturn = point.expectedReturn;
  }

  final envelope = <MobileFrontierPreviewPoint>[];
  for (final point in increasing) {
    while (envelope.length >= 2) {
      final a = envelope[envelope.length - 2];
      final b = envelope.last;
      final previousSlope =
          (b.expectedReturn - a.expectedReturn) / (b.volatility - a.volatility);
      final nextSlope = (point.expectedReturn - b.expectedReturn) /
          (point.volatility - b.volatility);
      if (nextSlope <= previousSlope + epsilon) {
        break;
      }
      envelope.removeLast();
    }
    envelope.add(point);
  }

  return List<MobileFrontierPreviewPoint>.unmodifiable(envelope);
}

/// Interactive efficient-frontier chart for the 기대수익률/리스크 설정 page
/// (capstone §4.4). Plots the real (volatility, expected-return) frontier
/// points, shades the user's suitable risk band, and lets the user drag a
/// point left/right along the curve. The parent owns [selectedPosition];
/// the chart maps a drag to the nearest point index and reports it via
/// [onPositionChanged].
class RiskReturnFrontierChart extends StatefulWidget {
  final List<MobileFrontierPreviewPoint> points;
  final int selectedPosition;
  final int recommendedPosition;
  final int inRangeLow;
  final int inRangeHigh;
  final ValueChanged<int> onPositionChanged;
  final ValueChanged<bool>? onDragStateChanged;

  const RiskReturnFrontierChart({
    super.key,
    required this.points,
    required this.selectedPosition,
    required this.recommendedPosition,
    required this.inRangeLow,
    required this.inRangeHigh,
    required this.onPositionChanged,
    this.onDragStateChanged,
  });

  @override
  State<RiskReturnFrontierChart> createState() =>
      _RiskReturnFrontierChartState();
}

class _RiskReturnFrontierChartState extends State<RiskReturnFrontierChart>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final Animation<double> _reveal;
  late final AnimationController _pulseController;
  bool _isDragging = false;

  // Plot insets (logical px) reserved inside the canvas for axis titles
  // (top), x-tick + band labels (bottom), and small side breathing room.
  static const double _insetL = 8;
  static const double _insetR = 8;
  static const double _insetTop = 26;
  static const double _insetBottom = 34;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      duration: WeRoboMotion.chartDraw,
      vsync: this,
    )..forward();
    _reveal = CurvedAnimation(
      parent: _revealController,
      curve: WeRoboMotion.chartReveal,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _revealController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _outOfRange =>
      widget.selectedPosition < widget.inRangeLow ||
      widget.selectedPosition > widget.inRangeHigh;

  Rect _plotRect(Size size) => Rect.fromLTWH(
        _insetL,
        _insetTop,
        size.width - _insetL - _insetR,
        size.height - _insetTop - _insetBottom,
      );

  ({double min, double max}) get _volBounds {
    final vols = widget.points.map((p) => p.volatility);
    final lo = vols.reduce(math.min);
    final hi = vols.reduce(math.max);
    final pad = (hi - lo) * 0.08 + 0.003;
    return (min: math.max(0, lo - pad), max: hi + pad);
  }

  ({double min, double max}) get _retBounds {
    final rets = widget.points.map((p) => p.expectedReturn);
    final lo = rets.reduce(math.min);
    final hi = rets.reduce(math.max);
    final pad = (hi - lo) * 0.20 + 0.003;
    return (min: math.max(0, lo - pad), max: hi + pad);
  }

  int _nearestPosition(Offset local, Size size) {
    final plot = _plotRect(size);
    final vb = _volBounds;
    final span = (vb.max - vb.min).abs() < 1e-9 ? 1.0 : vb.max - vb.min;
    var bestDist = double.infinity;
    var best = 0;
    for (var i = 0; i < widget.points.length; i++) {
      final x = plot.left +
          (widget.points[i].volatility - vb.min) / span * plot.width;
      final d = (x - local.dx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _moveTo(Offset local, Size size) {
    final pos = _nearestPosition(local, size);
    if (pos != widget.selectedPosition) {
      widget.onPositionChanged(pos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final accent = _outOfRange ? kFrontierAccentOrange : kFrontierAccentBlue;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (d) => _moveTo(d.localPosition, size),
          onPanStart: (d) {
            setState(() => _isDragging = true);
            widget.onDragStateChanged?.call(true);
            _moveTo(d.localPosition, size);
          },
          onPanUpdate: (d) => _moveTo(d.localPosition, size),
          onPanEnd: (_) {
            setState(() => _isDragging = false);
            widget.onDragStateChanged?.call(false);
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_revealController, _pulseController]),
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _RiskReturnPainter(
                  points: widget.points,
                  selectedPosition: widget.selectedPosition,
                  inRangeLow: widget.inRangeLow,
                  inRangeHigh: widget.inRangeHigh,
                  volBounds: _volBounds,
                  retBounds: _retBounds,
                  plotRect: _plotRect(size),
                  reveal: _reveal.value,
                  pulse: _pulseController.value,
                  isDragging: _isDragging,
                  accent: accent,
                  gridColor: tc.border,
                  labelColor: tc.textTertiary,
                  axisTitleColor: tc.textSecondary,
                  bandLabelColor: WeRoboColors.primaryDark,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RiskReturnPainter extends CustomPainter {
  final List<MobileFrontierPreviewPoint> points;
  final int selectedPosition;
  final int inRangeLow;
  final int inRangeHigh;
  final ({double min, double max}) volBounds;
  final ({double min, double max}) retBounds;
  final Rect plotRect;
  final double reveal;
  final double pulse;
  final bool isDragging;
  final Color accent;
  final Color gridColor;
  final Color labelColor;
  final Color axisTitleColor;
  final Color bandLabelColor;

  _RiskReturnPainter({
    required this.points,
    required this.selectedPosition,
    required this.inRangeLow,
    required this.inRangeHigh,
    required this.volBounds,
    required this.retBounds,
    required this.plotRect,
    required this.reveal,
    required this.pulse,
    required this.isDragging,
    required this.accent,
    required this.gridColor,
    required this.labelColor,
    required this.axisTitleColor,
    required this.bandLabelColor,
  });

  double get _volSpan => (volBounds.max - volBounds.min).abs() < 1e-9
      ? 1
      : volBounds.max - volBounds.min;
  double get _retSpan => (retBounds.max - retBounds.min).abs() < 1e-9
      ? 1
      : retBounds.max - retBounds.min;

  double _x(double vol) =>
      plotRect.left + (vol - volBounds.min) / _volSpan * plotRect.width;

  double _y(double ret) =>
      plotRect.bottom - (ret - retBounds.min) / _retSpan * plotRect.height;

  Offset _offsetAt(int i) =>
      Offset(_x(points[i].volatility), _y(points[i].expectedReturn));

  int _clampPos(int i) => i.clamp(0, points.length - 1);

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatchBands(canvas);
    _paintGridAndTicks(canvas);
    _paintAxisTitles(canvas);
    _paintCurve(canvas);
    _paintBandLabel(canvas);
    _paintHandleAndCallout(canvas);
  }

  void _paintHatchBands(Canvas canvas) {
    final loX = _x(points[_clampPos(inRangeLow)].volatility);
    final hiX = _x(points[_clampPos(inRangeHigh)].volatility);
    if (loX > plotRect.left + 0.5) {
      _hatchRect(
        canvas,
        Rect.fromLTRB(plotRect.left, plotRect.top, loX, plotRect.bottom),
      );
    }
    if (hiX < plotRect.right - 0.5) {
      _hatchRect(
        canvas,
        Rect.fromLTRB(hiX, plotRect.top, plotRect.right, plotRect.bottom),
      );
    }
  }

  void _hatchRect(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()..color = kFrontierDangerCoral.withValues(alpha: 0.05),
    );
    final line = Paint()
      ..color = kFrontierDangerCoral.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    const gap = 7.0;
    for (var d = -rect.height; d < rect.width; d += gap) {
      canvas.drawLine(
        Offset(rect.left + d, rect.bottom),
        Offset(rect.left + d + rect.height, rect.top),
        line,
      );
    }
    canvas.restore();
  }

  void _paintGridAndTicks(Canvas canvas) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 0.6;
    for (final v in _volTicks()) {
      final x = _x(v);
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        grid,
      );
      _drawText(
        canvas,
        '±${(v * 100).toStringAsFixed(0)}%',
        Offset(x, plotRect.bottom + 4),
        labelColor,
        align: _Anchor.topCenter,
      );
    }
    for (final r in _retTicks()) {
      final y = _y(r);
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        grid,
      );
      _drawText(
        canvas,
        '${(r * 100).toStringAsFixed(0)}%',
        Offset(plotRect.left + 1, y),
        labelColor,
        align: _Anchor.leftCenter,
      );
    }
  }

  List<double> _volTicks() {
    const step = 0.05;
    final ticks = <double>[];
    var v = (volBounds.min / step).ceilToDouble() * step;
    while (v <= volBounds.max + 1e-9) {
      if (v >= volBounds.min - 1e-9) {
        ticks.add(double.parse(v.toStringAsFixed(4)));
      }
      v += step;
    }
    return ticks;
  }

  List<double> _retTicks() {
    final range = _retSpan;
    final step = range > 0.06 ? 0.02 : (range > 0.025 ? 0.01 : 0.005);
    final ticks = <double>[];
    var r = (retBounds.min / step).ceilToDouble() * step;
    while (r <= retBounds.max + 1e-9) {
      if (r >= retBounds.min - 1e-9) {
        ticks.add(double.parse(r.toStringAsFixed(4)));
      }
      r += step;
    }
    return ticks;
  }

  void _paintAxisTitles(Canvas canvas) {
    _drawText(
      canvas,
      '↑ 기대수익률',
      Offset(plotRect.left, 4),
      axisTitleColor,
      align: _Anchor.topLeft,
      bold: true,
    );
    _drawText(
      canvas,
      '리스크 →',
      Offset(plotRect.right, 4),
      axisTitleColor,
      align: _Anchor.topRight,
      bold: true,
    );
  }

  void _paintCurve(Canvas canvas) {
    if (points.length < 2) return;
    final maxI = (reveal * (points.length - 1)).floor().clamp(
          0,
          points.length - 1,
        );
    if (maxI < 1) return;
    final base = Path()..moveTo(_offsetAt(0).dx, _offsetAt(0).dy);
    for (var i = 1; i <= maxI; i++) {
      final o = _offsetAt(i);
      base.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      base,
      Paint()
        ..color = kFrontierAccentBlue.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final selI = _clampPos(selectedPosition).clamp(0, maxI);
    if (selI >= 1) {
      final hi = Path()..moveTo(_offsetAt(0).dx, _offsetAt(0).dy);
      for (var i = 1; i <= selI; i++) {
        final o = _offsetAt(i);
        hi.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        hi,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintBandLabel(Canvas canvas) {
    final loX = _x(points[_clampPos(inRangeLow)].volatility);
    final hiX = _x(points[_clampPos(inRangeHigh)].volatility);
    final cx = ((loX + hiX) / 2).clamp(plotRect.left + 28, plotRect.right - 28);
    _drawText(
      canvas,
      '내 적합 범위',
      Offset(cx, plotRect.bottom + 18),
      bandLabelColor,
      align: _Anchor.topCenter,
      bold: true,
    );
  }

  void _paintHandleAndCallout(Canvas canvas) {
    final pos = _offsetAt(_clampPos(selectedPosition));
    final pulseT = (math.sin(pulse * 2 * math.pi) + 1) / 2;
    final glowR = (isDragging ? 26.0 : 18.0) + pulseT * 4;
    canvas.drawCircle(
      pos,
      glowR,
      Paint()..color = accent.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      pos,
      glowR * 0.62,
      Paint()..color = accent.withValues(alpha: 0.18),
    );
    final r = isDragging ? 13.0 : 11.0;
    canvas.drawCircle(pos, r, Paint()..color = accent);
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final plus = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(pos.dx - 4, pos.dy),
      Offset(pos.dx + 4, pos.dy),
      plus,
    );
    canvas.drawLine(
      Offset(pos.dx, pos.dy - 4),
      Offset(pos.dx, pos.dy + 4),
      plus,
    );
    final ret = points[_clampPos(selectedPosition)].expectedReturn * 100;
    _paintCallout(canvas, pos, '+${ret.toStringAsFixed(1)}%');
  }

  void _paintCallout(Canvas canvas, Offset anchor, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: WeRoboFonts.number,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padH = 9.0;
    const padV = 4.0;
    const tail = 6.0;
    const gap = 13.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    final left = (anchor.dx - w / 2).clamp(
      plotRect.left,
      plotRect.right - w,
    );
    final top = (anchor.dy - gap - tail - h).clamp(0.0, plotRect.bottom);
    final rect = Rect.fromLTWH(left, top, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = accent,
    );
    final tailX = anchor.dx.clamp(rect.left + tail, rect.right - tail);
    canvas.drawPath(
      Path()
        ..moveTo(tailX - tail, rect.bottom)
        ..lineTo(tailX + tail, rect.bottom)
        ..lineTo(tailX, rect.bottom + tail)
        ..close(),
      Paint()..color = accent,
    );
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    Color color, {
    _Anchor align = _Anchor.topLeft,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: WeRoboFonts.caption,
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = pos.dx;
    var dy = pos.dy;
    switch (align) {
      case _Anchor.topLeft:
        break;
      case _Anchor.topCenter:
        dx -= tp.width / 2;
        break;
      case _Anchor.topRight:
        dx -= tp.width;
        break;
      case _Anchor.leftCenter:
        dy -= tp.height / 2;
        break;
    }
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RiskReturnPainter old) {
    return old.selectedPosition != selectedPosition ||
        old.inRangeLow != inRangeLow ||
        old.inRangeHigh != inRangeHigh ||
        old.reveal != reveal ||
        old.pulse != pulse ||
        old.isDragging != isDragging ||
        old.accent != accent ||
        old.gridColor != gridColor ||
        old.labelColor != labelColor ||
        old.plotRect != plotRect ||
        old.points != points;
  }
}

enum _Anchor { topLeft, topCenter, topRight, leftCenter }
