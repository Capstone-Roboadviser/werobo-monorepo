import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/chart_point_filters.dart';
import '../../../app/theme.dart';
import '../../../models/chart_data.dart';
import '../../../models/portfolio_data.dart';
import '../../../services/mock_chart_data.dart';

// ── Main chart widget ──

class PortfolioCharts extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartPoint>? benchmarkVolatilityPoints;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;
  final bool useFallbackMock;

  const PortfolioCharts({
    super.key,
    required this.type,
    this.volatilityPoints,
    this.benchmarkVolatilityPoints,
    this.comparisonLines,
    this.rebalanceDates,
    this.useFallbackMock = true,
  });

  @override
  State<PortfolioCharts> createState() => _PortfolioChartsState();
}

class _PortfolioChartsState extends State<PortfolioCharts> {
  int _topTab = 0; // 0=변동성/성과, 1=포트폴리오 비교

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        // Top toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: tc.card,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _ToggleTab(
                  label: '변동성',
                  isActive: _topTab == 0,
                  onTap: () => setState(() => _topTab = 0),
                ),
                _ToggleTab(
                  label: '포트폴리오 비교',
                  isActive: _topTab == 1,
                  onTap: () => setState(() => _topTab = 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _topTab == 0
                ? _VolReturnView(
                    key: const ValueKey('volret'),
                    type: widget.type,
                    volatilityPoints: widget.volatilityPoints,
                    benchmarkVolatilityPoints: widget.benchmarkVolatilityPoints,
                    useFallbackMock: widget.useFallbackMock,
                  )
                : _ComparisonView(
                    key: const ValueKey('comp'),
                    type: widget.type,
                    comparisonLines: widget.comparisonLines,
                    rebalanceDates: widget.rebalanceDates,
                    useFallbackMock: widget.useFallbackMock,
                  ),
          ),
        ),
      ],
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleTab(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? WeRoboColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: WeRoboTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isActive ? WeRoboColors.white : tc.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── View 1: 변동성 ──

class _VolReturnView extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartPoint>? benchmarkVolatilityPoints;
  final bool useFallbackMock;

  const _VolReturnView({
    super.key,
    required this.type,
    this.volatilityPoints,
    this.benchmarkVolatilityPoints,
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

  List<ChartPoint>? get _benchmarkPoints {
    final raw = widget.benchmarkVolatilityPoints;
    if (raw == null || raw.isEmpty) return null;
    return _filterByRange(raw);
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                          final x = d.localPosition.dx - 36;
                          final chartW = constraints.maxWidth - 36 - 12;
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
                                benchmarkPoints: _benchmarkPoints,
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

// ── View 2: 포트폴리오 비교 ──

class _ComparisonView extends StatefulWidget {
  final InvestmentType type;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;
  final bool useFallbackMock;

  const _ComparisonView({
    super.key,
    required this.type,
    this.comparisonLines,
    this.rebalanceDates,
    required this.useFallbackMock,
  });

  @override
  State<_ComparisonView> createState() => _ComparisonViewState();
}

class _ComparisonViewState extends State<_ComparisonView>
    with SingleTickerProviderStateMixin {
  late AnimationController _drawCtrl;
  int? _touchIndex;
  int _range = 4; // index into _ranges
  bool _show7AssetAvg = true;
  bool _showBondTrend = true;

  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체'];
  static const _rangeDays = [7, 90, 365, 1825, 99999];

  @override
  void initState() {
    super.initState();
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

  static List<ChartLine> _allMockComparisonLines() {
    final seen = <String>{};
    final result = <ChartLine>[];
    for (final t in InvestmentType.values) {
      for (final line in MockChartData.comparisonLines(t)) {
        if (seen.add(line.key)) result.add(line);
      }
    }
    return result;
  }

  /// Use the explicit 7-asset-class benchmark line from the backend.
  ChartLine? _buildBenchmarkLine(List<ChartLine> rawLines) {
    for (final line in rawLines) {
      if (line.key == 'benchmark_avg') {
        return line;
      }
    }
    return null;
  }

  List<ChartLine> _filterByType(List<ChartLine> rawLines) {
    final code = widget.type.riskCode;
    final result = <ChartLine>[];

    // Selected portfolio line
    for (final line in rawLines) {
      if (line.key == code) {
        result.add(line);
        break;
      }
    }

    // 7-asset average benchmark (toggle-controlled)
    if (_show7AssetAvg) {
      final bench = _buildBenchmarkLine(rawLines);
      if (bench != null) result.add(bench);
    }

    // Bond trend: straight line from treasury start to end
    if (_showBondTrend) {
      final bond = _buildBondTrendLine(rawLines);
      if (bond != null) result.add(bond);
    }

    return result;
  }

  Widget _buildToggleButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
    required WeRoboThemeColors tc,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF999999).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF999999) : tc.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: WeRoboTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10,
            color: active ? tc.textPrimary : tc.textTertiary,
          ),
        ),
      ),
    );
  }

  /// Build a straight line from the first to last point of the
  /// treasury (IEF) comparison line.
  ChartLine? _buildBondTrendLine(List<ChartLine> rawLines) {
    ChartLine? treasury;
    for (final line in rawLines) {
      if (line.key == 'treasury') {
        treasury = line;
        break;
      }
    }
    if (treasury == null || treasury.points.length < 2) return null;
    final first = treasury.points.first;
    final last = treasury.points.last;
    return ChartLine(
      key: 'bond_trend',
      label: '채권 수익률',
      color: const Color(0xFF999999).withValues(alpha: 0.4),
      dashed: true,
      points: [first, last],
    );
  }

  List<ChartLine> _filterByRange(List<ChartLine> rawLines) {
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    return rawLines.map((line) {
      final filtered =
          line.points.where((p) => p.date.isAfter(cutoff)).toList();
      final rangedPoints = filtered.isNotEmpty ? filtered : line.points;
      final rebasedPoints = rebaseChartPointsToFirstValue(rangedPoints);
      return ChartLine(
        key: line.key,
        label: line.label,
        color: line.color,
        dashed: line.dashed,
        points: rebasedPoints,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final allLines = widget.comparisonLines ??
        (widget.useFallbackMock
            ? _allMockComparisonLines()
            : const <ChartLine>[]);
    final typedLines = allLines.isEmpty ? allLines : _filterByType(allLines);
    final lines = typedLines.isEmpty ? typedLines : _filterByRange(typedLines);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Benchmark toggles
          Row(
            children: [
              _buildToggleButton(
                label: '7자산 평균',
                active: _show7AssetAvg,
                onTap: () {
                  setState(() => _show7AssetAvg = !_show7AssetAvg);
                  _drawCtrl.forward(from: 0);
                },
                tc: tc,
              ),
              const SizedBox(width: 6),
              _buildToggleButton(
                label: '채권 수익률',
                active: _showBondTrend,
                onTap: () {
                  setState(() => _showBondTrend = !_showBondTrend);
                  _drawCtrl.forward(from: 0);
                },
                tc: tc,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          // Time range chips
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(_rangeLabels.length, (i) {
              final active = _range == i;
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _range = i);
                    _drawCtrl.forward(from: 0);
                  },
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
          const SizedBox(height: 8),
          // Chart
          Expanded(
            child: lines.isEmpty
                ? const _EmptyChartState(
                    message: '비교 백테스트 데이터가 아직 없습니다.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanUpdate: (d) {
                          if (lines.isEmpty || lines[0].points.isEmpty) return;
                          final x = d.localPosition.dx - 36;
                          final chartW = constraints.maxWidth - 36 - 12;
                          final count = lines[0].points.length;
                          final idx = ((x / chartW) * (count - 1))
                              .round()
                              .clamp(0, count - 1);
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
                              painter: _MultiLineChartPainter(
                                lines: lines,
                                progress: _drawCtrl.value,
                                touchIndex: _touchIndex,
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
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: lines.map((l) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: l.color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: l.dashed
                        ? null
                        : null, // visual only, dashing shown in paint
                  ),
                  const SizedBox(width: 4),
                  Text(l.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: tc.textSecondary,
                      )),
                ],
              );
            }).toList(),
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
  final List<ChartPoint>? benchmarkPoints;
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
    this.benchmarkPoints,
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
    const padL = 36.0;
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
    // Include benchmark values in Y-axis scaling
    final bp = benchmarkPoints;
    if (bp != null && bp.isNotEmpty) {
      for (final p in bp) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
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

    // Benchmark dashed line (7-asset average volatility)
    if (bp != null && bp.length >= 2) {
      final benchPath = Path();
      final benchCount = (bp.length * progress).ceil().clamp(0, bp.length);
      if (benchCount >= 2) {
        for (int i = 0; i < benchCount; i++) {
          final x = padL + w * i / (bp.length - 1);
          final y = h - ((bp[i].value - minY) / rangeY) * h;
          if (i == 0) {
            benchPath.moveTo(x, y);
          } else {
            benchPath.lineTo(x, y);
          }
        }
        final benchPaint = Paint()
          ..color = const Color(0xFF999999).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        _drawDashedPath(canvas, benchPath, benchPaint);
      }
    }

    // Build path
    final drawCount = (points.length * progress).ceil().clamp(0, points.length);
    if (drawCount < 2) return;

    final linePath = Path();
    final areaPath = Path();

    for (int i = 0; i < drawCount; i++) {
      final x = padL + w * i / (points.length - 1);
      final y = h - ((values[i] - minY) / rangeY) * h;
      if (i == 0) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, h); // bottom
        areaPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }

    // Area fill gradient
    final lastX = padL + w * (drawCount - 1) / (points.length - 1);
    areaPath.lineTo(lastX, h);
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
      old.progress != progress || old.touchIndex != touchIndex;
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

  _MultiLineChartPainter({
    required this.lines,
    required this.progress,
    this.touchIndex,
    required this.gridColor,
    required this.textTertiaryColor,
    required this.textPrimaryColor,
    required this.tooltipBackground,
    required this.tooltipBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    const padL = 36.0;
    const padR = 12.0;
    const padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padB;

    // Y range across all lines
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final p in line.points) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
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

    // Draw lines
    for (final line in lines) {
      final pts = line.points;
      final count = pts.length;
      final drawCount = (count * progress).ceil().clamp(0, count);
      if (drawCount < 2) continue;

      final path = Path();
      for (int i = 0; i < drawCount; i++) {
        final x = padL + w * i / (count - 1);
        final y = h - ((pts[i].value - minY) / rangeY) * h;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
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

    // Crosshair
    if (touchIndex != null && lines.isNotEmpty) {
      final pts = lines[0].points;
      if (touchIndex! < pts.length) {
        final tx = padL + w * touchIndex! / (pts.length - 1);
        canvas.drawLine(
            Offset(tx, 0),
            Offset(tx, h),
            Paint()
              ..color = gridColor
              ..strokeWidth = 1);

        // Dots for each line
        for (final line in lines) {
          if (touchIndex! < line.points.length) {
            final val = line.points[touchIndex!].value;
            final ty = h - ((val - minY) / rangeY) * h;
            canvas.drawCircle(Offset(tx, ty), 4, Paint()..color = line.color);
            canvas.drawCircle(
                Offset(tx, ty), 2, Paint()..color = tooltipBackground);
          }
        }

        // Tooltip
        final date = pts[touchIndex!].date;
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        var tooltipLines = dateStr;
        for (final line in lines) {
          if (!line.dashed && touchIndex! < line.points.length) {
            tooltipLines +=
                '\n${line.label}: ${(line.points[touchIndex!].value * 100).toStringAsFixed(1)}%';
          }
        }
        _drawTooltip(canvas, Offset(tx, 10), tooltipLines, size.width);
      }
    }

    // X-axis labels
    if (lines.isNotEmpty && lines[0].points.length > 1) {
      final pts = lines[0].points;
      final dateStyle = TextStyle(
        fontSize: 8,
        color: textTertiaryColor,
        fontFamily: WeRoboFonts.english,
      );
      for (int i = 0; i < 5; i++) {
        final idx = (pts.length - 1) * i ~/ 4;
        final d = pts[idx].date;
        final label = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        final x = padL + w * idx / (pts.length - 1);
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
      old.progress != progress || old.touchIndex != touchIndex;
}

// ── Shared helpers ──

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
