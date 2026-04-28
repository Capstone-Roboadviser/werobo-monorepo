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
  int _topTab = 0; // 0=변동성/성과, 1=포트폴리오 비교

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        // Top toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
            duration: WeRoboMotion.medium,
            child: _topTab == 0
                ? _VolReturnView(
                    key: const ValueKey('volret'),
                    type: widget.type,
                    volatilityPoints: widget.volatilityPoints,
                    useFallbackMock: widget.useFallbackMock,
                  )
                : _ComparisonView(
                    key: const ValueKey('comp'),
                    type: widget.type,
                    comparisonLines: widget.comparisonLines,
                    rebalanceDates: widget.rebalanceDates,
                    expectedAnnualReturn: widget.expectedAnnualReturn,
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
          duration: WeRoboMotion.short,
          curve: WeRoboMotion.move,
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
  final bool useFallbackMock;

  const _VolReturnView({
    super.key,
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

// ── View 2: 포트폴리오 비교 ──

class _ComparisonView extends StatefulWidget {
  final InvestmentType type;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;
  final double? expectedAnnualReturn;
  final bool useFallbackMock;

  const _ComparisonView({
    super.key,
    required this.type,
    this.comparisonLines,
    this.rebalanceDates,
    this.expectedAnnualReturn,
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
  bool _showAssetAvg = true;
  bool _showExpectedReturn = true;
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

  /// Use the explicit asset-benchmark line from the backend.
  ChartLine? _buildBenchmarkLine(List<ChartLine> rawLines) {
    for (final line in rawLines) {
      if (line.key == 'benchmark_avg') {
        return ChartLine(
          key: line.key,
          label: '시장',
          color: const Color(0xFF64748B),
          dashed: false,
          points: line.points,
        );
      }
    }
    return null;
  }

  ChartLine? _buildPortfolioLine(List<ChartLine> rawLines) {
    for (final key in [widget.type.riskCode, 'selected']) {
      for (final line in rawLines) {
        if (line.key == key) {
          return _normalizePortfolioLine(line);
        }
      }
    }

    for (final line in rawLines) {
      if (_isPortfolioCandidateLine(line)) {
        return _normalizePortfolioLine(line);
      }
    }
    return null;
  }

  bool _isPortfolioCandidateLine(ChartLine line) {
    return line.key != 'benchmark_avg' &&
        line.key != 'treasury' &&
        line.key != 'bond_trend' &&
        line.key != 'expected_return' &&
        !line.key.endsWith('_expected') &&
        !line.label.contains('기대수익');
  }

  ChartLine _normalizePortfolioLine(ChartLine line) {
    final normalizedLabel =
        line.label.trim().isEmpty || line.label == 'selected'
            ? '선택 포트폴리오'
            : line.label;
    return ChartLine(
      key: line.key,
      label: normalizedLabel,
      color: WeRoboColors.primary,
      dashed: false,
      points: line.points,
    );
  }

  List<ChartLine> _filterByType(List<ChartLine> rawLines) {
    final result = <ChartLine>[];

    // Selected portfolio line — relabel to generic "포트폴리오"
    final portfolioLine = _buildPortfolioLine(rawLines);
    if (portfolioLine != null) {
      result.add(ChartLine(
        key: portfolioLine.key,
        label: '포트폴리오',
        color: WeRoboColors.primary,
        dashed: false,
        points: portfolioLine.points,
      ));
    }

    // Asset-class average benchmark (toggle-controlled)
    if (_showAssetAvg) {
      final bench = _buildBenchmarkLine(rawLines);
      if (bench != null) result.add(bench);
    }

    // Include raw treasury so bond trend can be built after range filter
    if (_showBondTrend) {
      for (final line in rawLines) {
        if (line.key == 'treasury') {
          result.add(line);
          break;
        }
      }
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

  List<ChartLine> _filterByRange(List<ChartLine> rawLines) {
    final latestDate = _latestPointDate(rawLines) ?? DateTime.now();
    final cutoff = latestDate.subtract(Duration(days: _rangeDays[_range]));
    return rawLines.map((line) {
      final filtered =
          line.points.where((p) => !p.date.isBefore(cutoff)).toList();
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

  DateTime? _latestPointDate(List<ChartLine> lines) {
    DateTime? latest;
    for (final line in lines) {
      for (final point in line.points) {
        if (latest == null || point.date.isAfter(latest)) {
          latest = point.date;
        }
      }
    }
    return latest;
  }

  ChartLine? _buildExpectedReturnLine(List<ChartLine> rangedLines) {
    final expectedAnnualReturn = widget.expectedAnnualReturn;
    if (expectedAnnualReturn == null) {
      return null;
    }

    final portfolioLine = rangedLines
        .where((line) => line.key != 'benchmark_avg' && line.key != 'treasury')
        .firstOrNull;
    if (portfolioLine == null || portfolioLine.points.length < 2) {
      return null;
    }

    final first = portfolioLine.points.first;
    final last = portfolioLine.points.last;
    final elapsedDays = max(0, last.date.difference(first.date).inDays);
    final expectedReturn = expectedAnnualReturn * (elapsedDays / 365.25);

    return ChartLine(
      key: 'expected_return',
      label: '연 기대수익률',
      color: WeRoboColors.chartGreen.withValues(alpha: 0.85),
      dashed: true,
      points: [
        ChartPoint(date: first.date, value: 0.0),
        ChartPoint(date: last.date, value: expectedReturn),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final allLines = widget.comparisonLines ??
        (widget.useFallbackMock
            ? _allMockComparisonLines()
            : const <ChartLine>[]);
    final typedLines = allLines.isEmpty ? allLines : _filterByType(allLines);
    var lines = typedLines.isEmpty ? typedLines : _filterByRange(typedLines);

    if (_showExpectedReturn) {
      final expectedReturnLine = _buildExpectedReturnLine(lines);
      if (expectedReturnLine != null) {
        lines = [...lines, expectedReturnLine];
      }
    }

    // Build bond trend from range-filtered treasury, then replace treasury
    if (_showBondTrend) {
      final rangedTreasury =
          lines.where((l) => l.key == 'treasury').firstOrNull;
      if (rangedTreasury != null && rangedTreasury.points.length >= 2) {
        final first = rangedTreasury.points.first;
        final last = rangedTreasury.points.last;
        lines = [
          ...lines.where((l) => l.key != 'treasury'),
          ChartLine(
            key: 'bond_trend',
            label: '채권 수익률',
            color: const Color(0xFF999999).withValues(alpha: 0.4),
            dashed: true,
            points: [first, last],
          ),
        ];
      } else {
        lines = lines.where((l) => l.key != 'treasury').toList();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Benchmark toggles
          Row(
            children: [
              _buildToggleButton(
                label: '시장',
                active: _showAssetAvg,
                onTap: () {
                  setState(() => _showAssetAvg = !_showAssetAvg);
                  _drawCtrl.forward(from: 0);
                },
                tc: tc,
              ),
              const SizedBox(width: 6),
              _buildToggleButton(
                label: '연 기대수익률',
                active: _showExpectedReturn,
                onTap: () {
                  setState(() => _showExpectedReturn = !_showExpectedReturn);
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
                          if (lines.isEmpty || lines[0].points.isEmpty) {
                            return;
                          }
                          final x = d.localPosition.dx - 28;
                          final chartW = constraints.maxWidth - 28 - 12;
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
    const padL = 28.0;
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
      final pathPoints = _interpolatedPathPoints(
        n: count,
        progress: progress,
        xAt: (i) => padL + w * i / (count - 1),
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
      old.lines != lines ||
      old.progress != progress ||
      old.touchIndex != touchIndex;
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
