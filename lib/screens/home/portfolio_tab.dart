import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../models/rebalance_data.dart';
import '../../services/mobile_backend_api.dart';
import '../../services/mock_chart_data.dart';
import '../onboarding/widgets/portfolio_charts.dart';
import '../onboarding/widgets/vestor_pie_chart.dart';

class PortfolioTab extends StatefulWidget {
  const PortfolioTab({super.key});

  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  int _viewTab = 0; // 0 = 비중, 1 = 성과 추이
  int? _selectedSector;
  int? _expandedEvent;

  bool _isLoadingCharts = true;
  String? _chartError;
  List<ChartLine>? _comparisonLines;
  List<DateTime>? _rebalanceDates;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoadingCharts = true;
      _chartError = null;
    });

    try {
      final backtest =
          await MobileBackendApi.instance.fetchComparisonBacktest();
      if (!mounted) return;

      setState(() {
        _isLoadingCharts = false;
        _rebalanceDates = backtest.rebalanceDates;
        _comparisonLines = backtest.lines
            .map((line) => ChartLine(
                  key: line.key,
                  label: line.label,
                  color: parseBackendHexColor(line.color),
                  dashed: line.style != 'solid',
                  points: line.points
                      .map((p) =>
                          ChartPoint(date: p.date, value: p.returnPct))
                      .toList(),
                ))
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingCharts = false;
        _chartError = error is MobileBackendException
            ? error.message
            : '차트 데이터를 불러오지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final type = PortfolioStateProvider.of(context).type;
    final categories = PortfolioData.categoriesFor(type);
    final details = PortfolioData.detailsFor(type);
    final rebalanceEvents = MockRebalanceData.eventsFor(type);

    // Prepend promised return line to comparison data
    final lines = _comparisonLines != null
        ? [MockChartData.promisedReturnLine(type), ..._comparisonLines!]
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('내 포트폴리오',
                style: WeRoboTypography.heading2.themed(context)),
            const SizedBox(height: 16),

            // View toggle
            Container(
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _ToggleChip(
                    label: '비중',
                    isActive: _viewTab == 0,
                    onTap: () => setState(() => _viewTab = 0),
                  ),
                  _ToggleChip(
                    label: '성과 추이',
                    isActive: _viewTab == 1,
                    onTap: () => setState(() => _viewTab = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _viewTab == 0
                  ? _AllocationView(
                      key: const ValueKey('alloc'),
                      categories: categories,
                      details: details,
                      selectedSector: _selectedSector,
                      onSectorSelected: (idx) =>
                          setState(() => _selectedSector = idx),
                    )
                  : _TrendView(
                      key: const ValueKey('trend'),
                      type: type,
                      isLoading: _isLoadingCharts,
                      chartError: _chartError,
                      comparisonLines: lines,
                      rebalanceDates: _rebalanceDates,
                      onRetry: _loadChartData,
                    ),
            ),
            const SizedBox(height: 28),

            // Next rebalance card
            _NextRebalanceCard(),
            const SizedBox(height: 20),

            // Rebalancing history
            Text('리밸런싱 기록',
                style: WeRoboTypography.heading3.themed(context)),
            const SizedBox(height: 12),
            ...rebalanceEvents.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              return _RebalanceEventCard(
                event: event,
                isExpanded: _expandedEvent == i,
                onTap: () => setState(() =>
                    _expandedEvent = _expandedEvent == i ? null : i),
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Toggle chip ──

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

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
              color:
                  isActive ? WeRoboColors.white : tc.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Allocation view (pie + sector list) ──

class _AllocationView extends StatelessWidget {
  final List<PortfolioCategory> categories;
  final List<PortfolioCategoryDetail> details;
  final int? selectedSector;
  final ValueChanged<int?> onSectorSelected;

  const _AllocationView({
    super.key,
    required this.categories,
    required this.details,
    required this.selectedSector,
    required this.onSectorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        Center(
          child: VestorPieChart(
            categories: categories,
            size: 220,
            ringWidth: 26,
            selectedRingWidth: 32,
            onSectorSelected: onSectorSelected,
            centerBuilder: (_) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCenter(context),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...details.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: d.category.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.category.name,
                            style: WeRoboTypography.bodySmall.copyWith(
                                color: tc.textPrimary)),
                        if (d.tickers.isNotEmpty)
                          Text(
                            d.tickers
                                .map((t) => t.symbol)
                                .join(', '),
                            style: WeRoboTypography.caption
                                .themed(context),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${d.category.percentage.toInt()}%',
                    style: WeRoboTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildCenter(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    if (selectedSector == null || selectedSector! >= details.length) {
      return Text(
        key: const ValueKey('default'),
        '포트폴리오\n비중',
        style: WeRoboTypography.heading3
            .copyWith(color: tc.textPrimary),
        textAlign: TextAlign.center,
      );
    }

    final detail = details[selectedSector!];
    return Column(
      key: ValueKey('sector_$selectedSector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          detail.category.name,
          style: WeRoboTypography.caption.copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${detail.category.percentage.toInt()}%',
          style: WeRoboTypography.number
              .copyWith(color: tc.textPrimary),
        ),
        const SizedBox(height: 4),
        ...detail.tickers.take(3).map((t) => Text(
              '${t.symbol} ${t.percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: tc.textSecondary,
                height: 1.3,
              ),
            )),
      ],
    );
  }
}

// ── Trend view (line chart with benchmarks) ──

class _TrendView extends StatelessWidget {
  final InvestmentType type;
  final bool isLoading;
  final String? chartError;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;
  final VoidCallback onRetry;

  const _TrendView({
    super.key,
    required this.type,
    required this.isLoading,
    this.chartError,
    this.comparisonLines,
    this.rebalanceDates,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(color: WeRoboColors.primary),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: PortfolioCharts(
        type: type,
        comparisonLines: comparisonLines,
        rebalanceDates: rebalanceDates,
        useFallbackMock: true,
      ),
    );
  }
}

// ── Next rebalance card ──

class _NextRebalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WeRoboColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_rounded,
                size: 20, color: WeRoboColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('다음 리밸런싱',
                    style: WeRoboTypography.caption
                        .copyWith(color: WeRoboColors.primary)),
                Text('2026-07-01',
                    style: WeRoboTypography.bodySmall.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFamily: WeRoboFonts.english)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('87일',
                style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Rebalance event card ──

class _RebalanceEventCard extends StatelessWidget {
  final RebalanceEvent event;
  final bool isExpanded;
  final VoidCallback onTap;

  const _RebalanceEventCard({
    required this.event,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final dateStr =
        '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header row (always visible)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tc.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 20, color: tc.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr,
                          style: WeRoboTypography.bodySmall.copyWith(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontFamily: WeRoboFonts.english)),
                      Text(event.status,
                          style: WeRoboTypography.caption
                              .themed(context)),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: tc.textTertiary,
                ),
              ],
            ),

            // Expanded detail
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetail(context),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Before/after stacked bars
          _AllocationBar(
              label: '변경 전',
              changes: event.changes,
              useBefore: true),
          const SizedBox(height: 6),
          _AllocationBar(
              label: '변경 후',
              changes: event.changes,
              useBefore: false),
          const SizedBox(height: 14),

          // Per-sector change rows
          ...event.changes.map((change) {
            final isPositive = change.delta >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: change.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(change.sectorName,
                        style: WeRoboTypography.caption.copyWith(
                            color: tc.textPrimary)),
                  ),
                  Text(
                    '${change.beforePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontFamily: WeRoboFonts.english,
                      fontSize: 11,
                      color: tc.textSecondary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 12, color: tc.textTertiary),
                  ),
                  Text(
                    '${change.afterPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontFamily: WeRoboFonts.english,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPositive
                              ? tc.accent
                              : WeRoboColors.warning)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}${change.delta.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: WeRoboFonts.english,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? tc.accent
                            : WeRoboColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Horizontal stacked allocation bar ──

class _AllocationBar extends StatelessWidget {
  final String label;
  final List<AllocationChange> changes;
  final bool useBefore;

  const _AllocationBar({
    required this.label,
    required this.changes,
    required this.useBefore,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: WeRoboTypography.caption
                .copyWith(color: tc.textSecondary)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 16,
            child: Row(
              children: changes.map((change) {
                final pct = useBefore ? change.beforePct : change.afterPct;
                return Flexible(
                  flex: (pct * 10).round().clamp(1, 1000),
                  child: Container(
                    color: change.color
                        .withValues(alpha: useBefore ? 0.5 : 1.0),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
