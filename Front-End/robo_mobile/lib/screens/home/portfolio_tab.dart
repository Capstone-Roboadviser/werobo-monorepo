import 'package:flutter/material.dart';
import '../../app/chart_point_filters.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../services/mobile_backend_api.dart';
import '../onboarding/widgets/portfolio_charts.dart';
import '../onboarding/widgets/vestor_pie_chart.dart';
import 'portfolio_allocation_detail_page.dart';

List<ChartLine> buildHomePortfolioComparisonLines(
  PortfolioState portfolioState,
) {
  final portfolioStartedAt =
      DateTime.tryParse(portfolioState.accountSummary?.startedAt ?? '');
  return filterChartLinesFromStartDate(
    portfolioState.comparisonLines,
    startDate: portfolioStartedAt,
    rebaseToZero: true,
  );
}

List<DateTime> buildHomePortfolioRebalanceDates(
  PortfolioState portfolioState,
) {
  final portfolioStartedAt =
      DateTime.tryParse(portfolioState.accountSummary?.startedAt ?? '');
  return filterDatesFromStartDate(
    portfolioState.rebalanceDates,
    startDate: portfolioStartedAt,
  );
}

class PortfolioTab extends StatefulWidget {
  /// Optional widget rendered at the very top of the scroll view, above the
  /// portfolio stats card. Used by `PortfolioWeightsPage` to inject a
  /// strategy-message pill that scrolls with the rest of the content.
  final Widget? leading;

  const PortfolioTab({super.key, this.leading});

  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  int _viewTab = 0; // 0 = 비중, 1 = 성과 추이
  int? _selectedSector;
  bool _showAllocationAmounts = false;

  // Card 2 API data (volatility-history)
  bool _isLoadingHistory = false;
  InvestmentType? _loadedHistoryType;
  List<ChartPoint>? _volatilityPoints;
  List<ChartPoint>? _marketVolatilityPoints;

  // Card 7 backtest fetch guard
  String? _loadedBacktestSignature;

  @override
  void initState() {
    super.initState();
    logPageEnter('PortfolioTab');
  }

  @override
  void dispose() {
    logPageExit('PortfolioTab');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = PortfolioStateProvider.of(context);
    final type = state.type;
    if (_loadedHistoryType != type) {
      _fetchHistoryForType(type);
    }
    final desiredPortfolio = state.selectedPortfolio ??
        state.recommendation?.portfolioByCode(type.riskCode);
    final desiredSignature = _backtestSignature(desiredPortfolio);
    if (_loadedBacktestSignature != desiredSignature) {
      _fetchBacktest(desiredPortfolio);
    }
  }

  String _backtestSignature(MobilePortfolioRecommendation? portfolio) {
    final startedAt =
        PortfolioStateProvider.of(context).accountSummary?.startedAt ?? '';
    if (portfolio == null) {
      return 'generic|$startedAt';
    }
    final sortedKeys = portfolio.stockWeights.keys.toList()..sort();
    final pairs = sortedKeys
        .map((key) => '$key:${portfolio.stockWeights[key]}')
        .join(',');
    return '${portfolio.code}|$pairs|$startedAt';
  }

  Future<void> _fetchBacktest(MobilePortfolioRecommendation? portfolio) async {
    final signature = _backtestSignature(portfolio);
    _loadedBacktestSignature = signature;
    try {
      final state = PortfolioStateProvider.of(context);
      final selection = state.frontierSelection;
      // See home_shell._fetchBacktest — same fallback rationale.
      final onboardingPick = state.onboardingFrontierSelection;
      final selectedPointIndex =
          selection?.selectedPointIndex ?? onboardingPick?.selectedPointIndex;
      final targetVolatility = selection?.selectedTargetVolatility ??
          onboardingPick?.targetVolatility;
      final stockWeights = portfolio?.stockWeights;
      if (selectedPointIndex == null &&
          targetVolatility == null &&
          (stockWeights == null || stockWeights.isEmpty)) {
        if (_loadedBacktestSignature == signature) {
          _loadedBacktestSignature = null;
        }
        return;
      }
      final bt = await MobileBackendApi.instance.fetchComparisonBacktest(
        preferredDataSource: selection?.dataSource ??
            onboardingPick?.dataSource ??
            state.accountSummary?.dataSource,
        investmentHorizon: selection?.resolvedProfile.investmentHorizon ??
            state.accountSummary?.investmentHorizon ??
            'medium',
        selectedPointIndex: selectedPointIndex,
        targetVolatility: targetVolatility,
        stockWeights: stockWeights,
        portfolioCode: portfolio?.code,
        startDate: DateTime.tryParse(state.accountSummary?.startedAt ?? ''),
      );
      if (!mounted) return;
      if (_loadedBacktestSignature != signature) return;
      PortfolioStateProvider.of(context).setBacktest(bt);
    } catch (_) {
      if (_loadedBacktestSignature == signature) {
        _loadedBacktestSignature = null;
      }
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
    final selection = state.frontierSelection;
    final onboardingPick = state.onboardingFrontierSelection;
    final portfolio =
        state.selectedPortfolio ?? rec?.portfolioByCode(type.riskCode);
    final accountSummary = state.accountSummary;
    final portfolioStartedAt =
        DateTime.tryParse(accountSummary?.startedAt ?? '');
    final horizon = selection?.resolvedProfile.investmentHorizon ??
        onboardingPick?.preview?.resolvedProfile.investmentHorizon ??
        accountSummary?.investmentHorizon ??
        rec?.resolvedProfile.investmentHorizon ??
        'medium';
    final riskProfile = selection?.classificationCode ??
        portfolio?.code ??
        onboardingPick?.preview?.resolvedProfile.code ??
        type.riskCode;

    List<ChartPoint>? volPoints;
    List<ChartPoint>? marketPoints;

    try {
      final volResponse =
          await MobileBackendApi.instance.fetchVolatilityHistory(
        riskProfile: riskProfile,
        investmentHorizon: horizon,
        preferredDataSource: selection?.dataSource ??
            onboardingPick?.dataSource ??
            accountSummary?.dataSource,
        stockWeights: portfolio?.stockWeights,
        selectedPointIndex:
            selection?.selectedPointIndex ?? onboardingPick?.selectedPointIndex,
        targetVolatility: selection?.selectedTargetVolatility ??
            onboardingPick?.targetVolatility,
      );
      volPoints = volResponse.points
          .map((p) => ChartPoint(
                date: p.date,
                value: p.volatility,
              ))
          .toList();
      volPoints = filterChartPointsFromStartDate(
        volPoints,
        startDate: portfolioStartedAt,
      );
      if (volResponse.benchmarkPoints != null &&
          volResponse.benchmarkPoints!.isNotEmpty) {
        marketPoints = volResponse.benchmarkPoints!
            .map((p) => ChartPoint(
                  date: p.date,
                  value: p.volatility,
                ))
            .toList();
        marketPoints = filterChartPointsFromStartDate(
          marketPoints,
          startDate: portfolioStartedAt,
        );
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isLoadingHistory = false;
      _volatilityPoints = volPoints;
      _marketVolatilityPoints = marketPoints;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final type = portfolioState.type;
    final selectedPortfolio = portfolioState.selectedPortfolio;
    final categories = portfolioState.categories;
    final details = portfolioState.categoryDetails;
    final accountSummary = portfolioState.accountSummary;
    final accountActivities = portfolioState.accountActivities;
    final hasResolvedPortfolio =
        selectedPortfolio != null || accountSummary != null;
    final comparisonLines = buildHomePortfolioComparisonLines(portfolioState);
    final rebalanceDates = buildHomePortfolioRebalanceDates(portfolioState);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 8),

            // Portfolio type selector
            if (!portfolioState.hasPrototypeAccount &&
                portfolioState.recommendation != null &&
                portfolioState.frontierSelection == null) ...[
              _PortfolioTypeSelector(
                currentType: type,
                onTypeChanged: (t) {
                  PortfolioStateProvider.of(context).setType(t);
                  setState(() => _selectedSector = null);
                  _fetchHistoryForType(t);
                },
              ),
              const SizedBox(height: 16),
            ],

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
                    label: '변동성',
                    isActive: _viewTab == 1,
                    onTap: () => setState(() => _viewTab = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content — direct swap (no AnimatedSwitcher) because the
            // two views differ in height; stacking them during a fade
            // overlaps the allocation rows with the volatility chart.
            if (_viewTab == 0)
              _AllocationView(
                categories: categories,
                details: details,
                baseValue: _portfolioAllocationBaseValue(accountSummary),
                showAmounts: _showAllocationAmounts,
                hasResolvedPortfolio: hasResolvedPortfolio,
                selectedSector: _selectedSector,
                onSectorSelected: (idx) =>
                    setState(() => _selectedSector = idx),
                onValueModeChanged: (showAmounts) {
                  setState(() => _showAllocationAmounts = showAmounts);
                },
              )
            else
              _TrendView(
                type: type,
                volatilityPoints: _volatilityPoints,
                marketVolatilityPoints: _marketVolatilityPoints,
                comparisonLines: comparisonLines,
                rebalanceDates: rebalanceDates,
                expectedAnnualReturn: portfolioState.expectedReturn,
                isLoading: _isLoadingHistory,
              ),
            const SizedBox(height: 28),

            // Next rebalance card
            _NextRebalanceCard(rebalanceDates: rebalanceDates),
            const SizedBox(height: 28),
            _DepositsPanel(
              activities: accountActivities,
              accountSummary: accountSummary,
            ),
            if (accountSummary != null) const SizedBox(height: 20),
            if (accountSummary != null)
              _ReserveCashPanel(
                reserveCashAmount: accountSummary.cashBalance,
              ),
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
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Row(
        children: [
          _StatItem(
            label: '예상 연 수익률',
            value: p.expectedReturnLabel,
            valueColor: WeRoboColors.primary,
          ),
          _statDivider(tc),
          _StatItem(
            label: '시장 대비 위험도',
            value: '$score ($riskLabel)',
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
  final double? baseValue;
  final bool showAmounts;
  final bool hasResolvedPortfolio;
  final int? selectedSector;
  final ValueChanged<int?> onSectorSelected;
  final ValueChanged<bool> onValueModeChanged;

  const _AllocationView({
    required this.categories,
    required this.details,
    required this.baseValue,
    required this.showAmounts,
    required this.hasResolvedPortfolio,
    required this.selectedSector,
    required this.onSectorSelected,
    required this.onValueModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    if (categories.isEmpty) {
      final message = hasResolvedPortfolio
          ? '포트폴리오 비중 데이터가 아직 없습니다.'
          : '포트폴리오 데이터를 불러오는 중...';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            message,
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
        Row(
          children: [
            Text(
              '포트폴리오 구성',
              style: WeRoboTypography.heading3.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _PortfolioValueToggle(
              showAmounts: showAmounts,
              onValueModeChanged: onValueModeChanged,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...details.map(
          (detail) => _PortfolioAllocationRow(
            detail: detail,
            baseValue: baseValue,
            showAmounts: showAmounts,
            onTap: () => _openAllocationDetailPage(context, detail),
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () {},
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '포트폴리오 조정',
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openAllocationDetailPage(
    BuildContext context,
    PortfolioCategoryDetail detail,
  ) {
    Navigator.push(
      context,
      WeRoboMotion.fadeRoute<void>(
        PortfolioAllocationDetailPage(
          detail: detail,
          baseValue: baseValue,
          initialShowAmounts: showAmounts,
        ),
      ),
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

class _PortfolioValueToggle extends StatelessWidget {
  final bool showAmounts;
  final ValueChanged<bool> onValueModeChanged;

  const _PortfolioValueToggle({
    required this.showAmounts,
    required this.onValueModeChanged,
  });

  static const double _chipSize = 36.0;
  static const double _padding = 3.0;

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    const totalWidth = _chipSize * 2 + _padding * 2 + 4;
    return Pressable(
      onTap: () => onValueModeChanged(!showAmounts),
      child: Container(
        width: totalWidth,
        height: _chipSize + _padding * 2,
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment:
                  showAmounts ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: _chipSize,
                height: _chipSize,
                decoration: BoxDecoration(
                  color: tc.card,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: _chipSize + 2,
                  child: Center(
                    child: Text(
                      '%',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: !showAmounts ? tc.textPrimary : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _chipSize + 2,
                  child: Center(
                    child: Text(
                      '원',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: showAmounts ? tc.textPrimary : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.body,
                      ),
                    ),
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

class _PortfolioAllocationRow extends StatelessWidget {
  final PortfolioCategoryDetail detail;
  final double? baseValue;
  final bool showAmounts;
  final VoidCallback onTap;

  const _PortfolioAllocationRow({
    required this.detail,
    required this.baseValue,
    required this.showAmounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.border),
          boxShadow: WeRoboElevation.card(context),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: detail.category.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.category.name,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _buildAllocationSubtitle(detail),
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              showAmounts
                  ? _formatWonFromRatio(baseValue, detail.category.percentage)
                  : _formatPercentLabel(detail.category.percentage),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: WeRoboFonts.english,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: tc.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }

  String _buildAllocationSubtitle(PortfolioCategoryDetail detail) {
    if (detail.tickers.isEmpty) {
      return '세부 종목 정보 없음';
    }
    final symbols =
        detail.tickers.take(3).map((ticker) => ticker.symbol).join(', ');
    if (detail.tickers.length <= 3) {
      return symbols;
    }
    return '$symbols 외 ${detail.tickers.length - 3}개';
  }
}

class _DepositsPanel extends StatelessWidget {
  final List<MobileAccountActivity> activities;
  final MobileAccountSummary? accountSummary;

  const _DepositsPanel({
    required this.activities,
    required this.accountSummary,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final latestDeposit = _findLatestDeposit(activities);
    final latestAmount = latestDeposit?.amount ??
        ((accountSummary?.investedAmount ?? 0) > 0
            ? accountSummary?.investedAmount
            : null);
    final latestDate = _parseIsoDate(
      latestDeposit?.date ?? accountSummary?.startedAt,
    );
    const upcomingAmount = 100000.0;
    final upcomingDate = latestDate == null ? null : _addOneMonth(latestDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '입금 현황',
              style: WeRoboTypography.heading3.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: tc.textTertiary),
          ],
        ),
        const SizedBox(height: 16),
        _DepositInfoRow(
          label: '최근 입금',
          valueText: latestAmount == null
              ? '아직 입금 내역이 없어요'
              : '${_formatCurrency(latestAmount.round())} 원'
                  ' · ${_formatKoreanMonthDay(latestDate!)}',
        ),
        Divider(
          color: tc.border.withValues(alpha: 0.4),
          height: 1,
          thickness: 0.5,
        ),
        _DepositInfoRow(
          label: '예정 입금',
          valueText: upcomingDate == null
              ? '예정된 입금이 없어요'
              : '${_formatCurrency(upcomingAmount.round())} 원'
                  ' · ${_formatKoreanMonthDay(upcomingDate)}',
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: _DepositActionButton(
                icon: Icons.add_rounded,
                label: '입금하기',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _DepositActionButton(
                icon: Icons.event_repeat_rounded,
                label: '정기 입금',
              ),
            ),
          ],
        ),
      ],
    );
  }

  MobileAccountActivity? _findLatestDeposit(List<MobileAccountActivity> items) {
    final deposits = items
        .where(
          (activity) =>
              activity.type == 'cash_in' || activity.type == 'initial_deposit',
        )
        .toList()
      ..sort((a, b) {
        final aDate = _parseIsoDate(a.date) ?? DateTime(1970);
        final bDate = _parseIsoDate(b.date) ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

    if (deposits.isEmpty) {
      return null;
    }
    return deposits.first;
  }
}

class _DepositInfoRow extends StatelessWidget {
  final String label;
  final String valueText;

  const _DepositInfoRow({required this.label, required this.valueText});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            valueText,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w500,
              fontFamily: WeRoboFonts.english,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DepositActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: () {},
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: tc.textPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReserveCashPanel extends StatelessWidget {
  final double reserveCashAmount;

  const _ReserveCashPanel({required this.reserveCashAmount});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '예비 현금',
          style: WeRoboTypography.heading3.copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '포트폴리오 구성 비중에는 포함되지 않아요.',
          style: WeRoboTypography.bodySmall.copyWith(color: tc.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '리밸런싱 시 별도로 보관됐다가 자동 사용돼요.',
          style: WeRoboTypography.caption.copyWith(color: tc.textTertiary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '현재 보유',
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              _formatWonAmount(reserveCashAmount),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: WeRoboFonts.english,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatCurrency(int amount) {
  final str = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

String _formatPercentLabel(double percentage) {
  return '${percentage.toStringAsFixed(2)}%';
}

String _formatWonFromRatio(double? baseValue, double percentage) {
  if (baseValue == null || baseValue <= 0) {
    return '-';
  }
  final amount = (baseValue * percentage / 100).round();
  return '${_formatCurrency(amount)} 원';
}

String _formatWonAmount(double? amount) {
  if (amount == null) {
    return '-';
  }
  return '${_formatCurrency(amount.round())} 원';
}

double? _portfolioAllocationBaseValue(MobileAccountSummary? summary) {
  if (summary == null) {
    return null;
  }
  final currentInvestedValue = summary.currentValue - summary.cashBalance;
  if (currentInvestedValue > 0) {
    return currentInvestedValue;
  }
  final investedPrincipalExcludingCash =
      summary.investedAmount - summary.cashBalance;
  if (investedPrincipalExcludingCash > 0) {
    return investedPrincipalExcludingCash;
  }
  return null;
}

DateTime? _parseIsoDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime _addOneMonth(DateTime date) {
  final nextMonth = date.month == 12 ? 1 : date.month + 1;
  final nextYear = date.month == 12 ? date.year + 1 : date.year;
  final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
  final nextDay = date.day > lastDayOfNextMonth ? lastDayOfNextMonth : date.day;
  return DateTime(nextYear, nextMonth, nextDay);
}

String _formatKoreanMonthDay(DateTime date) {
  return '${date.month}월 ${date.day}일';
}

// ── Trend view (card 2 + card 7 API data) ──

class _TrendView extends StatelessWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;
  final List<ChartPoint>? marketVolatilityPoints;
  final List<ChartLine> comparisonLines;
  final List<DateTime> rebalanceDates;
  final double? expectedAnnualReturn;
  final bool isLoading;

  const _TrendView({
    required this.type,
    this.volatilityPoints,
    this.marketVolatilityPoints,
    required this.comparisonLines,
    required this.rebalanceDates,
    this.expectedAnnualReturn,
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
        marketVolatilityPoints: marketVolatilityPoints,
        comparisonLines: comparisonLines.isNotEmpty ? comparisonLines : null,
        rebalanceDates: rebalanceDates.isNotEmpty ? rebalanceDates : null,
        expectedAnnualReturn: expectedAnnualReturn,
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
