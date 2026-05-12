import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

String frontierAssetBubbleLabel(AssetClass cls) => cls.koLabel;

// Locked stair-step layout from capstone 2026-05-12 reference image:
// dots sit below the frontier curve in a fan, cash at bottom-left and
// newGrowth at top-right. Each x is held high enough that the label
// (positioned to the dot's left) still fits inside the chart.
const Map<AssetClass, Offset> _kAssetBubbleSlots = {
  AssetClass.cash: Offset(0.06, 0.94),
  AssetClass.shortBond: Offset(0.18, 0.84),
  AssetClass.gold: Offset(0.31, 0.74),
  AssetClass.infraBond: Offset(0.44, 0.645),
  AssetClass.usValue: Offset(0.57, 0.52),
  AssetClass.usGrowth: Offset(0.77, 0.42),
  AssetClass.newGrowth: Offset(0.91, 0.22),
};

// Exceptions: assets whose label sits to the LEFT of the dot. Everyone
// else defaults to right-side labels.
const Set<AssetClass> _kLeftLabelAssets = {AssetClass.newGrowth};

// Backend asset code → AssetClass enum, used to read the selected
// portfolio's weight per class for dot-size scaling.
const Map<String, AssetClass> _kAssetClassByCode = {
  'cash_equivalents': AssetClass.cash,
  'short_term_bond': AssetClass.shortBond,
  'infra_bond': AssetClass.infraBond,
  'gold': AssetClass.gold,
  'us_value': AssetClass.usValue,
  'us_growth': AssetClass.usGrowth,
  'new_growth': AssetClass.newGrowth,
};

// Locked dot size: 7.7px (110% of the 7.0px base) at weight ≥ 0.30,
// scaling down linearly to 65% of the base (4.55px) at weight 0.
// Positions stay locked; only the radius reflects the selected
// portfolio's allocation.
double _radiusForWeight(double weight) {
  const minRadius = 4.55;
  const maxRadius = 7.7;
  final t = (weight / 0.30).clamp(0.0, 1.0);
  return minRadius + (maxRadius - minRadius) * t;
}

const double _kFrontierCurveStartX = 0.10;
const double _kFrontierCurveEndX = 0.94;
const double _kFrontierBubbleLabelFontSize = 10.5;
const double _kFrontierBubbleLabelMargin = 4.0;
const double _kFrontierBubbleLabelGap = 2.0;

Offset frontierCurvePointForT(double t, Size size) {
  final clampedT = t.clamp(0.0, 1.0).toDouble();
  final x = size.width *
      (_kFrontierCurveStartX +
          (_kFrontierCurveEndX - _kFrontierCurveStartX) * clampedT);
  final normalizedY = 0.85 - 0.7 * sqrt(clampedT) + 0.15 * clampedT;
  final y = size.height * normalizedY;
  return Offset(x, y);
}

double _frontierTForX(double x, double width) {
  final t = (x / width - _kFrontierCurveStartX) /
      (_kFrontierCurveEndX - _kFrontierCurveStartX);
  return t.clamp(0.0, 1.0);
}

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

class FrontierAssetBubbleLabelLayout {
  final AssetClass cls;
  final Offset anchor;
  final Rect rect;
  final bool labelOnLeft;

  const FrontierAssetBubbleLabelLayout({
    required this.cls,
    required this.anchor,
    required this.rect,
    required this.labelOnLeft,
  });

  FrontierAssetBubbleLabelLayout copyWith({Rect? rect}) {
    return FrontierAssetBubbleLabelLayout(
      cls: cls,
      anchor: anchor,
      rect: rect ?? this.rect,
      labelOnLeft: labelOnLeft,
    );
  }
}

List<FrontierAssetBubbleSpec> frontierAssetBubbleSpecs({
  required MobileFrontierPreviewPoint? point,
  required Size size,
  required int selectedPosition,
  required int previewPointCount,
}) {
  // Position is locked per _kAssetBubbleSlots; the only thing that
  // varies with the selected portfolio is each dot's radius. Opacity
  // stays at the locked max via the constant `weight: 0.30` below.
  final weights = <AssetClass, double>{};
  if (point != null) {
    for (final alloc in point.sectorAllocations) {
      final cls = _kAssetClassByCode[alloc.assetCode];
      if (cls == null) continue;
      weights[cls] = (weights[cls] ?? 0) + alloc.weight;
    }
  }
  // Before any preview data lands, render every dot at max size so the
  // chart doesn't shrink-and-grow on first paint.
  final fallbackWeight = point == null ? 0.30 : 0.0;
  final specs = <FrontierAssetBubbleSpec>[];
  for (final cls in AssetClass.values) {
    final slot = _kAssetBubbleSlots[cls]!;
    final weight = weights[cls] ?? fallbackWeight;
    specs.add(
      FrontierAssetBubbleSpec(
        cls: cls,
        weight: 0.30,
        anchor: Offset(size.width * slot.dx, size.height * slot.dy),
        radius: _radiusForWeight(weight),
      ),
    );
  }
  return specs;
}

List<FrontierAssetBubbleLabelLayout> frontierAssetBubbleLabelLayouts({
  required List<FrontierAssetBubbleSpec> bubbleSpecs,
  required Size size,
}) {
  final rawLayouts = <FrontierAssetBubbleLabelLayout>[];
  for (final spec in bubbleSpecs) {
    final text = frontierAssetBubbleLabel(spec.cls);
    final labelSize = _frontierBubbleLabelSize(text);
    // Labels sit to the right of every dot, with per-asset overrides in
    // _kLeftLabelAssets for dots crowded against the right edge.
    final labelOnLeft = _kLeftLabelAssets.contains(spec.cls);
    final rawDx = labelOnLeft
        ? spec.anchor.dx - spec.radius - labelSize.width - 6
        : spec.anchor.dx + spec.radius + 6;
    final rawDy = spec.anchor.dy - labelSize.height / 2;
    final dx = rawDx.clamp(
      _kFrontierBubbleLabelMargin,
      max(
        _kFrontierBubbleLabelMargin,
        size.width - labelSize.width - _kFrontierBubbleLabelMargin,
      ),
    );
    final dy = rawDy.clamp(
      _kFrontierBubbleLabelMargin,
      max(
        _kFrontierBubbleLabelMargin,
        size.height - labelSize.height - _kFrontierBubbleLabelMargin,
      ),
    );
    rawLayouts.add(
      FrontierAssetBubbleLabelLayout(
        cls: spec.cls,
        anchor: spec.anchor,
        rect: Offset(dx.toDouble(), dy.toDouble()) & labelSize,
        labelOnLeft: labelOnLeft,
      ),
    );
  }

  final layouts = [...rawLayouts]
    ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
  final adjusted = <FrontierAssetBubbleLabelLayout>[];
  var nextTop = _kFrontierBubbleLabelMargin;
  for (final layout in layouts) {
    final maxTop = max(
      _kFrontierBubbleLabelMargin,
      size.height - layout.rect.height - _kFrontierBubbleLabelMargin,
    );
    final top = max(layout.rect.top, nextTop)
        .clamp(_kFrontierBubbleLabelMargin, maxTop)
        .toDouble();
    final rect = Rect.fromLTWH(
      layout.rect.left,
      top,
      layout.rect.width,
      layout.rect.height,
    );
    adjusted.add(layout.copyWith(rect: rect));
    nextTop = rect.bottom + _kFrontierBubbleLabelGap;
  }

  if (adjusted.isEmpty) return adjusted;
  final overflow =
      adjusted.last.rect.bottom - (size.height - _kFrontierBubbleLabelMargin);
  if (overflow <= 0) return adjusted;
  return adjusted
      .map(
        (layout) => layout.copyWith(
          rect: layout.rect.shift(Offset(0, -overflow)),
        ),
      )
      .toList();
}

Size _frontierBubbleLabelSize(String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: WeRoboFonts.body,
        fontSize: _kFrontierBubbleLabelFontSize,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  return tp.size;
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
    return frontierCurvePointForT(t, Size(w, h));
  }

  /// Map screen x position directly to t for smooth dragging
  double _screenToT(Offset localPos, double w, double h) {
    return _frontierTForX(localPos.dx, w);
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
                  textPrimaryColor: tc.textPrimary,
                  textTertiaryColor: tc.textTertiary,
                  labelBackgroundColor: tc.background,
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
  final Color textPrimaryColor;
  final Color textTertiaryColor;
  final Color labelBackgroundColor;

  _FrontierPainter({
    required this.curveProgress,
    required this.dotProgress,
    required this.dotT,
    required this.isDragging,
    required this.pulseValue,
    required this.previewPoints,
    required this.selectedPreviewPosition,
    required this.gridColor,
    required this.textPrimaryColor,
    required this.textTertiaryColor,
    required this.labelBackgroundColor,
  });

  Offset _tToPoint(double t, double w, double h) {
    return frontierCurvePointForT(t, Size(w, h));
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

    // Keep the selected dot on the smooth frontier curve, while the
    // allocation bubbles live in stable risk/return slots around it.
    if (curveProgress > 0) {
      _drawSmoothFrontier(canvas, size, curveProgress);
    }
    if (dotProgress > 0) {
      _drawAssetBubbles(canvas, size, dotProgress);
      final tSelected = _selectedDotT();
      final dotPos = _tToPoint(tSelected, w, h);
      _drawSelectedDot(canvas, dotPos);
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
  List<FrontierAssetBubbleLabelLayout> _drawAssetBubbles(
    Canvas canvas,
    Size size,
    double opacity,
  ) {
    if (opacity <= 0) return const [];
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
    }
    final layouts = frontierAssetBubbleLabelLayouts(
      bubbleSpecs: specs,
      size: size,
    );
    for (final layout in layouts) {
      _drawBubbleLabel(canvas, layout, opacity);
    }
    return layouts;
  }

  void _drawBubbleLabel(
    Canvas canvas,
    FrontierAssetBubbleLabelLayout layout,
    double opacity,
  ) {
    final labelEdge = Offset(
      layout.labelOnLeft ? layout.rect.right : layout.rect.left,
      layout.rect.center.dy,
    );
    final leaderPaint = Paint()
      ..color = textTertiaryColor.withValues(alpha: 0.24 * opacity)
      ..strokeWidth = 0.8;
    canvas.drawLine(layout.anchor, labelEdge, leaderPaint);

    final text = frontierAssetBubbleLabel(layout.cls);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: WeRoboFonts.body,
          fontSize: _kFrontierBubbleLabelFontSize,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, layout.rect.topLeft);
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

  @override
  bool shouldRepaint(covariant _FrontierPainter old) {
    return old.curveProgress != curveProgress ||
        old.dotProgress != dotProgress ||
        old.dotT != dotT ||
        old.isDragging != isDragging ||
        old.pulseValue != pulseValue ||
        old.selectedPreviewPosition != selectedPreviewPosition ||
        old.previewPoints != previewPoints ||
        old.textPrimaryColor != textPrimaryColor ||
        old.textTertiaryColor != textTertiaryColor ||
        old.labelBackgroundColor != labelBackgroundColor;
  }
}
