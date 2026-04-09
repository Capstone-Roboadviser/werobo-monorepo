import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../models/mock_earnings_data.dart';
import '../../models/rebalance_data.dart';
import '../../services/mobile_backend_api.dart';
import 'volatility_screen.dart';
import 'widgets/chart_painters.dart';

class PortfolioTab extends StatefulWidget {
  const PortfolioTab({super.key});

  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  int? _expandedEvent;

  // Volatility API data (passed to volatility screen)
  bool _isLoadingHistory = false;
  InvestmentType? _loadedHistoryType;
  List<ChartPoint>? _volatilityPoints;

  // Backtest fetch guard
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
      final bt = await MobileBackendApi.instance
          .fetchComparisonBacktest();
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
      final result = await MobileBackendApi.instance
          .fetchRebalanceSimulation(
        weights: weights,
        startDate: '2025-03-03',
      );
      if (!mounted) return;
      setState(() => _apiRebalanceEvents = result.rebalanceEvents);
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

  void _navigateToVolatility() {
    final type = PortfolioStateProvider.of(context).type;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => VolatilityScreen(
          type: type,
          volatilityPoints: _volatilityPoints,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final type = portfolioState.type;
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
            Text('내 포트폴리오',
                style:
                    WeRoboTypography.heading2.themed(context)),
            const SizedBox(height: 12),

            // Portfolio type selector
            _PortfolioTypeSelector(
              currentType: type,
              onTypeChanged: (t) {
                PortfolioStateProvider.of(context).setType(t);
                _fetchHistoryForType(t);
              },
            ),
            const SizedBox(height: 16),

            // Risk & return summary
            _PortfolioStatsCard(
              portfolio: portfolioState.selectedPortfolio,
            ),
            const SizedBox(height: 16),

            // Comparison chart (replaces old toggle + pie/trend)
            _ComparisonChartSection(
              type: type,
              comparisonLines:
                  lines.isNotEmpty ? lines : null,
              rebalanceDates: rebalanceDates.isNotEmpty
                  ? rebalanceDates
                  : null,
            ),
            const SizedBox(height: 16),

            // Volatility page navigation
            _VolatilityNavButton(
              onTap: _navigateToVolatility,
            ),
            const SizedBox(height: 20),

            // Next rebalance card
            _NextRebalanceCard(
                rebalanceDates: rebalanceDates),
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
                color: WeRoboColors.primary
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high_rounded,
                          size: 18,
                          color: WeRoboColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '자동 리밸런싱',
                        style:
                            WeRoboTypography.bodySmall.copyWith(
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
            Text('리밸런싱 기록',
                style:
                    WeRoboTypography.heading3.themed(context)),
            const SizedBox(height: 12),
            ...rebalanceEvents.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              return _RebalanceEventCard(
                event: event,
                isExpanded: _expandedEvent == i,
                onTap: () => setState(() =>
                    _expandedEvent =
                        _expandedEvent == i ? null : i),
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Comparison chart section ──

class _ComparisonChartSection extends StatefulWidget {
  final InvestmentType type;
  final List<ChartLine>? comparisonLines;
  final List<DateTime>? rebalanceDates;

  const _ComparisonChartSection({
    required this.type,
    this.comparisonLines,
    this.rebalanceDates,
  });

  @override
  State<_ComparisonChartSection> createState() =>
      _ComparisonChartSectionState();
}

class _ComparisonChartSectionState
    extends State<_ComparisonChartSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _drawCtrl;
  int? _touchIndex;
  int _range = 4;

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
  void didUpdateWidget(covariant _ComparisonChartSection old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) {
      _drawCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    super.dispose();
  }

  List<ChartLine> _buildDisplayLines(
      List<ChartLine> rawLines) {
    final code = widget.type.riskCode;
    final result = <ChartLine>[];

    // 1. Portfolio line (포폴선) — blue solid
    for (final line in rawLines) {
      if (line.key == code) {
        result.add(ChartLine(
          key: line.key,
          label: line.label,
          color: WeRoboColors.primary,
          dashed: false,
          points: line.points,
        ));
        break;
      }
    }

    // 2. Market line (시장선) — grey solid
    for (final line in rawLines) {
      if (line.key == 'sp500') {
        result.add(ChartLine(
          key: 'sp500',
          label: 'S&P 500',
          color: const Color(0xFF999999),
          dashed: false,
          points: line.points,
        ));
        break;
      }
    }

    // 3. Bond line (채권) — dark grey dotted
    for (final line in rawLines) {
      if (line.key == 'treasury') {
        result.add(ChartLine(
          key: 'treasury',
          label: '10년 국채',
          color: const Color(0xFF666666),
          dashed: true,
          points: line.points,
        ));
        break;
      }
    }

    return result;
  }

  List<ChartLine> _filterByRange(List<ChartLine> rawLines) {
    final cutoff = DateTime.now()
        .subtract(Duration(days: _rangeDays[_range]));
    return rawLines.map((line) {
      final filtered = line.points
          .where((p) => p.date.isAfter(cutoff))
          .toList();
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
    final allLines =
        widget.comparisonLines ?? const <ChartLine>[];
    final displayLines = allLines.isEmpty
        ? allLines
        : _buildDisplayLines(allLines);
    final lines = displayLines.isEmpty
        ? displayLines
        : _filterByRange(displayLines);
    final rebalanceDates =
        widget.rebalanceDates ?? const <DateTime>[];

    return Column(
      children: [
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
        SizedBox(
          height: 320,
          child: lines.isEmpty
              ? const EmptyChartState(
                  message: '비교 백테스트 데이터가 아직 없습니다.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanUpdate: (d) {
                        if (lines.isEmpty ||
                            lines[0].points.isEmpty) {
                          return;
                        }
                        final x = d.localPosition.dx - 36;
                        final chartW =
                            constraints.maxWidth - 36 - 12;
                        final count = lines[0].points.length;
                        final idx =
                            ((x / chartW) * (count - 1))
                                .round()
                                .clamp(0, count - 1);
                        setState(() => _touchIndex = idx);
                      },
                      onPanEnd: (_) =>
                          setState(() => _touchIndex = null),
                      onTapUp: (_) =>
                          setState(() => _touchIndex = null),
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
                              textTertiaryColor:
                                  tc.textTertiary,
                              textPrimaryColor:
                                  tc.textPrimary,
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
      ],
    );
  }
}

// ── Volatility navigation button ──

class _VolatilityNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _VolatilityNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: WeRoboColors.primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.show_chart_rounded,
                  size: 18, color: WeRoboColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '포트폴리오 변동성',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: tc.textTertiary),
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

// ── Contribution analysis section ──

class _ContributionSection extends StatelessWidget {
  final String riskCode;

  const _ContributionSection({required this.riskCode});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final summary = MockEarningsData.summaryFor(riskCode);
    final commentary =
        MockEarningsData.commentaryFor(riskCode);
    final sorted = [...summary]
      ..sort((a, b) => b.earnings.compareTo(a.earnings));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('수익 기여 분석',
            style:
                WeRoboTypography.heading3.themed(context)),
        const SizedBox(height: 8),
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
        ...sorted.map((a) {
          final isPositive = a.earnings >= 0;
          final color =
              isPositive ? tc.accent : WeRoboColors.error;
          final maxEarnings = sorted.first.earnings.abs();
          final barFraction = maxEarnings > 0
              ? (a.earnings.abs() / maxEarnings)
              : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.assetName,
                          style: WeRoboTypography.caption
                              .copyWith(
                                  color: tc.textPrimary,
                                  fontWeight:
                                      FontWeight.w500),
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
                        value:
                            barFraction.clamp(0.0, 1.0),
                        backgroundColor: tc.border
                            .withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation(color),
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
                  child: Icon(Icons.check_rounded,
                      size: 20, color: tc.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(dateStr,
                          style: WeRoboTypography.bodySmall
                              .copyWith(
                                  color: tc.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontFamily:
                                      WeRoboFonts.english)),
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
              label: '변경 전',
              changes: event.changes,
              useBefore: true),
          const SizedBox(height: 6),
          _AllocationBar(
              label: '변경 후',
              changes: event.changes,
              useBefore: false),
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
                      borderRadius:
                          BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(change.sectorName,
                        style: WeRoboTypography.caption
                            .copyWith(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6),
                    child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: tc.textTertiary),
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
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}'
                      '${change.delta.toStringAsFixed(1)}%',
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
                final pct = useBefore
                    ? change.beforePct
                    : change.afterPct;
                return Flexible(
                  flex: (pct * 10).round().clamp(1, 1000),
                  child: Container(
                    color: change.color.withValues(
                        alpha: useBefore ? 0.5 : 1.0),
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
