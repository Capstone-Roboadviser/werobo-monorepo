import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

/// Chart-internal short labels — full koLabel collides on iPhones <430pt.
const Map<AssetClass, String> _kAssetShortLabels = {
  AssetClass.cash: '현금성',
  AssetClass.shortBond: '단기채',
  AssetClass.infraBond: '인프라',
  AssetClass.gold: '금',
  AssetClass.usValue: '미국가',
  AssetClass.usGrowth: '미국성',
  AssetClass.newGrowth: '신성장',
};

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

  /// Fixed t position along the idealized frontier for each asset
  /// class, ordered defensive → aggressive. Each asset gets a unique
  /// slot so bubbles don't overlap each other, and the values are
  /// spaced wider than label width to keep the labels readable.
  ///
  /// We don't have backend per-asset stats, and the user has accepted
  /// approximate placement — this trades scientific accuracy for
  /// visual cleanliness, matching the textbook efficient-frontier
  /// presentation the user referenced (smooth curve + clean labels).
  static const Map<AssetClass, double> _assetT = {
    AssetClass.cash: 0.00,
    AssetClass.shortBond: 0.18,
    AssetClass.infraBond: 0.35,
    AssetClass.gold: 0.50,
    AssetClass.usValue: 0.65,
    AssetClass.usGrowth: 0.85,
    AssetClass.newGrowth: 1.00,
  };

  /// Vertical offset (px, screen down) of an asset bubble below the
  /// curve at its t. Keeps the bubble visually distinct from the
  /// frontier line without losing the "this asset sits at this risk
  /// tier" association.
  static const double _assetBubbleOffsetY = 18.0;

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

    // Single drawing path for both with-preview and no-preview cases.
    // The curve, dot, and bubbles are all parameterized by t ∈ [0, 1]
    // along the idealized sqrt-shaped frontier (`_tToPoint`). Using one
    // smooth function (sampled densely) avoids the kinks the previous
    // anchor-based cubic-Bezier produced (horizontal tangents at every
    // anchor → discontinuous slope at junctions). It also means asset
    // bubbles get unique t slots and never pile up at corners the way
    // the previous data-bounding-box mapping did.
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
      final pos = selectedPreviewPosition;
      if (pp != null && pos != null && pos >= 0 && pos < pp.length) {
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
    final pos = selectedPreviewPosition;
    if (pp != null && pp.isNotEmpty && pos != null) {
      if (pp.length <= 1) return 0.5;
      final clamped = pos.clamp(0, pp.length - 1);
      return clamped / (pp.length - 1);
    }
    return dotT;
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

  /// Draws the seven asset-class bubbles at their REAL (vol, return)
  /// coordinates relative to the frontier (mapped onto the same screen
  /// padding ratios used for the curve). Numbers come from
  /// [_assetApproxCoords] — a hardcoded approximate table — until the
  /// backend exposes per-asset stats in
  /// `MobileFrontierPreviewResponse`. 신성장주 is intentionally
  /// Draws the seven asset-class bubbles slightly below the curve at
  /// each asset's fixed t (`_assetT`). Each asset has a unique slot so
  /// bubbles don't pile up or overlap each other. The vertical offset
  /// keeps the bubbles visually distinct from the frontier line itself
  /// while preserving the "this asset sits at this risk tier" reading.
  /// Reveal-aware: only assets whose t has been reached by the curve
  /// animation are drawn.
  void _drawAssetBubbles(Canvas canvas, Size size, double opacity) {
    if (opacity <= 0) return;
    final w = size.width;
    final h = size.height;
    for (final cls in AssetClass.values) {
      final t = _assetT[cls]!;
      if (t > curveProgress) continue;
      final base = _tToPoint(t, w, h);
      final anchor = Offset(base.dx, base.dy + _assetBubbleOffsetY);
      final color = WeRoboColors.assetColor(cls);
      // Fixed radius — NO size-growth animation.
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(anchor, 7.0, fillPaint);
      // White ring for contrast against the warm-gray background.
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = WeRoboColors.white.withValues(alpha: opacity)
        ..strokeWidth = 1.5;
      canvas.drawCircle(anchor, 7.0, ringPaint);
      // Label below the bubble (away from the curve), so it never
      // collides with the curve stroke.
      _drawLabel(
        canvas,
        anchor,
        _kAssetShortLabels[cls]!,
        opacity,
        below: true,
      );
    }
  }

  /// Renders a Noto Sans KR caption near [anchor]. By default the
  /// caption sits above the anchor; set [below] to drop it underneath
  /// (used by asset bubbles, which sit below the curve and would
  /// otherwise get a label that crosses the frontier stroke).
  void _drawLabel(
    Canvas canvas,
    Offset anchor,
    String text,
    double opacity, {
    bool below = false,
  }) {
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
    final pos = below
        ? Offset(anchor.dx - tp.width / 2, anchor.dy + 12)
        : Offset(anchor.dx - tp.width / 2, anchor.dy - 16 - tp.height);
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
