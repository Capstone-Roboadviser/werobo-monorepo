import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/chart_data.dart';
import '../../../models/portfolio_data.dart';
import '../../../services/mock_chart_data.dart';
import '../../home/widgets/chart_painters.dart';

// ── Main chart widget ──

class PortfolioCharts extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartPoint>? performancePoints;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;
  final bool useFallbackMock;

  const PortfolioCharts({
    super.key,
    required this.type,
    this.volatilityPoints,
    this.performancePoints,
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
                  label: '변동성/성과 추이',
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
                    performancePoints: widget.performancePoints,
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

// ── View 1: 변동성/성과 추이 ──

class _VolReturnView extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartPoint>? performancePoints;
  final bool useFallbackMock;

  const _VolReturnView({
    super.key,
    required this.type,
    this.volatilityPoints,
    this.performancePoints,
    required this.useFallbackMock,
  });

  @override
  State<_VolReturnView> createState() => _VolReturnViewState();
}

class _VolReturnViewState extends State<_VolReturnView>
    with SingleTickerProviderStateMixin {
  int _subTab = 0; // 0=변동성, 1=성과
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

  List<ChartPoint> get _points {
    final backendPoints =
        _subTab == 0 ? widget.volatilityPoints : widget.performancePoints;
    final all = backendPoints ??
        (widget.useFallbackMock
            ? (_subTab == 0
                ? MockChartData.volatilityHistory(widget.type)
                : MockChartData.returnHistory(widget.type))
            : const <ChartPoint>[]);
    if (all.isEmpty) {
      return const <ChartPoint>[];
    }
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    final filtered = all.where((p) => p.date.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  double _expectedVolatility() {
    return widget.type == InvestmentType.safe
        ? 0.084
        : widget.type == InvestmentType.balanced
            ? 0.108
            : 0.137;
  }

  double _expectedReturn() {
    return widget.type == InvestmentType.safe
        ? 0.062
        : widget.type == InvestmentType.balanced
            ? 0.085
            : 0.112;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final points = _points;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Sub-toggle: 변동성 / 성과
          Row(
            children: [
              _SubTab(
                  label: '변동성',
                  active: _subTab == 0,
                  onTap: () {
                    setState(() => _subTab = 0);
                    _drawCtrl.forward(from: 0);
                  }),
              const SizedBox(width: 8),
              _SubTab(
                  label: '성과',
                  active: _subTab == 1,
                  onTap: () {
                    setState(() => _subTab = 1);
                    _drawCtrl.forward(from: 0);
                  }),
              const Spacer(),
              // Time range chips
              ...List.generate(_rangeLabels.length, (i) {
                final active = _range == i;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _range = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            active ? WeRoboColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _rangeLabels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? WeRoboColors.white
                              : tc.textTertiary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Chart
          Expanded(
            child: points.isEmpty
                ? const EmptyChartState(
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
                              painter: AreaChartPainter(
                                points: points,
                                progress: _drawCtrl.value,
                                color: _subTab == 0
                                    ? WeRoboColors.primary
                                    : tc.accent,
                                touchIndex: _touchIndex,
                                valueLabel: _subTab == 0 ? '변동성' : '성과',
                                baselineValue: _subTab == 0
                                    ? _expectedVolatility()
                                    : _expectedReturn(),
                                baselineLabel:
                                    _subTab == 0 ? '기대 변동성' : '기대 수익률',
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

class _SubTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SubTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? WeRoboColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? WeRoboColors.primary : tc.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: WeRoboTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: active ? WeRoboColors.primary : tc.textTertiary,
          ),
        ),
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
  late InvestmentType _selectedType;
  bool _showBenchmark = true;

  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체'];
  static const _rangeDays = [7, 90, 365, 1825, 99999];
  static const _portfolioKeys = {
    'conservative',
    'balanced',
    'growth',
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type;
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

  /// Build a 7-asset simple-average benchmark line from all
  /// portfolio lines (approximation until backend provides it).
  ChartLine? _buildBenchmarkLine(List<ChartLine> rawLines) {
    final portfolioLines = rawLines
        .where((l) => _portfolioKeys.contains(l.key))
        .toList();
    if (portfolioLines.isEmpty) return null;
    final minLen = portfolioLines
        .map((l) => l.points.length)
        .reduce(min);
    if (minLen < 2) return null;

    final avgPoints = <ChartPoint>[];
    for (int i = 0; i < minLen; i++) {
      double sum = 0;
      for (final line in portfolioLines) {
        sum += line.points[i].value;
      }
      avgPoints.add(ChartPoint(
        date: portfolioLines.first.points[i].date,
        value: sum / portfolioLines.length,
      ));
    }
    return ChartLine(
      key: 'benchmark_avg',
      label: '7자산 단순평균',
      color: const Color(0xFF999999),
      dashed: true,
      points: avgPoints,
    );
  }

  List<ChartLine> _filterByType(List<ChartLine> rawLines) {
    final code = _selectedType.riskCode;
    final result = <ChartLine>[];

    // Selected portfolio line
    for (final line in rawLines) {
      if (line.key == code) {
        result.add(line);
        break;
      }
    }

    // Benchmark (toggle-controlled)
    if (_showBenchmark) {
      final bench = _buildBenchmarkLine(rawLines);
      if (bench != null) result.add(bench);
    }

    return result;
  }

  List<ChartLine> _filterByRange(List<ChartLine> rawLines) {
    final cutoff =
        DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    return rawLines.map((line) {
      final filtered =
          line.points.where((p) => p.date.isAfter(cutoff)).toList();
      return ChartLine(
        key: line.key,
        label: line.label,
        color: line.color,
        dashed: line.dashed,
        points: filtered.isNotEmpty ? filtered : line.points,
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
    final typedLines =
        allLines.isEmpty ? allLines : _filterByType(allLines);
    final lines =
        typedLines.isEmpty ? typedLines : _filterByRange(typedLines);
    final rebalanceDates = widget.rebalanceDates ??
        (widget.useFallbackMock
            ? MockChartData.rebalanceDates
            : const <DateTime>[]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Portfolio type selector + benchmark toggle
          Row(
            children: [
              ...InvestmentType.values.map((t) {
                final active = _selectedType == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedType = t);
                      _drawCtrl.forward(from: 0);
                    },
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? WeRoboColors.primary
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                          color: active
                              ? WeRoboColors.primary
                              : tc.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        t.label,
                        style:
                            WeRoboTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: active
                              ? WeRoboColors.white
                              : tc.textTertiary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(
                      () => _showBenchmark = !_showBenchmark);
                  _drawCtrl.forward(from: 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showBenchmark
                        ? const Color(0xFF999999)
                            .withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showBenchmark
                          ? const Color(0xFF999999)
                          : tc.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '벤치마크',
                    style: WeRoboTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: _showBenchmark
                          ? tc.textPrimary
                          : tc.textTertiary,
                    ),
                  ),
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? WeRoboColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _rangeLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? WeRoboColors.white
                            : tc.textTertiary,
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
                ? const EmptyChartState(
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
                              painter: MultiLineChartPainter(
                                lines: lines,
                                progress: _drawCtrl.value,
                                rebalanceDates: rebalanceDates,
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

// Painters (AreaChartPainter, MultiLineChartPainter) and EmptyChartState
// are imported from ../../home/widgets/chart_painters.dart
