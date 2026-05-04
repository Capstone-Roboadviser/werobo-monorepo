import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';
import '../../../models/portfolio_data.dart';

/// Individual asset position on the risk-return plane.
class _AssetDot {
  final String code;
  final String name;
  final Color color;

  const _AssetDot({
    required this.code,
    required this.name,
    required this.color,
  });
}

class _WeightedAsset {
  final _AssetDot asset;
  final double weight;

  const _WeightedAsset({
    required this.asset,
    required this.weight,
  });
}

/// Asset metadata used to color and label the surrounding allocation dots.
const _kAssetDots = <_AssetDot>[
  _AssetDot(
    code: 'cash_equivalents',
    name: '현금성',
    color: CategoryColors.cash,
  ),
  _AssetDot(
    code: 'short_term_bond',
    name: '단기채권',
    color: CategoryColors.bond,
  ),
  _AssetDot(
    code: 'infra_bond',
    name: '인프라채권',
    color: CategoryColors.infra,
  ),
  _AssetDot(
    code: 'gold',
    name: '금',
    color: CategoryColors.gold,
  ),
  _AssetDot(
    code: 'new_growth',
    name: '신성장주',
    color: CategoryColors.newGrowth,
  ),
  _AssetDot(
    code: 'us_value',
    name: '미국가치주',
    color: CategoryColors.valueStock,
  ),
  _AssetDot(
    code: 'us_growth',
    name: '미국성장주',
    color: CategoryColors.growthStock,
  ),
];

const _kAssetSlotsByCode = <String, Offset>{
  'short_term_bond': Offset(0.47, 0.74), // below curve, center
  'cash_equivalents': Offset(0.67, 0.76), // below curve, right
  'infra_bond': Offset(0.08, 0.17), // top-left corner
  'gold': Offset(0.31, 0.11), // top, left-center
  'us_value': Offset(0.56, 0.08), // top, right-center
  'new_growth': Offset(0.78, 0.36), // right, mid
  'us_growth': Offset(0.78, 0.55), // right, lower
};

const _kUnknownAssetColor = Color(0xFF94A3B8);

final _kAssetDotByCode = {
  for (final asset in _kAssetDots) asset.code: asset,
};

/// Fallback weights used only for embedded/stale preview payloads that
/// do not yet carry per-point sector allocations.
const _kFallbackWeightsAtPosition = <int, Map<String, double>>{
  // conservative end (vol ≈ 0.057)
  0: {
    'short_term_bond': 0.30,
    'cash_equivalents': 0.30,
    'gold': 0.22,
    'us_value': 0.07,
    'new_growth': 0.05,
    'infra_bond': 0.03,
    'us_growth': 0.03,
  },
  // vol ≈ 0.08
  20: {
    'short_term_bond': 0.30,
    'cash_equivalents': 0.29,
    'infra_bond': 0.26,
    'new_growth': 0.05,
    'us_value': 0.04,
    'us_growth': 0.03,
    'gold': 0.03,
  },
  // vol ≈ 0.10
  35: {
    'short_term_bond': 0.30,
    'us_value': 0.23,
    'cash_equivalents': 0.19,
    'infra_bond': 0.17,
    'new_growth': 0.05,
    'gold': 0.03,
    'us_growth': 0.03,
  },
  // vol ≈ 0.12
  45: {
    'us_value': 0.30,
    'short_term_bond': 0.30,
    'infra_bond': 0.16,
    'cash_equivalents': 0.13,
    'new_growth': 0.05,
    'us_growth': 0.03,
    'gold': 0.03,
  },
  // vol ≈ 0.15
  55: {
    'short_term_bond': 0.30,
    'us_value': 0.30,
    'infra_bond': 0.24,
    'cash_equivalents': 0.05,
    'new_growth': 0.05,
    'gold': 0.03,
    'us_growth': 0.03,
  },
  // growth end (vol ≈ 0.19)
  60: {
    'us_value': 0.30,
    'infra_bond': 0.30,
    'short_term_bond': 0.21,
    'us_growth': 0.08,
    'new_growth': 0.05,
    'cash_equivalents': 0.03,
    'gold': 0.03,
  },
};

Map<String, double> _interpolateFallbackWeights(double scaledPosition) {
  final keys = _kFallbackWeightsAtPosition.keys.toList()..sort();
  if (keys.isEmpty) return {};
  if (scaledPosition <= keys.first) {
    return _kFallbackWeightsAtPosition[keys.first]!;
  }
  if (scaledPosition >= keys.last) {
    return _kFallbackWeightsAtPosition[keys.last]!;
  }

  int lower = keys.first;
  int upper = keys.last;
  for (final k in keys) {
    if (k <= scaledPosition) lower = k;
    if (k >= scaledPosition) {
      upper = k;
      break;
    }
  }
  if (lower == upper) return _kFallbackWeightsAtPosition[lower]!;

  final t = (scaledPosition - lower) / (upper - lower);
  final lowerW = _kFallbackWeightsAtPosition[lower]!;
  final upperW = _kFallbackWeightsAtPosition[upper]!;
  final allCodes = {...lowerW.keys, ...upperW.keys};
  return {
    for (final code in allCodes)
      code: (lowerW[code] ?? 0.0) * (1 - t) + (upperW[code] ?? 0.0) * t,
  };
}

_AssetDot _assetDotForAllocation(MobileSectorAllocation allocation) {
  final known = _kAssetDotByCode[allocation.assetCode];
  if (known != null) {
    return _AssetDot(
      code: known.code,
      name: allocation.assetName.isEmpty ? known.name : allocation.assetName,
      color: known.color,
    );
  }
  return _AssetDot(
    code: allocation.assetCode,
    name: allocation.assetName.isEmpty
        ? allocation.assetCode
        : allocation.assetName,
    color: _kUnknownAssetColor,
  );
}

List<_WeightedAsset> _weightedAssetsForPreviewPoint({
  required MobileFrontierPreviewPoint point,
  required int selectedPosition,
  required int previewPointCount,
}) {
  if (point.sectorAllocations.isNotEmpty) {
    return [
      for (final allocation in point.sectorAllocations)
        if (allocation.weight > 0)
          _WeightedAsset(
            asset: _assetDotForAllocation(allocation),
            weight: allocation.weight,
          ),
    ];
  }

  final normalizedPosition =
      previewPointCount <= 1 ? 0.0 : selectedPosition / (previewPointCount - 1);
  final fallbackWeights = _interpolateFallbackWeights(normalizedPosition * 60);
  return [
    for (final asset in _kAssetDots)
      if ((fallbackWeights[asset.code] ?? 0) > 0)
        _WeightedAsset(
          asset: asset,
          weight: fallbackWeights[asset.code] ?? 0.0,
        ),
  ];
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

  static const _zoneColors = [
    Color(0xFF059669), // safe (green)
    Color(0xFFFBBF24), // moderate (yellow)
    Color(0xFFF97316), // growth (orange)
  ];

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

  int _activeZone(double t) {
    if (t < 1 / 3) return 0;
    if (t < 2 / 3) return 1;
    return 2;
  }

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

    final hasPreviewPoints = previewPoints != null && previewPoints!.isNotEmpty;
    if (hasPreviewPoints) {
      _paintPreviewFrontier(canvas, size, labelStyle);
      return;
    }

    // Efficient frontier curve with zone coloring
    if (curveProgress > 0) {
      final allPoints = <Offset>[];
      for (int i = 0; i <= 50; i++) {
        final t = i / 50.0;
        if (t > curveProgress) break;
        allPoints.add(_tToPoint(t, w, h));
      }

      if (allPoints.isNotEmpty) {
        final activeZone = _activeZone(dotT);
        _drawZonedCurve(canvas, allPoints, 50, activeZone);
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
      final dotRadius = isDragging ? 12.0 : 8.0;
      final pulseGlow = sin(pulseValue * 2 * pi) * 3.0;
      final glowRadius = (isDragging ? 28.0 : 18.0) + pulseGlow;
      final glowAlpha =
          ((isDragging ? 0.3 : 0.2) + sin(pulseValue * 2 * pi) * 0.05) *
              dotProgress;

      // Glow
      final glowPaint = Paint()
        ..color = WeRoboColors.primary.withValues(alpha: glowAlpha)
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

    if (visiblePoints.length >= 2) {
      final activeZone = _activeZone(dotT);
      _drawZonedCurve(
        canvas,
        visiblePoints,
        points.length - 1,
        activeZone,
      );
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
    final dotRadius = isDragging ? 12.0 : 8.0;
    final pulseGlow = sin(pulseValue * 2 * pi) * 3.0;
    final glowRadius = (isDragging ? 28.0 : 18.0) + pulseGlow;
    final glowAlpha =
        ((isDragging ? 0.3 : 0.2) + sin(pulseValue * 2 * pi) * 0.05) *
            dotProgress;

    final glowPaint = Paint()
      ..color = WeRoboColors.primary.withValues(alpha: glowAlpha)
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

    // Asset dots — positioned at fixed layout slots around the frontier.
    // Keep low-weight assets visible so the frontier does not look incomplete.
    if (dotProgress > 0) {
      final visibleAssets = _weightedAssetsForPreviewPoint(
        point: labelPoint,
        selectedPosition: selectedPosition,
        previewPointCount: points.length,
      )
        ..removeWhere((asset) => asset.weight <= 0.005)
        ..sort((a, b) => a.weight.compareTo(b.weight));

      for (final weightedAsset in visibleAssets) {
        final asset = weightedAsset.asset;
        final weight = weightedAsset.weight;
        final slot = _kAssetSlotsByCode[asset.code];
        if (slot == null) continue;

        final pos = Offset(w * slot.dx, h * slot.dy);
        // Scale: small but visible at 3% → prominent at 30%+.
        final baseRadius = 4 + weight.clamp(0.0, 0.30) * 18;
        final radius =
            (baseRadius + sin(pulseValue * 2 * pi) * 0.5) * dotProgress;
        final alpha =
            (0.62 + weight.clamp(0.0, 0.30) * 1.1).clamp(0.62, 0.95).toDouble();
        final assetPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = asset.color.withValues(alpha: alpha * dotProgress);
        canvas.drawCircle(pos, radius, assetPaint);
        // Border ring
        final assetRingPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = asset.color.withValues(alpha: 1.0 * dotProgress)
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, radius, assetRingPaint);

        // Asset name
        _drawBoundedText(
          canvas,
          size,
          asset.name,
          Offset(pos.dx + radius + 4, pos.dy - 6),
          labelStyle.copyWith(
            color: asset.color.withValues(alpha: dotProgress),
            fontWeight: FontWeight.w600,
            fontSize: 9,
          ),
        );
        // Weight percentage
        final pctText = '${(weight * 100).toStringAsFixed(0)}%';
        _drawBoundedText(
          canvas,
          size,
          pctText,
          Offset(pos.dx + radius + 4, pos.dy + 5),
          labelStyle.copyWith(
            color: asset.color.withValues(alpha: 0.75 * dotProgress),
            fontWeight: FontWeight.w400,
            fontSize: 9,
          ),
        );
      }
      _drawAllocationLegend(
        canvas,
        size,
        visibleAssets,
        labelStyle,
        dotProgress,
      );
    }
  }

  void _drawAllocationLegend(
    Canvas canvas,
    Size size,
    List<_WeightedAsset> assets,
    TextStyle labelStyle,
    double opacity,
  ) {
    if (assets.isEmpty || opacity <= 0) return;
    final sorted = [...assets]..sort((a, b) => b.weight.compareTo(a.weight));

    const margin = 8.0;
    const gap = 4.0;
    const rowHeight = 17.0;
    const rows = 2;
    final chipWidth = (size.width - margin * 2 - gap * 3) / 4;
    final legendHeight = rowHeight * rows + gap;
    final startY = size.height - legendHeight - margin;

    for (var i = 0; i < sorted.length; i++) {
      final row = i ~/ 4;
      if (row >= rows) break;
      final itemsInRow = row == 0 ? min(4, sorted.length) : sorted.length - 4;
      final rowCount = min(4, max(0, itemsInRow));
      if (rowCount == 0) continue;
      final rowWidth = chipWidth * rowCount + gap * (rowCount - 1);
      final startX = (size.width - rowWidth) / 2;
      final col = i % 4;
      final asset = sorted[i];
      final rect = Rect.fromLTWH(
        startX + col * (chipWidth + gap),
        startY + row * (rowHeight + gap),
        chipWidth,
        rowHeight,
      );

      final bgPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = WeRoboColors.black.withValues(alpha: 0.45 * opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        bgPaint,
      );

      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = asset.asset.color.withValues(alpha: 0.95 * opacity);
      canvas.drawCircle(
        Offset(rect.left + 8, rect.center.dy),
        3.2,
        dotPaint,
      );

      final text = '${asset.asset.name} ${(asset.weight * 100).round()}%';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            color: asset.asset.color.withValues(alpha: opacity),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: chipWidth - 16);
      tp.paint(
        canvas,
        Offset(rect.left + 14, rect.top + (rowHeight - tp.height) / 2),
      );
    }
  }

  /// Draw the frontier curve split into 3 zones with coloring.
  void _drawZonedCurve(
    Canvas canvas,
    List<Offset> pts,
    int totalCount,
    int activeZone,
  ) {
    if (pts.length < 2) return;
    final n = pts.length;

    for (int zone = 0; zone < 3; zone++) {
      final zoneStart = zone / 3.0;
      final zoneEnd = (zone + 1) / 3.0;

      // Collect points in this zone (with overlap for
      // continuity at boundaries).
      final segPts = <Offset>[];
      for (int i = 0; i < n; i++) {
        final t = totalCount <= 0 ? 0.5 : i / totalCount.toDouble();
        if (t >= zoneStart - 0.02 && t <= zoneEnd + 0.02) {
          segPts.add(pts[i]);
        }
      }
      if (segPts.length < 2) continue;

      // Smooth the rendered curve while preserving the underlying preview
      // points for hit-testing and selection.
      final segPath = _buildSmoothPath(segPts);

      final isActive = zone == activeZone;
      final segColor = isActive ? _zoneColors[zone] : WeRoboColors.primary;

      if (isActive) {
        // Faint glow under active zone
        final glowPaint = Paint()
          ..color = segColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(segPath, glowPaint);
      }

      final segPaint = Paint()
        ..color = segColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Gradient blend at zone boundaries
      if (isActive && segPts.length >= 2) {
        // Blend start boundary
        if (zone > 0) {
          final gradStart = segPts.first;
          final gradEnd = segPts.length > 2 ? segPts[1] : segPts.last;
          segPaint.shader = _blendShader(
            WeRoboColors.primary,
            segColor,
            gradStart,
            gradEnd,
            segPts.first,
            segPts.last,
          );
        }
        // For single-segment approach, apply full gradient
        // across the path from blue edges to colored center.
        if (segPts.length >= 4) {
          segPaint.shader = _zoneGradientShader(
            segColor,
            segPts.first,
            segPts.last,
            zone > 0,
            zone < 2,
          );
        }
      }

      canvas.drawPath(segPath, segPaint);
    }
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;

      final rawControl1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final rawControl2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      final control1 = _clampOffsetToSegment(rawControl1, p1, p2);
      final control2 = _clampOffsetToSegment(rawControl2, p1, p2);

      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        p2.dx,
        p2.dy,
      );
    }

    return path;
  }

  Offset _clampOffsetToSegment(Offset value, Offset start, Offset end) {
    final minX = min(start.dx, end.dx);
    final maxX = max(start.dx, end.dx);
    final minY = min(start.dy, end.dy);
    final maxY = max(start.dy, end.dy);
    return Offset(
      value.dx.clamp(minX, maxX).toDouble(),
      value.dy.clamp(minY, maxY).toDouble(),
    );
  }

  /// Create a gradient shader that blends from blue
  /// at the edges to the zone color in the center.
  Shader _zoneGradientShader(
    Color zoneColor,
    Offset start,
    Offset end,
    bool blendStart,
    bool blendEnd,
  ) {
    final colors = <Color>[
      if (blendStart) WeRoboColors.primary,
      zoneColor,
      zoneColor,
      if (blendEnd) WeRoboColors.primary,
    ];
    final stops = <double>[
      if (blendStart) 0.0,
      blendStart ? 0.15 : 0.0,
      blendEnd ? 0.85 : 1.0,
      if (blendEnd) 1.0,
    ];
    return LinearGradient(
      colors: colors,
      stops: stops,
    ).createShader(Rect.fromPoints(start, end));
  }

  Shader _blendShader(
    Color from,
    Color to,
    Offset gradStart,
    Offset gradEnd,
    Offset pathStart,
    Offset pathEnd,
  ) {
    return LinearGradient(
      colors: [from, to, to, from],
      stops: const [0.0, 0.15, 0.85, 1.0],
    ).createShader(Rect.fromPoints(pathStart, pathEnd));
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

  void _drawBoundedText(
    Canvas canvas,
    Size size,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final dx = offset.dx.clamp(4.0, max(4.0, size.width - tp.width - 4.0));
    final dy = offset.dy.clamp(4.0, max(4.0, size.height - tp.height - 4.0));
    tp.paint(canvas, Offset(dx.toDouble(), dy.toDouble()));
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
