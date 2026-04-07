import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../services/mobile_backend_api.dart';
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

  // Card 2 API data (volatility-history)
  bool _isLoadingHistory = false;
  InvestmentType? _loadedHistoryType;
  List<ChartPoint>? _volatilityPoints;

  // Card 7 backtest fetch guard
  bool _backtestFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = PortfolioStateProvider.of(context);
    final type = state.type;
    if (_loadedHistoryType != type) {
      _fetchHistoryForType(type);
    }
    if (!_backtestFetched && state.backtest == null) {
      _fetchBacktest();
    }
  }

  Future<void> _fetchBacktest() async {
    _backtestFetched = true;
    try {
      final bt = await MobileBackendApi.instance
          .fetchComparisonBacktest();
      if (!mounted) return;
      PortfolioStateProvider.of(context).setBacktest(bt);
    } catch (_) {}
  }

  Future<void> _fetchHistoryForType(InvestmentType type) async {
    if (_isLoadingHistory) return;
    setState(() {
      _isLoadingHistory = true;
      _loadedHistoryType = type;
    });

    final state = PortfolioStateProvider.of(context);
    final rec = state.recommendation;
    final portfolio = rec?.portfolioByCode(type.riskCode);
    final horizon =
        rec?.resolvedProfile.investmentHorizon ?? 'medium';
    final riskProfile = portfolio?.code ?? type.riskCode;

    List<ChartPoint>? volPoints;

    try {
      final volResponse = await MobileBackendApi.instance
          .fetchVolatilityHistory(
        riskProfile: riskProfile,
        investmentHorizon: horizon,
      );
      volPoints = volResponse.points
          .map((p) => ChartPoint(
                date: p.date,
                value: p.volatility,
              ))
          .toList();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoadingHistory = false;
      _volatilityPoints = volPoints;
    });
  }

  /// Extract performance points from comparison-backtest data
  /// for the selected portfolio type.
  List<ChartPoint>? _performancePoints() {
    final state = PortfolioStateProvider.of(context);
    final code = state.type.riskCode;
    for (final line in state.comparisonLines) {
      if (line.key == code) return line.points;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final type = portfolioState.type;
    final categories = portfolioState.categories;
    final details = portfolioState.categoryDetails;
    final lines = portfolioState.comparisonLines;
    final rebalanceDates = portfolioState.rebalanceDates;
    final pastDates = rebalanceDates
        .where((d) => d.isBefore(DateTime.now()))
        .toList()
      ..sort((a, b) => b.compareTo(a));

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
            const SizedBox(height: 12),

            // Portfolio type selector
            _PortfolioTypeSelector(
              currentType: type,
              onTypeChanged: (t) {
                PortfolioStateProvider.of(context).setType(t);
                setState(() => _selectedSector = null);
                _fetchHistoryForType(t);
              },
            ),
            const SizedBox(height: 16),

            // Risk & return summary
            _PortfolioStatsCard(
              portfolio: portfolioState.selectedPortfolio,
            ),
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
              duration: const Duration(milliseconds: 300),
              child: _viewTab == 0
                  ? _AllocationView(
                      key: ValueKey('alloc_${type.name}'),
                      categories: categories,
                      details: details,
                      selectedSector: _selectedSector,
                      onSectorSelected: (idx) =>
                          setState(() => _selectedSector = idx),
                    )
                  : _TrendView(
                      key: ValueKey('trend_${type.name}'),
                      type: type,
                      volatilityPoints: _volatilityPoints,
                      performancePoints: _performancePoints(),
                      comparisonLines: lines,
                      rebalanceDates: rebalanceDates,
                      isLoading: _isLoadingHistory,
                    ),
            ),
            const SizedBox(height: 28),

            // Next rebalance card
            _NextRebalanceCard(rebalanceDates: rebalanceDates),
            const SizedBox(height: 20),

            // Rebalancing history from API
            if (pastDates.isNotEmpty) ...[
              Text('리밸런싱 기록',
                  style: WeRoboTypography.heading3.themed(context)),
              const SizedBox(height: 12),
              ...pastDates
                  .map((date) => _RebalanceDateCard(date: date)),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Portfolio stats card ──

class _PortfolioStatsCard extends StatelessWidget {
  final MobilePortfolioRecommendation? portfolio;

  const _PortfolioStatsCard({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final p = portfolio;
    if (p == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _StatItem(
            label: '예상 수익률',
            value: p.expectedReturnLabel,
            valueColor: WeRoboColors.primary,
          ),
          _statDivider(tc),
          _StatItem(
            label: '위험도',
            value: p.volatilityLabel,
            valueColor: tc.textPrimary,
          ),
          _statDivider(tc),
          _StatItem(
            label: '샤프 비율',
            value: p.sharpeRatio.toStringAsFixed(2),
            valueColor: tc.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _statDivider(WeRoboThemeColors tc) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: tc.textTertiary.withValues(alpha: 0.2),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: WeRoboTypography.caption.themed(context),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: WeRoboTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              fontFamily: WeRoboFonts.english,
              color: valueColor,
            ),
          ),
        ],
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
            color: isActive
                ? WeRoboColors.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: WeRoboTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isActive
                  ? WeRoboColors.white
                  : tc.textTertiary,
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
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            '포트폴리오 데이터를 불러오는 중...',
            style: WeRoboTypography.bodySmall.themed(context),
          ),
        ),
      );
    }
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(d.category.name,
                            style: WeRoboTypography.bodySmall
                                .copyWith(
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
    if (selectedSector == null ||
        selectedSector! >= details.length) {
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
              '${t.symbol} '
              '${t.percentage.toStringAsFixed(1)}%',
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

// ── Trend view (card 2 + card 7 API data) ──

class _TrendView extends StatelessWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartPoint>? performancePoints;
  final List<ChartLine> comparisonLines;
  final List<DateTime> rebalanceDates;
  final bool isLoading;

  const _TrendView({
    super.key,
    required this.type,
    this.volatilityPoints,
    this.performancePoints,
    required this.comparisonLines,
    required this.rebalanceDates,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading &&
        volatilityPoints == null &&
        comparisonLines.isEmpty) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            color: WeRoboColors.primary,
          ),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: PortfolioCharts(
        type: type,
        volatilityPoints: volatilityPoints,
        performancePoints: performancePoints,
        comparisonLines:
            comparisonLines.isNotEmpty ? comparisonLines : null,
        rebalanceDates:
            rebalanceDates.isNotEmpty ? rebalanceDates : null,
        useFallbackMock: false,
      ),
    );
  }
}

// ── Next rebalance card (derived from API dates) ──

class _NextRebalanceCard extends StatelessWidget {
  final List<DateTime> rebalanceDates;

  const _NextRebalanceCard({required this.rebalanceDates});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final now = DateTime.now();
    final futureDates = rebalanceDates
        .where((d) => d.isAfter(now))
        .toList()
      ..sort();
    if (futureDates.isEmpty) return const SizedBox.shrink();

    final next = futureDates.first;
    final daysLeft = next.difference(now).inDays;
    final dateStr =
        '${next.year}-${next.month.toString().padLeft(2, '0')}'
        '-${next.day.toString().padLeft(2, '0')}';

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
              color:
                  WeRoboColors.primary.withValues(alpha: 0.15),
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
                Text(dateStr,
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
              color:
                  WeRoboColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$daysLeft일',
                style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Rebalance date card (from API backtest data) ──

class _RebalanceDateCard extends StatelessWidget {
  final DateTime date;

  const _RebalanceDateCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
                Text('리밸런싱 완료',
                    style: WeRoboTypography.caption
                        .themed(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Portfolio type selector ──

class _PortfolioTypeSelector extends StatelessWidget {
  final InvestmentType currentType;
  final ValueChanged<InvestmentType> onTypeChanged;

  const _PortfolioTypeSelector({
    required this.currentType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: InvestmentType.values.map((t) {
          final active = currentType == t;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTypeChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? WeRoboColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.label,
                  textAlign: TextAlign.center,
                  style: WeRoboTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active
                        ? WeRoboColors.white
                        : tc.textTertiary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
