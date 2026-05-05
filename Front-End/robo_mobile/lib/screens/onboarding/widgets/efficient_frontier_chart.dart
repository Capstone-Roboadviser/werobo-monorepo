import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

String frontierAssetBubbleLabel(AssetClass cls) => cls.koLabel;

const Map<String, AssetClass> _kAssetClassByCode = {
  'cash_equivalents': AssetClass.cash,
  'short_term_bond': AssetClass.shortBond,
  'infra_bond': AssetClass.infraBond,
  'gold': AssetClass.gold,
  'us_value': AssetClass.usValue,
  'us_growth': AssetClass.usGrowth,
  'new_growth': AssetClass.newGrowth,
};

const Map<AssetClass, Offset> _kAssetBubbleSlots = {
  AssetClass.cash: Offset(0.20, 0.78),
  AssetClass.shortBond: Offset(0.36, 0.72),
  AssetClass.infraBond: Offset(0.18, 0.34),
  AssetClass.gold: Offset(0.40, 0.24),
  AssetClass.usValue: Offset(0.60, 0.20),
  AssetClass.usGrowth: Offset(0.78, 0.36),
  AssetClass.newGrowth: Offset(0.82, 0.22),
};

const Map<int, Map<AssetClass, double>> _kFallbackWeightsAtPosition = {
  0: {
    AssetClass.shortBond: 0.30,
    AssetClass.cash: 0.30,
    AssetClass.gold: 0.22,
    AssetClass.usValue: 0.07,
    AssetClass.newGrowth: 0.05,
    AssetClass.infraBond: 0.03,
    AssetClass.usGrowth: 0.03,
  },
  20: {
    AssetClass.shortBond: 0.30,
    AssetClass.cash: 0.29,
    AssetClass.infraBond: 0.26,
    AssetClass.newGrowth: 0.05,
    AssetClass.usValue: 0.04,
    AssetClass.usGrowth: 0.03,
    AssetClass.gold: 0.03,
  },
  35: {
    AssetClass.shortBond: 0.30,
    AssetClass.usValue: 0.23,
    AssetClass.cash: 0.19,
    AssetClass.infraBond: 0.17,
    AssetClass.newGrowth: 0.05,
    AssetClass.gold: 0.03,
    AssetClass.usGrowth: 0.03,
  },
  45: {
    AssetClass.usValue: 0.30,
    AssetClass.shortBond: 0.30,
    AssetClass.infraBond: 0.16,
    AssetClass.cash: 0.13,
    AssetClass.newGrowth: 0.05,
    AssetClass.usGrowth: 0.03,
    AssetClass.gold: 0.03,
  },
  55: {
    AssetClass.shortBond: 0.30,
    AssetClass.usValue: 0.30,
    AssetClass.infraBond: 0.24,
    AssetClass.cash: 0.05,
    AssetClass.newGrowth: 0.05,
    AssetClass.gold: 0.03,
    AssetClass.usGrowth: 0.03,
  },
  60: {
    AssetClass.usValue: 0.30,
    AssetClass.infraBond: 0.30,
    AssetClass.shortBond: 0.21,
    AssetClass.usGrowth: 0.08,
    AssetClass.newGrowth: 0.05,
    AssetClass.cash: 0.03,
    AssetClass.gold: 0.03,
  },
};

class FrontierAssetBubbleSpec {
  final AssetClass cls;
  final double weight;
  final Offset anchor;
  final double radius;

  const FrontierAssetBubbleSpec({
    required this.cls,
    required this.weight,
    required this.anchor,
    required this.radius,
  });
}

List<FrontierAssetBubbleSpec> frontierAssetBubbleSpecs({
  required MobileFrontierPreviewPoint? point,
  required Size size,
  required int selectedPosition,
  required int previewPointCount,
}) {
  final weights = _weightsForFrontierPoint(
    point: point,
    selectedPosition: selectedPosition,
    previewPointCount: previewPointCount,
  );
  final specs = <FrontierAssetBubbleSpec>[];
  for (final cls in AssetClass.values) {
    final weight = weights[cls] ?? 0;
    if (weight <= 0.005) continue;
    final slot = _kAssetBubbleSlots[cls]!;
    specs.add(
      FrontierAssetBubbleSpec(
        cls: cls,
        weight: weight,
        anchor: Offset(size.width * slot.dx, size.height * slot.dy),
        radius: _bubbleRadiusForWeight(weight),
      ),
    );
  }
  return specs..sort((a, b) => a.radius.compareTo(b.radius));
}

Map<AssetClass, double> _weightsForFrontierPoint({
  required MobileFrontierPreviewPoint? point,
  required int selectedPosition,
  required int previewPointCount,
}) {
  if (point != null && point.sectorAllocations.isNotEmpty) {
    final weights = <AssetClass, double>{};
    for (final allocation in point.sectorAllocations) {
      final cls = _kAssetClassByCode[allocation.assetCode];
      if (cls == null || allocation.weight <= 0) continue;
      weights[cls] = (weights[cls] ?? 0) + allocation.weight;
    }
    return weights;
  }

  final maxPosition = max(0, previewPointCount - 1);
  final clampedPosition = selectedPosition.clamp(0, maxPosition).toDouble();
  final normalizedPosition =
      maxPosition <= 0 ? 0.0 : clampedPosition / maxPosition;
  return _interpolateFallbackWeights(normalizedPosition * 60);
}

Map<AssetClass, double> _interpolateFallbackWeights(double scaledPosition) {
  final keys = _kFallbackWeightsAtPosition.keys.toList()..sort();
  if (keys.isEmpty) return const {};
  if (scaledPosition <= keys.first) {
    return _kFallbackWeightsAtPosition[keys.first]!;
  }
  if (scaledPosition >= keys.last) {
    return _kFallbackWeightsAtPosition[keys.last]!;
  }

  int lower = keys.first;
  int upper = keys.last;
  for (final key in keys) {
    if (key <= scaledPosition) lower = key;
    if (key >= scaledPosition) {
      upper = key;
      break;
    }
  }
  if (lower == upper) return _kFallbackWeightsAtPosition[lower]!;

  final t = (scaledPosition - lower) / (upper - lower);
  final lowerWeights = _kFallbackWeightsAtPosition[lower]!;
  final upperWeights = _kFallbackWeightsAtPosition[upper]!;
  final allClasses = {...lowerWeights.keys, ...upperWeights.keys};
  return {
    for (final cls in allClasses)
      cls:
          (lowerWeights[cls] ?? 0.0) * (1 - t) + (upperWeights[cls] ?? 0.0) * t,
  };
}

double _bubbleRadiusForWeight(double weight) {
  final clamped = weight.clamp(0.0, 0.30).toDouble();
  return 4.5 + clamped * 20.0;
}

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

  /// Map a touch x position to the nearest preview index. Since both
  /// the curve and the dot live in t-space (`_tToPoint`), we just go
  /// touch_x → t (`_screenToT`) → nearest index. No need to compute
  /// per-point offsets in real (vol, return) space anymore.
  int _nearestPreviewPosition(Offset localPos, double w, double h) {
    final previewPoints = widget.previewPoints!;
    if (previewPoints.length <= 1) return 0;
    final t = _screenToT(localPos, w, h);
    return (t * (previewPoints.length - 1))
        .round()
        .clamp(0, previewPoints.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _pulseController]),
      builder: (context, _) {
        // Chart fills whatever its parent provides — wrap in Expanded
        // (or a SizedBox) at the call site to control its bounds.
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return GestureDetector(
              onPanStart: (details) {
                if (_controller.isCompleted) {
                  // Selected dot lives on the curve at t_selected.
                  // Same math as the painter's `_selectedDotT()`.
                  late final double tSelected;
                  if (_hasPreviewPoints) {
                    final pp = widget.previewPoints!;
                    final pos =
                        widget.selectedPreviewPosition ?? pp.length ~/ 2;
                    tSelected = pp.length <= 1
                        ? 0.5
                        : pos.clamp(0, pp.length - 1) / (pp.length - 1);
                  } else {
                    tSelected = _dotT;
                  }
                  final dotPos = _tToPoint(tSelected, w, h);
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
                        : previewPosition / (widget.previewPoints!.length - 1);
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

    // Keep the selected dot on the smooth frontier curve, while the
    // allocation bubbles live in stable risk/return slots around it.
    if (curveProgress > 0) {
      _drawSmoothFrontier(canvas, size, curveProgress);
    }
    if (dotProgress > 0) {
      _drawAssetBubbles(canvas, size, dotProgress);
    }
    if (dotProgress > 0) {
      final tSelected = _selectedDotT();
      final dotPos = _tToPoint(tSelected, w, h);
      _drawSelectedDot(canvas, dotPos);

      // Representative label (e.g. 안정형 / 균형형 / 성장형) for the
      // currently-selected preview point — only present at the marker
      // indices the backend tags.
      final pp = previewPoints;
      final pos = _selectedPosition();
      if (pp != null && pos >= 0 && pos < pp.length) {
        final label = pp[pos].representativeLabel;
        if (label != null) {
          _drawText(
            canvas,
            label,
            Offset(dotPos.dx + 10, max(8, dotPos.dy - 22)),
            labelStyle.copyWith(
              color: WeRoboColors.primary,
              fontWeight: FontWeight.w600,
            ),
          );
        }
      }
    }
  }

  /// Resolve the t value for the currently-selected dot. Preview drives
  /// it when present (t = index / (length - 1)); otherwise we fall back
  /// to the no-preview `dotT`.
  double _selectedDotT() {
    final pp = previewPoints;
    if (pp != null && pp.isNotEmpty) {
      if (pp.length <= 1) return 0.5;
      final clamped = _selectedPosition().clamp(0, pp.length - 1);
      return clamped / (pp.length - 1);
    }
    return dotT;
  }

  int _selectedPosition() {
    final pp = previewPoints;
    if (pp != null && pp.isNotEmpty) {
      final pos = selectedPreviewPosition ?? pp.length ~/ 2;
      return pos.clamp(0, pp.length - 1);
    }
    return (dotT.clamp(0.0, 1.0) * 60).round();
  }

  MobileFrontierPreviewPoint? _selectedPreviewPoint() {
    final pp = previewPoints;
    if (pp == null || pp.isEmpty) return null;
    return pp[_selectedPosition()];
  }

  /// Stroke the idealized frontier as a dense polyline sampled directly
  /// from the sqrt formula in `_tToPoint`. ~80 segments at this canvas
  /// size reads as a single smooth curve. Honors `curveProgress` so the
  /// initial reveal animation still works.
  void _drawSmoothFrontier(Canvas canvas, Size size, double progress) {
    const sampleCount = 80;
    final w = size.width;
    final h = size.height;
    final start = _tToPoint(0, w, h);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 1; i <= sampleCount; i++) {
      final t = i / sampleCount;
      if (t >= progress) {
        final end = _tToPoint(progress, w, h);
        path.lineTo(end.dx, end.dy);
        break;
      }
      final p = _tToPoint(t, w, h);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = WeRoboColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Draws allocation bubbles for the currently-selected frontier point.
  /// Radius is data-driven: as the selected point changes, the backend
  /// sector weights resize these circles.
  void _drawAssetBubbles(Canvas canvas, Size size, double opacity) {
    if (opacity <= 0) return;
    final pp = previewPoints;
    final specs = frontierAssetBubbleSpecs(
      point: _selectedPreviewPoint(),
      size: size,
      selectedPosition: _selectedPosition(),
      previewPointCount: pp?.length ?? 61,
    );

    for (final spec in specs) {
      final color = WeRoboColors.assetColor(spec.cls);
      final radius = (spec.radius + sin(pulseValue * 2 * pi) * 0.35) * opacity;
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(
          alpha: (0.58 + spec.weight.clamp(0.0, 0.30) * 1.1)
                  .clamp(0.58, 0.92)
                  .toDouble() *
              opacity,
        );
      canvas.drawCircle(spec.anchor, radius, fillPaint);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = WeRoboColors.white.withValues(alpha: opacity)
        ..strokeWidth = 1.5;
      canvas.drawCircle(spec.anchor, radius, ringPaint);
      _drawBubbleLabel(canvas, size, spec, opacity);
    }
  }

  void _drawBubbleLabel(
    Canvas canvas,
    Size size,
    FrontierAssetBubbleSpec spec,
    double opacity,
  ) {
    final text = frontierAssetBubbleLabel(spec.cls);
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
    final labelOnLeft = spec.anchor.dx > size.width * 0.72;
    final rawDx = labelOnLeft
        ? spec.anchor.dx - spec.radius - tp.width - 5
        : spec.anchor.dx + spec.radius + 5;
    final rawDy = spec.anchor.dy - tp.height / 2;
    final dx = rawDx.clamp(4.0, max(4.0, size.width - tp.width - 4.0));
    final dy = rawDy.clamp(4.0, max(4.0, size.height - tp.height - 4.0));
    tp.paint(canvas, Offset(dx.toDouble(), dy.toDouble()));
  }

  /// Selected (draggable) dot with pulse glow — preserved from previous
  /// behaviour. Asset bubbles resize from weights; this dot marks the
  /// currently selected frontier point.
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
