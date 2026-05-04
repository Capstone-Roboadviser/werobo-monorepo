import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

class EfficientFrontierChart extends StatefulWidget {
  final ValueChanged<double>? onPositionChanged;
  final ValueChanged<bool>? onDragStateChanged;
  final List<MobileFrontierPreviewPoint>? previewPoints;
  final int? selectedPreviewPosition;
  final ValueChanged<int>? onPreviewPointChanged;

  const EfficientFrontierChart({
    super.key,
    this.onPositionChanged,
    this.onDragStateChanged,
    this.previewPoints,
    this.selectedPreviewPosition,
    this.onPreviewPointChanged,
  });

  @override
  State<EfficientFrontierChart> createState() => _EfficientFrontierChartState();
}

class _EfficientFrontierChartState extends State<EfficientFrontierChart>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnimation;
  late Animation<double> _dotAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Position along the curve: 0.0 = start, 1.0 = end
  double _dotT = 0.45;
  bool _isDragging = false;

  bool get _hasPreviewPoints =>
      widget.previewPoints != null && widget.previewPoints!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _curveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _dotAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant EfficientFrontierChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasPreviewPoints) {
      return;
    }
    final selectedPreviewPosition = widget.selectedPreviewPosition;
    final previewPoints = widget.previewPoints!;
    if (selectedPreviewPosition == null ||
        selectedPreviewPosition < 0 ||
        selectedPreviewPosition >= previewPoints.length) {
      return;
    }
    final nextDotT = previewPoints.length <= 1
        ? 0.45
        : selectedPreviewPosition / (previewPoints.length - 1);
    if ((_dotT - nextDotT).abs() > 0.0001) {
      setState(() => _dotT = nextDotT);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Convert a t value (0..1) to canvas coordinates
  Offset _tToPoint(double t, double w, double h) {
    final x = w * 0.15 + (w * 0.7) * t;
    final normalizedY = 0.85 - 0.7 * sqrt(t) + 0.15 * t;
    final y = h * normalizedY;
    return Offset(x, y);
  }

  /// Map screen x position directly to t for smooth dragging
  double _screenToT(Offset localPos, double w, double h) {
    // x = w*0.15 + w*0.7*t  =>  t = (x - w*0.15) / (w*0.7)
    final t = (localPos.dx - w * 0.15) / (w * 0.7);
    return t.clamp(0.0, 1.0);
  }

  int _nearestPreviewPosition(Offset localPos, double w, double h) {
    final previewPoints = widget.previewPoints!;
    final minVolatility = previewPoints.map((p) => p.volatility).reduce(min);
    final maxVolatility = previewPoints.map((p) => p.volatility).reduce(max);
    final minExpectedReturn =
        previewPoints.map((p) => p.expectedReturn).reduce(min);
    final maxExpectedReturn =
        previewPoints.map((p) => p.expectedReturn).reduce(max);

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (int i = 0; i < previewPoints.length; i++) {
      final point = _previewPointToOffset(
        previewPoints[i],
        w,
        h,
        minVolatility,
        maxVolatility,
        minExpectedReturn,
        maxExpectedReturn,
      );
      final distance = (localPos - point).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  Offset _previewPointToOffset(
    MobileFrontierPreviewPoint point,
    double w,
    double h,
    double minVolatility,
    double maxVolatility,
    double minExpectedReturn,
    double maxExpectedReturn,
  ) {
    const leftPaddingRatio = 0.15;
    const rightPaddingRatio = 0.85;
    const topPaddingRatio = 0.12;
    const bottomPaddingRatio = 0.86;

    final normalizedVolatility = maxVolatility == minVolatility
        ? 0.5
        : (point.volatility - minVolatility) / (maxVolatility - minVolatility);
    final normalizedExpectedReturn = maxExpectedReturn == minExpectedReturn
        ? 0.5
        : (point.expectedReturn - minExpectedReturn) /
            (maxExpectedReturn - minExpectedReturn);

    final x = w * leftPaddingRatio +
        (w * (rightPaddingRatio - leftPaddingRatio)) * normalizedVolatility;
    final y = h * bottomPaddingRatio -
        (h * (bottomPaddingRatio - topPaddingRatio)) * normalizedExpectedReturn;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _pulseController]),
      builder: (context, _) {
        // 1:3 height:width ratio per 2026-05-05 user notes — the horizontal
        // layout makes the frontier curve slope readable on small screens.
        return AspectRatio(
          aspectRatio: 3.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return GestureDetector(
                onPanStart: (details) {
                  if (_controller.isCompleted) {
                    late final Offset dotPos;
                    if (_hasPreviewPoints) {
                      final pp = widget.previewPoints!;
                      dotPos = _previewPointToOffset(
                        pp[widget.selectedPreviewPosition ?? pp.length ~/ 2],
                        w,
                        h,
                        pp.map((p) => p.volatility).reduce(min),
                        pp.map((p) => p.volatility).reduce(max),
                        pp.map((p) => p.expectedReturn).reduce(min),
                        pp.map((p) => p.expectedReturn).reduce(max),
                      );
                    } else {
                      dotPos = _tToPoint(_dotT, w, h);
                    }
                    if ((details.localPosition - dotPos).distance < 60) {
                      setState(() => _isDragging = true);
                      widget.onDragStateChanged?.call(true);
                    }
                  }
                },
                onPanUpdate: (details) {
                  if (_isDragging) {
                    if (_hasPreviewPoints) {
                      final previewPosition =
                          _nearestPreviewPosition(details.localPosition, w, h);
                      final nextDotT = widget.previewPoints!.length <= 1
                          ? 0.45
                          : previewPosition /
                              (widget.previewPoints!.length - 1);
                      setState(() => _dotT = nextDotT);
                      widget.onPreviewPointChanged?.call(previewPosition);
                    } else {
                      setState(() {
                        _dotT = _screenToT(details.localPosition, w, h);
                      });
                      widget.onPositionChanged?.call(_dotT);
                    }
                  }
                },
                onPanEnd: (_) {
                  if (_isDragging) {
                    setState(() => _isDragging = false);
                    widget.onDragStateChanged?.call(false);
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  height: h,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CustomPaint(
                      painter: _FrontierPainter(
                        curveProgress: _curveAnimation.value,
                        dotProgress: _dotAnimation.value,
                        dotT: _dotT,
                        isDragging: _isDragging,
                        pulseValue: _pulseAnimation.value,
                        previewPoints: widget.previewPoints,
                        selectedPreviewPosition: widget.selectedPreviewPosition,
                        gridColor: tc.border,
                        textTertiaryColor: tc.textTertiary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FrontierPainter extends CustomPainter {
  final double curveProgress;
  final double dotProgress;
  final double dotT;
  final bool isDragging;
  final double pulseValue;
  final List<MobileFrontierPreviewPoint>? previewPoints;
  final int? selectedPreviewPosition;
  final Color gridColor;
  final Color textTertiaryColor;

  _FrontierPainter({
    required this.curveProgress,
    required this.dotProgress,
    required this.dotT,
    required this.isDragging,
    required this.pulseValue,
    required this.previewPoints,
    required this.selectedPreviewPosition,
    required this.gridColor,
    required this.textTertiaryColor,
  });

  Offset _tToPoint(double t, double w, double h) {
    final x = w * 0.15 + (w * 0.7) * t;
    final normalizedY = 0.85 - 0.7 * sqrt(t) + 0.15 * t;
    final y = h * normalizedY;
    return Offset(x, y);
  }

  /// Smooths a sparse set of (vol, ret) anchor points into a monotone-X
  /// cubic Bezier approximating the efficient frontier curve. The result
  /// is intentionally idealized (not raw scatter) — the curve communicates
  /// "lower vol = lower return, higher vol = higher return" visually.
  Path _buildFrontierPath(List<Offset> points, Size size) {
    if (points.isEmpty) return Path();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final c1 = Offset(p0.dx + (p1.dx - p0.dx) / 3, p0.dy);
      final c2 = Offset(p0.dx + 2 * (p1.dx - p0.dx) / 3, p1.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    }
    return path;
  }

  /// Returns the (x, y) in chart coords for an asset class label, mapped
  /// monotonically along the curve from defensive (left) to aggressive
  /// (right). Exact (vol, return) intentionally ignored — labels are
  /// placed for visual order, not data precision (per 2026-05-05 user
  /// notes).
  Offset _assetAnchor(AssetClass cls, List<Offset> curvePoints) {
    // 7 classes → 7 evenly-spaced anchors along the curve.
    // index 0 (cash) → curvePoints.first (leftmost)
    // index 6 (newGrowth) → curvePoints.last (rightmost)
    final i = cls.index;
    final n = AssetClass.values.length - 1;
    final t = i / n;
    final pos = (t * (curvePoints.length - 1)).round();
    return curvePoints[pos];
  }

  /// Sub-samples [points] down to roughly [target] anchors, preserving
  /// the first and last points so the curve still hits the endpoints.
  List<Offset> _subSample(List<Offset> points, int target) {
    if (points.length <= target) return points;
    final n = points.length;
    final result = <Offset>[];
    for (var i = 0; i < target; i++) {
      final idx = (i * (n - 1) / (target - 1)).round();
      result.add(points[idx]);
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (int i = 0; i <= 4; i++) {
      final x = w * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // Efficient frontier convention: x-axis risk, y-axis expected return.
    final labelStyle = TextStyle(
      color: textTertiaryColor,
      fontSize: 10,
    );

    _drawText(canvas, '연 기대수익률', const Offset(4, 4), labelStyle);

    final hasPreviewPoints = previewPoints != null && previewPoints!.isNotEmpty;
    if (hasPreviewPoints) {
      _paintPreviewFrontier(canvas, size, labelStyle);
      return;
    }

    // Build the smoothed idealized curve from a sparse set of anchor
    // points sampled from `_tToPoint`. The user explicitly wants visual
    // understanding, not data precision (2026-05-05 notes).
    if (curveProgress > 0) {
      const anchorCount = 9;
      final anchors = <Offset>[];
      for (int i = 0; i < anchorCount; i++) {
        final t = i / (anchorCount - 1);
        if (t > curveProgress) break;
        anchors.add(_tToPoint(t, w, h));
      }
      if (anchors.length >= 2) {
        _drawFrontierStroke(canvas, size, anchors);
        _drawAssetBubbles(canvas, anchors, dotProgress);
      }
    }

    // Selected (draggable) dot on the curve — pulse glow preserved.
    if (dotProgress > 0) {
      final dotPos = _tToPoint(dotT, w, h);
      _drawSelectedDot(canvas, dotPos);
    }
  }

  void _paintPreviewFrontier(Canvas canvas, Size size, TextStyle labelStyle) {
    final w = size.width;
    final h = size.height;
    final points = previewPoints!;

    // Use frontier-only range so the curve fills the canvas.
    final minVolatility = points.map((point) => point.volatility).reduce(min);
    final maxVolatility = points.map((point) => point.volatility).reduce(max);
    final minExpectedReturn =
        points.map((point) => point.expectedReturn).reduce(min);
    final maxExpectedReturn =
        points.map((point) => point.expectedReturn).reduce(max);
    final pointOffsets = [
      for (final point in points)
        _previewPointToOffset(
          point,
          w,
          h,
          minVolatility,
          maxVolatility,
          minExpectedReturn,
          maxExpectedReturn,
        ),
    ];
    final visibleCount = max(
      1,
      (pointOffsets.length * curveProgress).ceil(),
    );
    final visiblePoints = pointOffsets.take(visibleCount).toList();

    // Idealized curve — sub-sample down to ~9 anchors before smoothing.
    // The user explicitly chose visual understanding over precision
    // (2026-05-05 notes).
    if (visiblePoints.length >= 2) {
      final anchors = _subSample(visiblePoints, 9);
      _drawFrontierStroke(canvas, size, anchors);
      _drawAssetBubbles(canvas, anchors, dotProgress);
    }

    final selectedPosition = (() {
      if (selectedPreviewPosition != null &&
          selectedPreviewPosition! >= 0 &&
          selectedPreviewPosition! < points.length) {
        return selectedPreviewPosition!;
      }
      return points.length ~/ 2;
    })();
    final selectedPoint = pointOffsets[selectedPosition];
    _drawSelectedDot(canvas, selectedPoint);

    final labelPoint = points[selectedPosition];
    if (labelPoint.representativeLabel != null) {
      _drawText(
        canvas,
        labelPoint.representativeLabel!,
        Offset(selectedPoint.dx + 10, max(8, selectedPoint.dy - 22)),
        labelStyle.copyWith(
          color: WeRoboColors.primary,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  /// Stroke the smoothed idealized curve in primary brand color.
  void _drawFrontierStroke(Canvas canvas, Size size, List<Offset> anchors) {
    final curvePath = _buildFrontierPath(anchors, size);
    final curvePaint = Paint()
      ..color = WeRoboColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(curvePath, curvePaint);
  }

  /// Draws the seven asset-class bubbles at fixed normalized positions
  /// along the curve in `AssetClass` enum order — defensive (cash) on
  /// the left, aggressive (newGrowth) on the right. Fixed radius (no
  /// size growth animation) and no percentage labels per 2026-05-05
  /// user notes.
  void _drawAssetBubbles(
    Canvas canvas,
    List<Offset> curvePoints,
    double opacity,
  ) {
    if (opacity <= 0 || curvePoints.isEmpty) return;
    for (final cls in AssetClass.values) {
      final anchor = _assetAnchor(cls, curvePoints);
      final color = WeRoboColors.assetColor(cls);
      // Fixed radius — NO size-growth animation.
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(anchor, 7.0, fillPaint);
      // White ring for contrast against the curve stroke.
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = WeRoboColors.white.withValues(alpha: opacity)
        ..strokeWidth = 1.5;
      canvas.drawCircle(anchor, 7.0, ringPaint);
      // Asset name label only — no percentage. The bar widget below
      // the chart shows proportions.
      _drawLabel(canvas, anchor, cls.koLabel, opacity);
    }
  }

  /// Renders a Noto Sans KR caption above [anchor] at fixed offset.
  void _drawLabel(Canvas canvas, Offset anchor, String text, double opacity) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: WeRoboFonts.body,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: WeRoboColors.textPrimary.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final pos = Offset(anchor.dx - tp.width / 2, anchor.dy - 16 - tp.height);
    tp.paint(canvas, pos);
  }

  /// Selected (draggable) dot with pulse glow — preserved from previous
  /// behaviour. Asset bubbles are static; only this dot pulses.
  void _drawSelectedDot(Canvas canvas, Offset position) {
    if (dotProgress <= 0) return;
    final dotRadius = isDragging ? 12.0 : 8.0;
    final pulseGlow = sin(pulseValue * 2 * pi) * 3.0;
    final glowRadius = (isDragging ? 28.0 : 18.0) + pulseGlow;
    final glowAlpha =
        ((isDragging ? 0.3 : 0.2) + sin(pulseValue * 2 * pi) * 0.05) *
            dotProgress;

    final glowPaint = Paint()
      ..color = WeRoboColors.primary.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, glowRadius * dotProgress, glowPaint);

    final dotPaint = Paint()
      ..color = WeRoboColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, dotRadius * dotProgress, dotPaint);

    final ringPaint = Paint()
      ..color = WeRoboColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(position, dotRadius * dotProgress, ringPaint);
  }

  Offset _previewPointToOffset(
    MobileFrontierPreviewPoint point,
    double w,
    double h,
    double minVolatility,
    double maxVolatility,
    double minExpectedReturn,
    double maxExpectedReturn,
  ) {
    const leftPaddingRatio = 0.15;
    const rightPaddingRatio = 0.85;
    const topPaddingRatio = 0.12;
    const bottomPaddingRatio = 0.86;

    final normalizedVolatility = maxVolatility == minVolatility
        ? 0.5
        : (point.volatility - minVolatility) / (maxVolatility - minVolatility);
    final normalizedExpectedReturn = maxExpectedReturn == minExpectedReturn
        ? 0.5
        : (point.expectedReturn - minExpectedReturn) /
            (maxExpectedReturn - minExpectedReturn);

    final x = w * leftPaddingRatio +
        (w * (rightPaddingRatio - leftPaddingRatio)) * normalizedVolatility;
    final y = h * bottomPaddingRatio -
        (h * (bottomPaddingRatio - topPaddingRatio)) * normalizedExpectedReturn;
    return Offset(x, y);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _FrontierPainter old) {
    return old.curveProgress != curveProgress ||
        old.dotProgress != dotProgress ||
        old.dotT != dotT ||
        old.isDragging != isDragging ||
        old.pulseValue != pulseValue ||
        old.selectedPreviewPosition != selectedPreviewPosition ||
        old.previewPoints != previewPoints;
  }
}
