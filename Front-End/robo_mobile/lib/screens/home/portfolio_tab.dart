import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../models/mock_earnings_data.dart';
import '../../models/rebalance_data.dart';
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
  int? _expandedEvent;

  // Card 2 API data (volatility-history)
  bool _isLoadingHistory = false;
  InvestmentType? _loadedHistoryType;
  List<ChartPoint>? _volatilityPoints;

  // Card 7 backtest fetch guard
  bool _backtestFetched = false;

  // Rebalance simulation API data (falls back to mock)
  List<MobileRebalanceEvent>? _apiRebalanceEvents;
  bool _rebalanceFetched = false;

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
    if (!_rebalanceFetched) {
      _fetchRebalanceSimulation();
    }
  }

  Future<void> _fetchBacktest() async {
    _backtestFetched = true;
    try {
      final bt = await MobileBackendApi.instance.fetchComparisonBacktest();
      if (!mounted) return;
      PortfolioStateProvider.of(context).setBacktest(bt);
    } catch (_) {}
  }

  Future<void> _fetchRebalanceSimulation() async {
    if (_rebalanceFetched) return;
    _rebalanceFetched = true;
    try {
      final state = PortfolioStateProvider.of(context);
      final portfolio = state.selectedPortfolio;
      if (portfolio == null) return;
      final weights = <String, double>{};
      for (final s in portfolio.stockAllocations) {
        weights[s.ticker] = s.weight;
      }
      final result = await MobileBackendApi.instance.fetchRebalanceSimulation(
        weights: weights,
        startDate: '2025-03-03',
      );
      if (!mounted) return;
      setState(() => _apiRebalanceEvents = result.rebalanceEvents);
    } catch (_) {
      // Endpoint not deployed yet, mock data used as fallback
    }
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
    final horizon = rec?.resolvedProfile.investmentHorizon ?? 'medium';
    final riskProfile = state.frontierSelection != null &&
            state.frontierSelection!.representativeCode == type.riskCode
        ? state.frontierSelection!.representativeCode!
        : portfolio?.code ?? type.riskCode;

    List<ChartPoint>? volPoints;

    try {
      final volResponse =
          await MobileBackendApi.instance.fetchVolatilityHistory(
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
    final rebalanceEvents = MockRebalanceData.eventsFor(type);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('내 포트폴리오', style: WeRoboTypography.heading2.themed(context)),
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

            // Return contribution analysis
            _ContributionSection(
              riskCode: type.riskCode,
            ),
            const SizedBox(height: 20),

            // Auto-rebalancing explanation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WeRoboColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high_rounded,
                          size: 18, color: WeRoboColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '자동 리밸런싱',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WeRobo는 분기마다 포트폴리오를 자동으로 점검합니다. '
                    '자산 비중이 목표에서 10% 이상 벗어나면 '
                    '자동으로 조정해서 위험을 관리합니다.',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rebalancing history
            Text('리밸런싱 기록', style: WeRoboTypography.heading3.themed(context)),
            const SizedBox(height: 12),
            ...rebalanceEvents.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              return _RebalanceEventCard(
                event: event,
                isExpanded: _expandedEvent == i,
                onTap: () => setState(
                    () => _expandedEvent = _expandedEvent == i ? null : i),
              );
            }),
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

  // Market-relative risk score: 0-100 scale
  // max_market_vol = 0.20 (20% annualized, aggressive equity)
  static const double _maxMarketVol = 0.20;

  int _riskScore(double volatility) =>
      ((volatility / _maxMarketVol) * 100).round().clamp(0, 100);

  String _riskLabel(int score) {
    if (score <= 33) return '낮음';
    if (score <= 66) return '보통';
    return '높음';
  }

  Color _riskColor(int score, WeRoboThemeColors tc) {
    if (score <= 33) return tc.accent;
    if (score <= 66) return WeRoboColors.warning;
    return WeRoboColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final p = portfolio;
    if (p == null) return const SizedBox.shrink();

    final score = _riskScore(p.volatility);
    final riskLabel = _riskLabel(score);
    final riskColor = _riskColor(score, tc);

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
            label: '시장 대비 위험도',
            value: '$score',
            subtitle: riskLabel,
            valueColor: riskColor,
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
  final String? subtitle;
  final Color valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    this.subtitle,
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
          if (subtitle != null)
            Text(
              subtitle!,
              style: WeRoboTypography.caption.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.category.name,
                            style: WeRoboTypography.bodySmall
                                .copyWith(color: tc.textPrimary)),
                        if (d.tickers.isNotEmpty)
                          Text(
                            d.tickers.map((t) => t.symbol).join(', '),
                            style: WeRoboTypography.caption.themed(context),
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
        style: WeRoboTypography.heading3.copyWith(color: tc.textPrimary),
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
          style: WeRoboTypography.number.copyWith(color: tc.textPrimary),
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
    if (isLoading && volatilityPoints == null && comparisonLines.isEmpty) {
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
        comparisonLines: comparisonLines.isNotEmpty ? comparisonLines : null,
        rebalanceDates: rebalanceDates.isNotEmpty ? rebalanceDates : null,
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
    final futureDates = rebalanceDates.where((d) => d.isAfter(now)).toList()
      ..sort();
    if (futureDates.isEmpty) return const SizedBox.shrink();

    final next = futureDates.first;
    final daysLeft = next.difference(now).inDays;
    final dateStr = '${next.year}-${next.month.toString().padLeft(2, '0')}'
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
                Text(dateStr,
                    style: WeRoboTypography.bodySmall.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFamily: WeRoboFonts.english)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$daysLeft일',
                style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Contribution analysis section ──

class _ContributionSection extends StatelessWidget {
  final String riskCode;

  const _ContributionSection({required this.riskCode});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final summary = MockEarningsData.summaryFor(riskCode);
    final commentary = MockEarningsData.commentaryFor(riskCode);
    final totalPct = MockEarningsData.totalReturnPctFor(riskCode);
    final sorted = [...summary]
      ..sort((a, b) => b.earnings.compareTo(a.earnings));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('수익 기여 분석', style: WeRoboTypography.heading3.themed(context)),
        const SizedBox(height: 8),
        // Commentary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tc.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            commentary,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Per-asset bars
        ...sorted.map((a) {
          final isPositive = a.earnings >= 0;
          final color = isPositive ? tc.accent : WeRoboColors.error;
          final maxEarnings = sorted.first.earnings.abs();
          final barFraction =
              maxEarnings > 0 ? (a.earnings.abs() / maxEarnings) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.assetName,
                          style: WeRoboTypography.caption.copyWith(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}'
                        '${a.returnPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontFamily: WeRoboFonts.english,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isPositive ? '+' : ''}'
                        '₩${_formatAmount(a.earnings)}',
                        style: TextStyle(
                          fontFamily: WeRoboFonts.english,
                          fontSize: 11,
                          color: tc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: barFraction.clamp(0.0, 1.0),
                        backgroundColor: tc.border.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  static String _formatAmount(double amount) {
    final abs = amount.abs().round();
    final str = abs.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ── Rebalance event card (expandable) ──

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
        '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}'
        '-${event.date.day.toString().padLeft(2, '0')}';

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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tc.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_rounded, size: 20, color: tc.accent),
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
                          style: WeRoboTypography.caption.themed(context)),
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
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetail(tc),
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

  Widget _buildDetail(WeRoboThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AllocationBar(
              label: '변경 전', changes: event.changes, useBefore: true),
          const SizedBox(height: 6),
          _AllocationBar(
              label: '변경 후', changes: event.changes, useBefore: false),
          const SizedBox(height: 14),
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
                        style: WeRoboTypography.caption
                            .copyWith(color: tc.textPrimary)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPositive ? tc.accent : WeRoboColors.warning)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}'
                      '${change.delta.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: WeRoboFonts.english,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? tc.accent : WeRoboColors.warning,
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
            style: WeRoboTypography.caption.copyWith(color: tc.textSecondary)),
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
                    color:
                        change.color.withValues(alpha: useBefore ? 0.5 : 1.0),
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? WeRoboColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.label,
                  textAlign: TextAlign.center,
                  style: WeRoboTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active ? WeRoboColors.white : tc.textTertiary,
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
