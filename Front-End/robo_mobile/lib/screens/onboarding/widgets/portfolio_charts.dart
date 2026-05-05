import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/chart_point_filters.dart';
import '../../../app/theme.dart';
import '../../../models/chart_data.dart';
import '../../../models/portfolio_data.dart';
import '../../../services/mock_chart_data.dart';

/// Time-window selector for time-series charts on the portfolio review
/// screen. Drives the range chip row in `PortfolioComparisonChart`.
enum TimeRange {
  oneWeek('1주', 7),
  threeMonth('3달', 90),
  oneYear('1년', 365),
  threeYear('3년', 1095),
  fiveYear('5년', 1825),
  all('전체', 99999);

  final String label;
  final int days;
  const TimeRange(this.label, this.days);
}

/// Reusable multi-line comparison chart for the portfolio review screen.
///
/// Accepts data as parallel `seriesData` rows (each row is one series, e.g.
/// portfolio cumulative return, market benchmark, expected return, bond
/// benchmark) sharing a single `timeAxis`. Renders an empty state when the
/// data is missing so the screen degrades gracefully before the backend
/// wiring lands in a follow-up task.
class PortfolioComparisonChart extends StatefulWidget {
  /// Each inner list is one series sampled along [timeAxis]. All series
  /// must have the same length as [timeAxis] (mismatched rows are
  /// dropped). Series order follows the chart legend convention:
  /// portfolio first, then benchmarks.
  final List<List<double>> seriesData;
  final List<DateTime> timeAxis;

  /// Time-window the chart starts on. Default `threeYear` matches the
  /// post-frontier review screen brief (2026-05-05 design notes).
  final TimeRange initialRange;

  /// Optional override for the legend labels. When null the chart falls
  /// back to the static defaults (포트폴리오 / 시장 / 연 기대수익률 / 채권 수익률).
  /// Each label maps positionally to the corresponding row in
  /// [seriesData]; callers are responsible for matching the order.
  final List<String>? seriesLabels;

  /// Gesture flags wired in Task 3.5. Currently accepted but inert so the
  /// review screen can pass them through without an API churn later.
  final bool enablePinchZoom;
  final bool enableHorizontalDrag;

  const PortfolioComparisonChart({
    super.key,
    required this.seriesData,
    required this.timeAxis,
    this.initialRange = TimeRange.threeYear,
    this.seriesLabels,
    this.enablePinchZoom = false,
    this.enableHorizontalDrag = false,
  });

  @override
  State<PortfolioComparisonChart> createState() =>
      _PortfolioComparisonChartState();
}

class _PortfolioComparisonChartState extends State<PortfolioComparisonChart>
    with SingleTickerProviderStateMixin {
  // Each label maps 1:1 with `_seriesPalette` so colors stay stable across
  // tab switches when the parent re-renders.
  static const _seriesLabels = ['포트폴리오', '시장', '연 기대수익률', '채권 수익률'];
  static const _seriesPalette = [
    WeRoboColors.primary,
    Color(0xFF64748B),
    WeRoboColors.assetTier4,
    Color(0xFF999999),
  ];
  // Indexes into `_seriesPalette` that should render dashed (benchmarks
  // that are projections rather than realized returns).
  static const _dashedIndexes = {2, 3};

  late TimeRange _range;
  int? _touchIndex;
  late AnimationController _drawCtrl;

  // Pinch-zoom + horizontal-drag state. `_scale` multiplies the chart's
  // x-extent and `_panOffsetX` shifts it horizontally (in canvas pixels).
  // `_prevScale`/`_prevPanOffsetX` snapshot the values at gesture start so
  // each ScaleUpdate composes against the gesture origin, not against the
  // continuously-mutating live values.
  double _scale = 1.0;
  double _prevScale = 1.0;
  double _panOffsetX = 0.0;
  double _prevPanOffsetX = 0.0;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails d) {
    _prevScale = _scale;
    _prevPanOffsetX = _panOffsetX;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double chartWidth, int pointCount) {
    // Single-pointer drag = crosshair tap (NOT pan). Two-or-more-pointer
    // gestures route to the pinch-zoom + horizontal-pan transform so the
    // tap-to-tooltip behavior survives the gesture-enabled branch.
    if (d.pointerCount == 1) {
      _setTouchIndexFromX(d.localFocalPoint.dx, chartWidth, pointCount);
      return;
    }
    setState(() {
      _scale = (_prevScale * d.scale).clamp(0.5, 5.0);
      _panOffsetX = _prevPanOffsetX + d.focalPointDelta.dx;
    });
  }

  void _setTouchIndexFromX(double tapX, double chartWidth, int pointCount) {
    if (pointCount <= 1) return;
    final innerX = tapX - 28; // padL
    final innerW = chartWidth - 28 - 12; // padL + padR
    if (innerW <= 0) return;
    final idx = ((innerX / innerW) * (pointCount - 1))
        .round()
        .clamp(0, pointCount - 1);
    setState(() => _touchIndex = idx);
  }

  void _resetTransform() {
    setState(() {
      _scale = 1.0;
      _panOffsetX = 0.0;
      _prevScale = 1.0;
      _prevPanOffsetX = 0.0;
    });
  }

  /// Returns the chart lines after filtering by the current time range and
  /// rebasing each series so the first visible point sits at zero return
  /// (matches the existing `_ComparisonView` rebasing behavior).
  List<ChartLine> _buildLines() {
    final timeAxis = widget.timeAxis;
    if (timeAxis.isEmpty) {
      return const [];
    }
    final latest = timeAxis.last;
    final cutoff = latest.subtract(Duration(days: _range.days));
    final firstVisible = timeAxis.indexWhere((d) => !d.isBefore(cutoff));
    final startIdx = firstVisible < 0 ? 0 : firstVisible;

    final labels = widget.seriesLabels ?? _seriesLabels;

    final lines = <ChartLine>[];
    for (var i = 0; i < widget.seriesData.length; i++) {
      final raw = widget.seriesData[i];
      if (raw.length != timeAxis.length) continue;
      final rangedPoints = <ChartPoint>[
        for (var j = startIdx; j < timeAxis.length; j++)
          ChartPoint(date: timeAxis[j], value: raw[j]),
      ];
      if (rangedPoints.length < 2) continue;
      final rebased = rebaseChartPointsToFirstValue(rangedPoints);
      lines.add(ChartLine(
        key: 'series_$i',
        label: i < labels.length ? labels[i] : 'series ${i + 1}',
        color: i < _seriesPalette.length
            ? _seriesPalette[i]
            : Colors.grey,
        dashed: _dashedIndexes.contains(i),
        points: rebased,
      ));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final lines = _buildLines();
    if (lines.isEmpty) {
      return const _EmptyChartState(message: '비교 데이터가 없어요');
    }

    final gesturesEnabled =
        widget.enablePinchZoom || widget.enableHorizontalDrag;

    return Column(
      children: [
        // Time-range chip row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final r in TimeRange.values)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () {
                    if (_range == r) return;
                    setState(() => _range = r);
                    _drawCtrl.forward(from: 0);
                    _resetTransform();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _range == r
                          ? WeRoboColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _range == r
                            ? WeRoboColors.white
                            : tc.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartArea = AnimatedBuilder(
                animation: _drawCtrl,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                    painter: _MultiLineChartPainter(
                      lines: lines,
                      progress: _drawCtrl.value,
                      touchIndex: _touchIndex,
                      gridColor: tc.border,
                      textTertiaryColor: tc.textTertiary,
                      textPrimaryColor: tc.textPrimary,
                      tooltipBackground: tc.surface,
                      tooltipBorder: tc.border,
                      scale: _scale,
                      panOffsetX: _panOffsetX,
                    ),
                  );
                },
              );

              // When gestures are off, render the chart with only the
              // existing crosshair/touch tap handling — no scale/drag.
              if (!gesturesEnabled) {
                return GestureDetector(
                  onPanUpdate: (d) {
                    final pts = lines.first.points;
                    if (pts.isEmpty) return;
                    final x = d.localPosition.dx - 28;
                    final chartW = constraints.maxWidth - 28 - 12;
                    final idx = ((x / chartW) * (pts.length - 1))
                        .round()
                        .clamp(0, pts.length - 1);
                    setState(() => _touchIndex = idx);
                  },
                  onPanEnd: (_) => setState(() => _touchIndex = null),
                  onTapUp: (_) => setState(() => _touchIndex = null),
                  child: chartArea,
                );
              }

              // When gestures are on, scale gestures route by pointer count:
              // single-pointer = crosshair tap (sets _touchIndex), two+
              // pointers = pinch-zoom + horizontal pan. onTapUp keeps a
              // quick single tap surfacing the tooltip too. Double-tap
              // resets the transform.
              final pointCount = lines.first.points.length;
              return GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: (d) =>
                    _onScaleUpdate(d, constraints.maxWidth, pointCount),
                onScaleEnd: (_) {
                  _prevScale = _scale;
                  _prevPanOffsetX = _panOffsetX;
                },
                onTapUp: (d) => _setTouchIndexFromX(
                    d.localPosition.dx, constraints.maxWidth, pointCount),
                onDoubleTap: _resetTransform,
                child: chartArea,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final l in lines)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: l.color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: tc.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ── Main chart widget ──

class PortfolioCharts extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;
  final double? expectedAnnualReturn;
  final bool useFallbackMock;

  const PortfolioCharts({
    super.key,
    required this.type,
    this.volatilityPoints,
    this.comparisonLines,
    this.rebalanceDates,
    this.expectedAnnualReturn,
    this.useFallbackMock = true,
  });

  @override
  State<PortfolioCharts> createState() => _PortfolioChartsState();
}

class _PortfolioChartsState extends State<PortfolioCharts> {
  @override
  Widget build(BuildContext context) {
    return _VolReturnView(
      type: widget.type,
      volatilityPoints: widget.volatilityPoints,
      useFallbackMock: widget.useFallbackMock,
    );
  }
}

// ── View 1: 변동성 ──

class _VolReturnView extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final bool useFallbackMock;

  const _VolReturnView({
    required this.type,
    this.volatilityPoints,
    required this.useFallbackMock,
  });

  @override
  State<_VolReturnView> createState() => _VolReturnViewState();
}

class _VolReturnViewState extends State<_VolReturnView>
    with SingleTickerProviderStateMixin {
  int _range = 4; // index into _ranges
  int? _touchIndex;
  late AnimationController _drawCtrl;

  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체'];
  static const _rangeDays = [7, 90, 365, 1825, 99999];

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    super.dispose();
  }

  List<ChartPoint> _filterByRange(List<ChartPoint> all) {
    if (all.isEmpty) return const <ChartPoint>[];
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    final filtered = all.where((p) => p.date.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  List<ChartPoint> get _points {
    final all = widget.volatilityPoints ??
        (widget.useFallbackMock
            ? MockChartData.volatilityHistory(widget.type)
            : const <ChartPoint>[]);
    return _filterByRange(all);
  }

  double _expectedVolatility() {
    return widget.type == InvestmentType.safe
        ? 0.084
        : widget.type == InvestmentType.balanced
            ? 0.108
            : 0.137;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final points = _points;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Time range chips
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(_rangeLabels.length, (i) {
              final active = _range == i;
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _range = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? WeRoboColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _rangeLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active ? WeRoboColors.white : tc.textTertiary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Chart
          Expanded(
            child: points.isEmpty
                ? const _EmptyChartState(
                    message: '아직 차트 데이터를 준비하는 중입니다.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanUpdate: (d) {
                          if (points.isEmpty) return;
                          final x = d.localPosition.dx - 28;
                          final chartW = constraints.maxWidth - 28 - 12;
                          final idx = ((x / chartW) * (points.length - 1))
                              .round()
                              .clamp(0, points.length - 1);
                          setState(() => _touchIndex = idx);
                        },
                        onPanEnd: (_) => setState(() => _touchIndex = null),
                        onTapUp: (_) => setState(() => _touchIndex = null),
                        child: AnimatedBuilder(
                          animation: _drawCtrl,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              painter: _AreaChartPainter(
                                points: points,
                                progress: _drawCtrl.value,
                                color: WeRoboColors.primary,
                                touchIndex: _touchIndex,
                                valueLabel: '변동성',
                                baselineValue: _expectedVolatility(),
                                baselineLabel: '기대 변동성',
                                gridColor: tc.border,
                                textTertiaryColor: tc.textTertiary,
                                textPrimaryColor: tc.textPrimary,
                                tooltipBackground: tc.surface,
                                tooltipBorder: tc.border,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}


class _EmptyChartState extends StatelessWidget {
  final String message;

  const _EmptyChartState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: WeRoboTypography.bodySmall.themed(context),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Painters ──

class _AreaChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final double progress;
  final Color color;
  final int? touchIndex;
  final String valueLabel;
  final double? baselineValue;
  final String? baselineLabel;
  final Color gridColor;
  final Color textTertiaryColor;
  final Color textPrimaryColor;
  final Color tooltipBackground;
  final Color tooltipBorder;

  _AreaChartPainter({
    required this.points,
    required this.progress,
    required this.color,
    this.touchIndex,
    required this.valueLabel,
    this.baselineValue,
    this.baselineLabel,
    required this.gridColor,
    required this.textTertiaryColor,
    required this.textPrimaryColor,
    required this.tooltipBackground,
    required this.tooltipBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const padL = 28.0;
    const padR = 12.0;
    const padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padB;

    final values = points.map((p) => p.value).toList();
    var minY = values.reduce(min);
    var maxY = values.reduce(max);
    if (baselineValue != null) {
      if (baselineValue! < minY) minY = baselineValue!;
      if (baselineValue! > maxY) maxY = baselineValue!;
    }
    final rangeY = (maxY - minY).clamp(0.001, double.infinity);

    // Grid
    _drawGrid(canvas, size, padL, padR, padB, h, minY, rangeY);

    if (baselineValue != null) {
      final y = h - ((baselineValue! - minY) / rangeY) * h;
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (double x = padL; x < size.width - padR; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 4).clamp(0, size.width - padR), y),
          dashPaint,
        );
      }
      final labelStyle = TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w600,
        fontFamily: WeRoboFonts.english,
      );
      _drawText(
          canvas, baselineLabel ?? '', Offset(padL + 4, y - 14), labelStyle);
    }

    // Build path with smooth interpolation
    final pathPoints = _interpolatedPathPoints(
      n: points.length,
      progress: progress,
      xAt: (i) => padL + w * i / (points.length - 1),
      yAt: (i) => h - ((values[i] - minY) / rangeY) * h,
    );
    if (pathPoints == null) return;

    final linePath = Path();
    final areaPath = Path();

    for (int i = 0; i < pathPoints.length; i++) {
      final pt = pathPoints[i];
      if (i == 0) {
        linePath.moveTo(pt.dx, pt.dy);
        areaPath.moveTo(pt.dx, h); // bottom
        areaPath.lineTo(pt.dx, pt.dy);
      } else {
        linePath.lineTo(pt.dx, pt.dy);
        areaPath.lineTo(pt.dx, pt.dy);
      }
    }

    // Area fill gradient
    areaPath.lineTo(pathPoints.last.dx, h);
    areaPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
    );
    final areaPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(padL, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Crosshair + tooltip
    if (touchIndex != null && touchIndex! < points.length) {
      final ti = touchIndex!;
      final tx = padL + w * ti / (points.length - 1);
      final ty = h - ((values[ti] - minY) / rangeY) * h;

      // Vertical line
      final crossPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(tx, 0), Offset(tx, h), crossPaint);

      // Dot
      canvas.drawCircle(Offset(tx, ty), 5, Paint()..color = color);
      canvas.drawCircle(Offset(tx, ty), 3, Paint()..color = tooltipBackground);

      // Tooltip
      final date = points[ti].date;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final valStr = '${(values[ti] * 100).toStringAsFixed(1)}%';
      _drawTooltip(canvas, Offset(tx, ty - 28),
          '$dateStr\n$valueLabel: $valStr', size.width);
    }

    // X-axis date labels
    _drawDateLabels(canvas, size, padL, w, h, padB);
  }

  void _drawGrid(Canvas canvas, Size size, double padL, double padR,
      double padB, double h, double minY, double rangeY) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: textTertiaryColor,
      fontFamily: WeRoboFonts.english,
    );

    for (int i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      final val = minY + rangeY * i / 4;
      _drawText(canvas, '${(val * 100).toStringAsFixed(1)}%', Offset(0, y - 6),
          labelStyle);
    }
  }

  void _drawDateLabels(
      Canvas canvas, Size size, double padL, double w, double h, double padB) {
    if (points.length < 2) return;
    final style = TextStyle(
      fontSize: 8,
      color: textTertiaryColor,
      fontFamily: WeRoboFonts.english,
    );
    for (int i = 0; i < 5; i++) {
      final idx = (points.length - 1) * i ~/ 4;
      final d = points[idx].date;
      final label = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final x = padL + w * idx / (points.length - 1);
      _drawText(canvas, label, Offset(x - 16, h + 4), style);
    }
  }

  void _drawTooltip(Canvas canvas, Offset pos, String text, double maxW) {
    final style = TextStyle(
      fontSize: 10,
      color: textPrimaryColor,
      fontFamily: WeRoboFonts.english,
      height: 1.4,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    var x = pos.dx - tp.width / 2 - 8;
    x = x.clamp(0, maxW - tp.width - 16);
    final y = pos.dy - tp.height - 8;

    final rect = RRect.fromLTRBR(
        x, y, x + tp.width + 16, y + tp.height + 8, const Radius.circular(6));
    canvas.drawRRect(
        rect,
        Paint()
          ..color = tooltipBackground
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = tooltipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    tp.paint(canvas, Offset(x + 8, y + 4));
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.points != points ||
      old.progress != progress ||
      old.color != color ||
      old.touchIndex != touchIndex ||
      old.baselineValue != baselineValue ||
      old.baselineLabel != baselineLabel;
}

class _MultiLineChartPainter extends CustomPainter {
  final List<ChartLine> lines;
  final double progress;
  final int? touchIndex;
  final Color gridColor;
  final Color textTertiaryColor;
  final Color textPrimaryColor;
  final Color tooltipBackground;
  final Color tooltipBorder;

  /// Pinch-zoom multiplier and horizontal pan offset (in canvas pixels).
  /// At identity (1.0 / 0.0) the painter behaves exactly as before; the
  /// transform applies only to the line/crosshair x-coordinates so axis
  /// labels and gridlines stay anchored to the static canvas frame.
  final double scale;
  final double panOffsetX;

  _MultiLineChartPainter({
    required this.lines,
    required this.progress,
    this.touchIndex,
    required this.gridColor,
    required this.textTertiaryColor,
    required this.textPrimaryColor,
    required this.tooltipBackground,
    required this.tooltipBorder,
    this.scale = 1.0,
    this.panOffsetX = 0.0,
  });

  /// Apply [scale] and [panOffsetX] to a raw chart x. The left padding
  /// (`padL`) is treated as the transform anchor so identity transforms
  /// leave the chart visually unchanged.
  double _xWithTransform(double rawX, double padL) {
    return padL + (rawX - padL) * scale + panOffsetX;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    const padL = 28.0;
    const padR = 12.0;
    const padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padB;
    final allPoints = [
      for (final line in lines)
        for (final point in line.points) point,
    ];
    if (allPoints.isEmpty) return;

    var minDate = allPoints.first.date;
    var maxDate = allPoints.first.date;
    for (final point in allPoints) {
      if (point.date.isBefore(minDate)) minDate = point.date;
      if (point.date.isAfter(maxDate)) maxDate = point.date;
    }

    // Y range across all lines
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final p in allPoints) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    final rangeY = (maxY - minY).clamp(0.001, double.infinity);

    // Grid
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: textTertiaryColor,
      fontFamily: WeRoboFonts.english,
    );

    for (int i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      final val = minY + rangeY * i / 4;
      _drawText(canvas, '${(val * 100).toStringAsFixed(1)}%', Offset(0, y - 6),
          labelStyle);
    }

    // Clip the line/crosshair drawing to the chart area so a zoomed or
    // panned series doesn't bleed across the axis labels.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(padL, 0, w, h));

    // Draw lines (with zoom/pan applied)
    for (final line in lines) {
      final pts = line.points;
      final count = pts.length;
      final pathPoints = _interpolatedPathPoints(
        n: count,
        progress: progress,
        xAt: (i) => _xWithTransform(
          _xForDate(pts[i].date, minDate, maxDate, padL, w),
          padL,
        ),
        yAt: (i) => h - ((pts[i].value - minY) / rangeY) * h,
      );
      if (pathPoints == null) continue;

      final path = Path();
      for (int i = 0; i < pathPoints.length; i++) {
        final pt = pathPoints[i];
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }

      final paint = Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      if (line.dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    // Crosshair (also subject to the same transform so it tracks the
    // visible series under zoom/pan).
    if (touchIndex != null && lines.isNotEmpty) {
      final pts = lines[0].points;
      if (touchIndex! < pts.length) {
        final touchDate = pts[touchIndex!].date;
        final tx = _xWithTransform(
          _xForDate(touchDate, minDate, maxDate, padL, w),
          padL,
        );
        canvas.drawLine(
            Offset(tx, 0),
            Offset(tx, h),
            Paint()
              ..color = gridColor
              ..strokeWidth = 1);

        // Dots for each line
        for (final line in lines) {
          final nearestIndex = _nearestPointIndexByDate(line.points, touchDate);
          if (nearestIndex != null) {
            final val = line.points[nearestIndex].value;
            final ty = h - ((val - minY) / rangeY) * h;
            canvas.drawCircle(Offset(tx, ty), 4, Paint()..color = line.color);
            canvas.drawCircle(
                Offset(tx, ty), 2, Paint()..color = tooltipBackground);
          }
        }
      }
    }

    canvas.restore();

    // Tooltip (drawn outside the clip so it can overflow the chart area).
    if (touchIndex != null && lines.isNotEmpty) {
      final pts = lines[0].points;
      if (touchIndex! < pts.length) {
        final touchDate = pts[touchIndex!].date;
        final tx = _xWithTransform(
          _xForDate(touchDate, minDate, maxDate, padL, w),
          padL,
        );
        final dateStr = _formatDate(touchDate);
        var tooltipLines = dateStr;
        for (final line in lines) {
          final nearestIndex = _nearestPointIndexByDate(line.points, touchDate);
          if (!line.dashed && nearestIndex != null) {
            tooltipLines +=
                '\n${line.label}: ${(line.points[nearestIndex].value * 100).toStringAsFixed(1)}%';
          }
        }
        _drawTooltip(canvas, Offset(tx, 10), tooltipLines, size.width);
      }
    }

    // X-axis labels
    if (maxDate.isAfter(minDate)) {
      final dateStyle = TextStyle(
        fontSize: 8,
        color: textTertiaryColor,
        fontFamily: WeRoboFonts.english,
      );
      for (int i = 0; i < 5; i++) {
        final d = minDate.add(
          Duration(
            milliseconds:
                (maxDate.difference(minDate).inMilliseconds * i / 4).round(),
          ),
        );
        final label = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        final x = _xForDate(d, minDate, maxDate, padL, w);
        _drawText(canvas, label, Offset(x - 16, h + 4), dateStyle);
      }
    }
  }

  void _drawTooltip(Canvas canvas, Offset pos, String text, double maxW) {
    final style = TextStyle(
      fontSize: 10,
      color: textPrimaryColor,
      fontFamily: WeRoboFonts.english,
      height: 1.4,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    var x = pos.dx - tp.width / 2 - 8;
    x = x.clamp(0, maxW - tp.width - 16);

    final rect = RRect.fromLTRBR(x, pos.dy, x + tp.width + 16,
        pos.dy + tp.height + 8, const Radius.circular(6));
    canvas.drawRRect(rect, Paint()..color = tooltipBackground);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = tooltipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    tp.paint(canvas, Offset(x + 8, pos.dy + 4));
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter old) =>
      old.lines != lines ||
      old.progress != progress ||
      old.touchIndex != touchIndex ||
      old.scale != scale ||
      old.panOffsetX != panOffsetX;
}

double _xForDate(
  DateTime date,
  DateTime minDate,
  DateTime maxDate,
  double padL,
  double width,
) {
  final totalMs = maxDate.difference(minDate).inMilliseconds;
  if (totalMs <= 0) return padL;
  final elapsedMs = date.difference(minDate).inMilliseconds;
  return padL + width * (elapsedMs / totalMs).clamp(0.0, 1.0);
}

int? _nearestPointIndexByDate(List<ChartPoint> points, DateTime targetDate) {
  if (points.isEmpty) return null;
  var nearestIndex = 0;
  var nearestDistance =
      points.first.date.difference(targetDate).inMilliseconds.abs();
  for (var i = 1; i < points.length; i++) {
    final distance = points[i].date.difference(targetDate).inMilliseconds.abs();
    if (distance < nearestDistance) {
      nearestIndex = i;
      nearestDistance = distance;
    }
  }
  return nearestIndex;
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ── Shared helpers ──

/// Compute canvas offsets for a smoothly animated line.
/// Returns null when there is nothing to draw yet.
List<Offset>? _interpolatedPathPoints({
  required int n,
  required double progress,
  required double Function(int i) xAt,
  required double Function(int i) yAt,
}) {
  if (n < 2 || progress <= 0) return null;

  final fIdx = (n - 1) * progress.clamp(0.0, 1.0);
  final complete = fIdx.floor();
  final frac = fIdx - complete;

  final result = <Offset>[];
  for (int i = 0; i <= complete; i++) {
    result.add(Offset(xAt(i), yAt(i)));
  }

  if (frac > 0 && complete < n - 1) {
    final fx = xAt(complete), fy = yAt(complete);
    final tx = xAt(complete + 1), ty = yAt(complete + 1);
    result.add(Offset(fx + frac * (tx - fx), fy + frac * (ty - fy)));
  }

  return result.length < 2 ? null : result;
}

/// Draw a path as a dashed line using PathMetrics.
/// Dash pattern: 6px on, 10px gap.
void _drawDashedPath(Canvas canvas, Path path, Paint paint,
    {double dashLen = 6, double gapLen = 10}) {
  for (final metric in path.computeMetrics()) {
    double dist = 0;
    while (dist < metric.length) {
      final end = (dist + dashLen).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(dist, end), paint);
      dist += dashLen + gapLen;
    }
  }
}
