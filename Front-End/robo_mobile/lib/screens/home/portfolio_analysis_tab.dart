import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../onboarding/widgets/vestor_pie_chart.dart';
import 'portfolio_allocation_detail_page.dart';
import 'portfolio_tab.dart' show buildHomePortfolioComparisonLines;

class PortfolioAnalysisTab extends StatefulWidget {
  const PortfolioAnalysisTab({super.key});

  @override
  State<PortfolioAnalysisTab> createState() => _PortfolioAnalysisTabState();
}

class _PortfolioAnalysisTabState extends State<PortfolioAnalysisTab> {
  int _selectedTab = 1;

  @override
  Widget build(BuildContext context) {
    final state = PortfolioStateProvider.of(context);
    final tc = WeRoboThemeColors.of(context);
    final tabs = ['요약', '자산배분', '성과', '보유자산'];

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnalysisHeader(
              onBack: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 18),
            _AnalysisTabBar(
              tabs: tabs,
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: WeRoboMotion.short,
              child: switch (_selectedTab) {
                0 => _AnalysisSummaryPage(
                    key: const ValueKey('summary'),
                    state: state,
                  ),
                1 => _AssetAllocationAnalysisPage(
                    key: const ValueKey('allocation'),
                    state: state,
                  ),
                2 => _PerformanceAnalysisPage(
                    key: const ValueKey('performance'),
                    state: state,
                  ),
                _ => _HoldingsAnalysisPage(
                    key: const ValueKey('holdings'),
                    state: state,
                  ),
              },
            ),
            const SizedBox(height: 8),
            Text(
              '포트폴리오 데이터는 시장 상황과 계정 동기화 상태에 따라 달라질 수 있어요.',
              style: WeRoboTypography.caption.copyWith(
                color: tc.textTertiary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _AnalysisHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      children: [
        Pressable(
          onTap: onBack,
          child: Icon(
            Icons.chevron_left_rounded,
            size: 32,
            color: tc.textPrimary,
          ),
        ),
        Expanded(
          child: Text(
            '포트폴리오 분석',
            textAlign: TextAlign.center,
            style: WeRoboTypography.heading3.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Pressable(
          onTap: () {},
          child: Icon(
            Icons.ios_share_rounded,
            size: 24,
            color: tc.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AnalysisTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _AnalysisTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tc.border.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: WeRoboMotion.short,
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedIndex == i
                            ? WeRoboColors.primary
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: selectedIndex == i
                          ? WeRoboColors.primary
                          : tc.textSecondary,
                      fontWeight: selectedIndex == i
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssetAllocationAnalysisPage extends StatelessWidget {
  final PortfolioState state;

  const _AssetAllocationAnalysisPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final categories = _analysisCategories(state);
    return Column(
      children: [
        _AllocationOverviewCard(
          categories: categories,
          totalValue: _analysisTotalValue(state),
        ),
        const SizedBox(height: 12),
        _MetricGrid(state: state),
        const SizedBox(height: 12),
        _PerformanceTrendCard(
          title: '성과 추이',
          lines: _analysisPerformanceLines(state),
        ),
      ],
    );
  }
}

class _AnalysisSummaryPage extends StatelessWidget {
  final PortfolioState state;

  const _AnalysisSummaryPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final totalValue = _analysisTotalValue(state);
    final summary = state.accountSummary;
    final profit = summary?.profitLoss ?? 1250000;
    final profitPct = summary?.profitLossPct ?? 0.0109;
    final isGain = profit >= 0;

    return Column(
      children: [
        _AnalysisCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '요약',
                style: WeRoboTypography.heading3.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      label: '총 자산',
                      value: '${_formatWon(totalValue)}원',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMetric(
                      label: '누적 손익',
                      value: '${isGain ? '+' : '-'}'
                          '${_formatWon(profit.abs())}원',
                      valueColor: isGain ? tc.accent : WeRoboColors.lossBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '현재 포트폴리오는 ${(profitPct.abs() * 100).toStringAsFixed(2)}% '
                '${isGain ? '수익 구간' : '손실 구간'}에 있어요. 자산배분 탭에서 비중과 성과 흐름을 함께 볼 수 있어요.',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PerformanceTrendCard(
          title: '최근 성과',
          lines: _analysisPerformanceLines(state),
        ),
      ],
    );
  }
}

class _PerformanceAnalysisPage extends StatelessWidget {
  final PortfolioState state;

  const _PerformanceAnalysisPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricGrid(state: state),
        const SizedBox(height: 12),
        _PerformanceTrendCard(
          title: '성과 추이',
          lines: _analysisPerformanceLines(state),
          large: true,
        ),
      ],
    );
  }
}

class _HoldingsAnalysisPage extends StatelessWidget {
  final PortfolioState state;

  const _HoldingsAnalysisPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final details = _analysisDetails(state);
    final baseValue = _analysisTotalValue(state);
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '보유자산',
            style: WeRoboTypography.heading3.copyWith(
              color: WeRoboThemeColors.of(context).textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final detail in details)
            _HoldingRow(
              detail: detail,
              baseValue: baseValue,
            ),
        ],
      ),
    );
  }
}

class _AllocationOverviewCard extends StatelessWidget {
  final List<PortfolioCategory> categories;
  final double totalValue;

  const _AllocationOverviewCard({
    required this.categories,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자산 배분 현황',
            style: WeRoboTypography.body.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 320;
              final chartSize = isCompact ? 174.0 : 190.0;
              final chart = SizedBox(
                width: chartSize,
                height: chartSize,
                child: VestorPieChart(
                  categories: categories,
                  size: chartSize,
                  ringWidth: 30,
                  selectedRingWidth: 34,
                  centerBuilder: (_) => Text(
                    '총 자산\n${_formatWon(totalValue)}원',
                    textAlign: TextAlign.center,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                ),
              );
              final legend = _AllocationLegend(categories: categories);
              if (isCompact) {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 16),
                    legend,
                  ],
                );
              }
              return Row(
                children: [
                  chart,
                  const SizedBox(width: 18),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AllocationLegend extends StatelessWidget {
  final List<PortfolioCategory> categories;

  const _AllocationLegend({required this.categories});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        for (final category in categories.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${category.percentage.toStringAsFixed(1)}%',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final PortfolioState state;

  const _MetricGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final portfolio = state.selectedPortfolio;
    final summary = state.accountSummary;
    final annualReturn = portfolio?.expectedReturn ?? summary?.expectedReturn;
    final volatility = portfolio?.volatility ?? summary?.volatility;
    final sharpe = portfolio?.sharpeRatio ?? summary?.sharpeRatio;
    final score = _investorScore(volatility ?? 0.1123);
    final metrics = [
      _MetricData(
        label: '수익률 (연환산)',
        value: '+${((annualReturn ?? 0.1245) * 100).toStringAsFixed(2)}%',
        color: WeRoboColors.primary,
      ),
      _MetricData(
        label: '변동성',
        value: '${((volatility ?? 0.1123) * 100).toStringAsFixed(2)}%',
      ),
      _MetricData(
        label: '샤프지수',
        value: (sharpe ?? 1.21).toStringAsFixed(2),
      ),
      _MetricData(
        label: '분산투자 점수',
        value: '$score/100',
        color: WeRoboColors.primary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 2 : 4;
        final useTwoColumns = constraints.maxWidth < 430;
        final resolvedColumns = useTwoColumns ? 2 : columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: resolvedColumns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: resolvedColumns == 2 ? 106 : 118,
          ),
          itemBuilder: (context, index) => _MetricCard(data: metrics[index]),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border.withValues(alpha: 0.42)),
        boxShadow: WeRoboElevation.subtle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.value,
              style: WeRoboTypography.body.copyWith(
                color: data.color ?? tc.textPrimary,
                fontWeight: FontWeight.w900,
                fontFamily: WeRoboFonts.english,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final Color? color;

  const _MetricData({
    required this.label,
    required this.value,
    this.color,
  });
}

class _PerformanceTrendCard extends StatelessWidget {
  final String title;
  final List<ChartLine> lines;
  final bool large;

  const _PerformanceTrendCard({
    required this.title,
    required this.lines,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return _AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: WeRoboTypography.body.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '최근 1년',
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: tc.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PerformanceLegend(lines: lines),
          const SizedBox(height: 10),
          SizedBox(
            height: large ? 240 : 188,
            child: CustomPaint(
              painter: _AnalysisLineChartPainter(
                lines: lines,
                gridColor: tc.border.withValues(alpha: 0.55),
                labelColor: tc.textTertiary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceLegend extends StatelessWidget {
  final List<ChartLine> lines;

  const _PerformanceLegend({required this.lines});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 8,
      spacing: 18,
      children: [
        for (final line in lines.take(2))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: line.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                line.label,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeRoboColors.primaryLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: WeRoboTypography.bodySmall.copyWith(
              color: valueColor ?? tc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final PortfolioCategoryDetail detail;
  final double baseValue;

  const _HoldingRow({
    required this.detail,
    required this.baseValue,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final amount = baseValue * detail.category.percentage / 100;
    return Pressable(
      onTap: () => Navigator.push(
        context,
        WeRoboMotion.fadeRoute<void>(
          PortfolioAllocationDetailPage(
            detail: detail,
            baseValue: baseValue,
            initialShowAmounts: true,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: detail.category.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.category.name,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail.tickers.map((t) => t.symbol).take(3).join(', '),
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${detail.category.percentage.toStringAsFixed(1)}%',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${_formatWon(amount)}원',
                  style: WeRoboTypography.caption.copyWith(
                    color: tc.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final Widget child;

  const _AnalysisCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border.withValues(alpha: 0.45)),
        boxShadow: WeRoboElevation.subtle,
      ),
      child: child,
    );
  }
}

class _AnalysisLineChartPainter extends CustomPainter {
  final List<ChartLine> lines;
  final Color gridColor;
  final Color labelColor;

  const _AnalysisLineChartPainter({
    required this.lines,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 8.0;
    const right = 8.0;
    const bottom = 26.0;
    final rect =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (rect.width <= 0 || rect.height <= 0) return;

    final allPoints = lines.expand((line) => line.points).toList();
    if (allPoints.length < 2) return;

    final minDate =
        allPoints.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate =
        allPoints.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
    var minValue = allPoints.map((p) => p.value).reduce(math.min);
    var maxValue = allPoints.map((p) => p.value).reduce(math.max);
    minValue = math.min(minValue, -0.10);
    maxValue = math.max(maxValue, 0.20);
    final valueSpan =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;
    final dateSpan = maxDate.difference(minDate).inMilliseconds;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final value in const [-0.10, 0.0, 0.10, 0.20]) {
      final y = rect.bottom - ((value - minValue) / valueSpan) * rect.height;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      textPainter.text = TextSpan(
        text: '${(value * 100).round()}%',
        style: TextStyle(
          color: labelColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    for (final line in lines) {
      if (line.points.length < 2) continue;
      final path = Path();
      for (var i = 0; i < line.points.length; i++) {
        final point = line.points[i];
        final xFactor = dateSpan <= 0
            ? i / (line.points.length - 1)
            : point.date.difference(minDate).inMilliseconds / dateSpan;
        final yFactor = (point.value - minValue) / valueSpan;
        final offset = Offset(
          rect.left + xFactor * rect.width,
          rect.bottom - yFactor * rect.height,
        );
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.key == 'portfolio' ? 3 : 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }

    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final dates = [
      minDate,
      minDate.add(Duration(milliseconds: (dateSpan * 0.33).round())),
      minDate.add(Duration(milliseconds: (dateSpan * 0.66).round())),
      maxDate,
    ];
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      final x = rect.left + (i / (dates.length - 1)) * rect.width;
      labelPaint.text = TextSpan(
        text:
            "'${date.year.toString().substring(2)}.${date.month.toString().padLeft(2, '0')}",
        style: TextStyle(
          color: labelColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(
            (x - labelPaint.width / 2)
                .clamp(rect.left, rect.right - labelPaint.width),
            rect.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnalysisLineChartPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

List<PortfolioCategory> _analysisCategories(PortfolioState state) {
  final categories = state.categories;
  if (categories.isNotEmpty) return categories.take(4).toList();
  final source = state.accountSummary?.sectorAllocations ??
      const <MobileSectorAllocation>[];
  if (source.isNotEmpty) {
    final colors = [
      WeRoboColors.primary,
      const Color(0xFF4EB9A9),
      const Color(0xFFFFA51F),
      const Color(0xFF7693B8),
    ];
    return [
      for (var i = 0; i < math.min(source.length, 4); i++)
        PortfolioCategory(
          name: _friendlyAssetName(source[i].assetCode, source[i].assetName),
          percentage: source[i].weight * 100,
          color: colors[i],
        ),
    ];
  }
  return const [
    PortfolioCategory(
      name: '주식 (ETF)',
      percentage: 55,
      color: WeRoboColors.primary,
    ),
    PortfolioCategory(
      name: '채권',
      percentage: 25,
      color: Color(0xFF4EB9A9),
    ),
    PortfolioCategory(
      name: '대체투자',
      percentage: 10,
      color: Color(0xFFFFA51F),
    ),
    PortfolioCategory(
      name: '현금',
      percentage: 10,
      color: Color(0xFF7693B8),
    ),
  ];
}

List<PortfolioCategoryDetail> _analysisDetails(PortfolioState state) {
  final details = state.categoryDetails;
  if (details.isNotEmpty) return details;
  return [
    for (final category in _analysisCategories(state))
      PortfolioCategoryDetail(
        category: category,
        tickers: [
          TickerHolding(
            symbol: category.name == '현금' ? 'CASH' : 'ETF',
            name: category.name,
            percentage: category.percentage,
          ),
        ],
      ),
  ];
}

List<ChartLine> _analysisPerformanceLines(PortfolioState state) {
  final comparisonLines = buildHomePortfolioComparisonLines(state);
  final usable = comparisonLines
      .where((line) =>
          line.key == 'portfolio' ||
          line.key == 'market' ||
          line.label.contains('벤치'))
      .take(2)
      .toList();
  if (usable.length >= 2) {
    return [
      usable[0],
      ChartLine(
        key: usable[1].key,
        label: usable[1].key == 'market' ? '벤치마크' : usable[1].label,
        color: const Color(0xFFB8C1D8),
        points: usable[1].points,
      ),
    ];
  }
  final history = state.accountHistory;
  if (history.length >= 2) {
    final first = history.first.portfolioValue;
    final portfolioPoints = [
      for (final point in history)
        ChartPoint(
          date: point.date,
          value: first <= 0 ? 0 : point.portfolioValue / first - 1,
        ),
    ];
    return [
      ChartLine(
        key: 'portfolio',
        label: '나의 포트폴리오',
        color: WeRoboColors.primary,
        points: portfolioPoints,
      ),
      ChartLine(
        key: 'benchmark',
        label: '벤치마크',
        color: const Color(0xFFB8C1D8),
        points: [
          for (var i = 0; i < portfolioPoints.length; i++)
            ChartPoint(
              date: portfolioPoints[i].date,
              value: portfolioPoints[i].value * 0.62,
            ),
        ],
      ),
    ];
  }
  final now = DateTime.now();
  const mine = [
    -0.02,
    0.01,
    0.035,
    0.005,
    0.025,
    0.07,
    0.105,
    0.08,
    0.12,
    0.15,
    0.13,
    0.20
  ];
  const benchmark = [
    -0.01,
    0.006,
    0.02,
    -0.01,
    0.0,
    0.035,
    0.055,
    0.025,
    0.065,
    0.045,
    0.085,
    0.12
  ];
  return [
    ChartLine(
      key: 'portfolio',
      label: '나의 포트폴리오',
      color: WeRoboColors.primary,
      points: [
        for (var i = 0; i < mine.length; i++)
          ChartPoint(
            date: DateTime(now.year, now.month - (mine.length - 1 - i), 1),
            value: mine[i],
          ),
      ],
    ),
    ChartLine(
      key: 'benchmark',
      label: '벤치마크',
      color: const Color(0xFFB8C1D8),
      points: [
        for (var i = 0; i < benchmark.length; i++)
          ChartPoint(
            date: DateTime(now.year, now.month - (benchmark.length - 1 - i), 1),
            value: benchmark[i],
          ),
      ],
    ),
  ];
}

double _analysisTotalValue(PortfolioState state) {
  return state.accountSummary?.currentValue ?? 128250000;
}

int _investorScore(double volatility) {
  final score = 100 - ((volatility / 0.25) * 40).round();
  return score.clamp(60, 96);
}

String _friendlyAssetName(String code, String fallback) {
  final normalized = code.toLowerCase();
  if (normalized.contains('bond')) return '채권';
  if (normalized.contains('cash')) return '현금';
  if (normalized.contains('gold') || normalized.contains('infra')) {
    return '대체투자';
  }
  if (normalized.contains('growth') || normalized.contains('value')) {
    return '주식 (ETF)';
  }
  return fallback.isEmpty ? '기타' : fallback;
}

String _formatWon(double value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer(sign);
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
