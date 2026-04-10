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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnimation;
  late Animation<double> _dotAnimation;

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
    final minVolatility =
        previewPoints.map((point) => point.volatility).reduce(min);
    final maxVolatility =
        previewPoints.map((point) => point.volatility).reduce(max);
    final minExpectedReturn =
        previewPoints.map((point) => point.expectedReturn).reduce(min);
    final maxExpectedReturn =
        previewPoints.map((point) => point.expectedReturn).reduce(max);

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
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 240.0;

            return GestureDetector(
              onLongPressStart: (details) {
                if (_controller.isCompleted) {
                  final dotPos = _hasPreviewPoints
                      ? _previewPointToOffset(
                          widget.previewPoints![
                              widget.selectedPreviewPosition ??
                                  widget.previewPoints!.length ~/ 2],
                          w,
                          h,
                          widget.previewPoints!
                              .map((point) => point.volatility)
                              .reduce(min),
                          widget.previewPoints!
                              .map((point) => point.volatility)
                              .reduce(max),
                          widget.previewPoints!
                              .map((point) => point.expectedReturn)
                              .reduce(min),
                          widget.previewPoints!
                              .map((point) => point.expectedReturn)
                              .reduce(max),
                        )
                      : _tToPoint(_dotT, w, h);
                  if ((details.localPosition - dotPos).distance < 60) {
                    setState(() => _isDragging = true);
                    widget.onDragStateChanged?.call(true);
                  }
                }
              },
              onLongPressMoveUpdate: (details) {
                if (_isDragging) {
                  if (_hasPreviewPoints) {
                    final previewPosition =
                        _nearestPreviewPosition(details.localPosition, w, h);
                    final nextDotT = widget.previewPoints!.length <= 1
                        ? 0.45
                        : previewPosition / (widget.previewPoints!.length - 1);
                    setState(() => _dotT = nextDotT);
                    widget.onPreviewPointChanged?.call(previewPosition);
                    widget.onPositionChanged?.call(nextDotT);
                  } else {
                    setState(() {
                      _dotT = _screenToT(details.localPosition, w, h);
                    });
                    widget.onPositionChanged?.call(_dotT);
                  }
                }
              },
              onLongPressEnd: (_) {
                setState(() => _isDragging = false);
                widget.onDragStateChanged?.call(false);
              },
              onLongPressCancel: () {
                setState(() => _isDragging = false);
                widget.onDragStateChanged?.call(false);
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
  final List<MobileFrontierPreviewPoint>? previewPoints;
  final int? selectedPreviewPosition;
  final Color gridColor;
  final Color textTertiaryColor;

  _FrontierPainter({
    required this.curveProgress,
    required this.dotProgress,
    required this.dotT,
    required this.isDragging,
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

    _drawText(canvas, '기대수익률', const Offset(4, 4), labelStyle);
    _drawText(canvas, '위험도', Offset(w - 32, h - 16), labelStyle);

    final hasPreviewPoints = previewPoints != null && previewPoints!.isNotEmpty;
    if (hasPreviewPoints) {
      _paintPreviewFrontier(canvas, size, labelStyle);
      return;
    }

    // Efficient frontier curve
    if (curveProgress > 0) {
      final curvePath = Path();
      final points = <Offset>[];

      for (int i = 0; i <= 50; i++) {
        final t = i / 50.0;
        if (t > curveProgress) break;
        points.add(_tToPoint(t, w, h));
      }

      if (points.isNotEmpty) {
        curvePath.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          if (i < points.length - 1) {
            final cp = Offset(
              (points[i].dx + points[i + 1].dx) / 2,
              (points[i].dy + points[i + 1].dy) / 2,
            );
            curvePath.quadraticBezierTo(
              points[i].dx,
              points[i].dy,
              cp.dx,
              cp.dy,
            );
          } else {
            curvePath.lineTo(points[i].dx, points[i].dy);
          }
        }

        final curvePaint = Paint()
          ..color = WeRoboColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(curvePath, curvePaint);
      }
    }

    // Scatter dots (other portfolios)
    if (dotProgress > 0) {
      final rng = Random(42);
      final scatterPaint = Paint()..style = PaintingStyle.fill;

      for (int i = 0; i < 15; i++) {
        final x = w * 0.2 + rng.nextDouble() * w * 0.6;
        final y = h * 0.2 + rng.nextDouble() * h * 0.6;
        scatterPaint.color =
            textTertiaryColor.withValues(alpha: 0.3 * dotProgress);
        canvas.drawCircle(Offset(x, y), 3 * dotProgress, scatterPaint);
      }

      // Draggable dot on the curve
      final dotPos = _tToPoint(dotT, w, h);
      final dotRadius = isDragging ? 14.0 : 10.0;
      final glowRadius = isDragging ? 32.0 : 22.0;

      // Glow
      final glowPaint = Paint()
        ..color = WeRoboColors.primary
            .withValues(alpha: (isDragging ? 0.3 : 0.2) * dotProgress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotPos, glowRadius * dotProgress, glowPaint);

      // Dot fill
      final dotPaint = Paint()
        ..color = WeRoboColors.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotPos, dotRadius * dotProgress, dotPaint);

      // White ring
      final ringPaint = Paint()
        ..color = WeRoboColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(dotPos, dotRadius * dotProgress, ringPaint);
    }
  }

  void _paintPreviewFrontier(Canvas canvas, Size size, TextStyle labelStyle) {
    final w = size.width;
    final h = size.height;
    final points = previewPoints!;
    final minVolatility = points.map((point) => point.volatility).reduce(min);
    final maxVolatility = points.map((point) => point.volatility).reduce(max);
    final minExpectedReturn =
        points.map((point) => point.expectedReturn).reduce(min);
    final maxExpectedReturn =
        points.map((point) => point.expectedReturn).reduce(max);
    final curvePath = Path();
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

    if (visiblePoints.isNotEmpty) {
      curvePath.moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
      for (int i = 1; i < visiblePoints.length; i++) {
        curvePath.lineTo(visiblePoints[i].dx, visiblePoints[i].dy);
      }
      final curvePaint = Paint()
        ..color = WeRoboColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(curvePath, curvePaint);
    }

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = textTertiaryColor.withValues(alpha: 0.24 * dotProgress);
    final representativePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = WeRoboColors.primary.withValues(alpha: 0.55 * dotProgress);

    for (int i = 0; i < visiblePoints.length; i++) {
      final previewPoint = points[i];
      final radius = previewPoint.representativeCode == null
          ? 2.5 * dotProgress
          : 4 * dotProgress;
      canvas.drawCircle(
        visiblePoints[i],
        radius,
        previewPoint.representativeCode == null
            ? pointPaint
            : representativePaint,
      );
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
    final dotRadius = isDragging ? 14.0 : 10.0;
    final glowRadius = isDragging ? 32.0 : 22.0;

    final glowPaint = Paint()
      ..color = WeRoboColors.primary
          .withValues(alpha: (isDragging ? 0.3 : 0.2) * dotProgress)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(selectedPoint, glowRadius * dotProgress, glowPaint);

    final dotPaint = Paint()
      ..color = WeRoboColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(selectedPoint, dotRadius * dotProgress, dotPaint);

    final ringPaint = Paint()
      ..color = WeRoboColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(selectedPoint, dotRadius * dotProgress, ringPaint);

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
  bool shouldRepaint(covariant _FrontierPainter oldDelegate) {
    return oldDelegate.curveProgress != curveProgress ||
        oldDelegate.dotProgress != dotProgress ||
        oldDelegate.dotT != dotT ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.selectedPreviewPosition != selectedPreviewPosition ||
        oldDelegate.previewPoints != previewPoints;
  }
}
