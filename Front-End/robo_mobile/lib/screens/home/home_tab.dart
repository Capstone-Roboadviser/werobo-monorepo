import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../services/mobile_backend_api.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/mock_earnings_data.dart';
import '../../models/portfolio_data.dart';
import '../../models/rebalance_insight.dart';
import 'activity_hub_page.dart';
import 'digest_screen.dart';
import 'insight_detail_page.dart';
import 'portfolio_allocation_detail_page.dart';
import 'widgets/glowing_border.dart';
import 'projection_screen.dart';
import 'widgets/insight_transition_chart.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  bool _showAllocationAmounts = false;
  bool _earningsHistoryFetchStarted = false;
  String? _loadedEarningsRiskCode;

  @override
  void initState() {
    super.initState();
    logPageEnter('HomeTab');
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    logPageExit('HomeTab');
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = PortfolioStateProvider.of(context);
    final riskCode = state.type.riskCode;
    if (_loadedEarningsRiskCode != riskCode) {
      _loadedEarningsRiskCode = riskCode;
      _earningsHistoryFetchStarted = false;
    }
    if (!_earningsHistoryFetchStarted && state.earningsHistory == null) {
      _earningsHistoryFetchStarted = true;
      _loadEarningsHistory(state, riskCode);
    }
  }

  Future<void> _loadEarningsHistory(
    PortfolioState state,
    String riskCode,
  ) async {
    final selected = state.selectedPortfolio;
    final startedAt = state.accountSummary?.startedAt;
    if (selected == null || startedAt == null || startedAt.isEmpty) {
      // Cold-start path: fall back to mock immediately so the card has data
      // when the user starts dragging. Defer past the current build frame so
      // notifyListeners() doesn't fire during didChangeDependencies.
      Future.microtask(() {
        if (!mounted) return;
        state.setEarningsHistory(
          MockEarningsData.mockEarningsHistoryResponse(riskCode: riskCode),
        );
      });
      return;
    }
    try {
      final api = MobileBackendApi.instance;
      final response = await api.fetchEarningsHistory(
        weights: {
          for (final s in selected.sectorAllocations) s.assetCode: s.weight,
        },
        startDate: startedAt,
      );
      if (!mounted) return;
      state.setEarningsHistory(response);
    } catch (e) {
      if (!mounted) return;
      developer.log(
        'fetchEarningsHistory failed; using mock fallback: $e',
        name: 'HomeTab',
      );
      state.setEarningsHistory(
        MockEarningsData.mockEarningsHistoryResponse(riskCode: riskCode),
      );
    }
  }

  Animation<double> _fadeAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: WeRoboMotion.enter),
    );
  }

  Animation<Offset> _slideAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: WeRoboMotion.enter),
      ),
    );
  }

  Widget _stagger(int index, Widget child) {
    return SlideTransition(
      position: _slideAt(index),
      child: FadeTransition(opacity: _fadeAt(index), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final type = state.type;
    final activities = state.accountActivities;
    final accountSummary = state.accountSummary;
    final allocationDetails = state.categoryDetails;
    final hasResolvedPortfolio =
        state.selectedPortfolio != null || state.accountSummary != null;
    final latestUnreadInsight =
        state.unreadInsights.isNotEmpty ? state.unreadInsights.first : null;
    final issueData = _HomeIssueFeedDataSource.resolve(
      hasResolvedPortfolio: hasResolvedPortfolio,
      liveDigest: state.weeklyDigest,
      liveInsight: latestUnreadInsight,
    );
    final issueDigest = issueData.digest;
    final issueInsight = issueData.latestInsight;
    final hasIssueFeed = _PortfolioIssueFeed.hasItems(
      digest: issueDigest,
      latestInsight: issueInsight,
    );
    final hasStandaloneInsightBanner =
        state.unreadInsightCount > 0 && !hasIssueFeed;
    final hasStandaloneDigestBanner = state.isWeeklyDigestAvailable &&
        !state.hasSeenCurrentDigest &&
        !hasIssueFeed;
    int staggerIdx = 0;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Notification icon (persistent access)
            Align(
              alignment: Alignment.centerRight,
              child: _NotificationIconButton(
                hasUnread: state.unreadInsightCount > 0,
              ),
            ),
            const SizedBox(height: 8),

            // Welcome banner (first visit only)
            if (!state.welcomeBannerSeen)
              _stagger(
                staggerIdx,
                _WelcomeBanner(
                  type: type,
                  onDismiss: () => state.markWelcomeBannerSeen(),
                ),
              )
            else
              const SizedBox.shrink(),
            if (!state.welcomeBannerSeen)
              const SizedBox(height: 16)
            else
              const SizedBox.shrink(),

            // Hero: value + chart + time range
            _stagger(
              !state.welcomeBannerSeen ? ++staggerIdx : staggerIdx,
              _PortfolioHeroChart(type: type),
            ),
            if (hasIssueFeed) const SizedBox(height: 16),
            if (hasIssueFeed)
              _stagger(
                ++staggerIdx,
                _PortfolioIssueFeed(
                  digest: issueDigest,
                  latestInsight: issueInsight,
                  onDigestTap: issueData.usesPlaceholderDigest
                      ? null
                      : () => Navigator.push(
                            context,
                            WeRoboMotion.fadeRoute<void>(
                              const DigestScreen(),
                            ),
                          ),
                  onInsightTap:
                      issueData.usesPlaceholderInsight || issueInsight == null
                          ? null
                          : () => Navigator.push(
                                context,
                                WeRoboMotion.fadeRoute<void>(
                                  InsightDetailPage(insight: issueInsight),
                                ),
                              ),
                ),
              ),
            SizedBox(height: hasIssueFeed ? 24 : 28),

            // Standalone legacy banners only render when the timeline has
            // nothing to own, avoiding duplicate digest/algorithm alerts.
            if (hasStandaloneInsightBanner)
              Divider(color: tc.border.withValues(alpha: 0.3), height: 1),
            if (hasStandaloneInsightBanner) const SizedBox(height: 16),
            if (hasStandaloneInsightBanner)
              _stagger(
                ++staggerIdx,
                _InsightBanner(
                  latestInsight: state.unreadInsights.first,
                  unreadCount: state.unreadInsightCount,
                ),
              ),
            if (hasStandaloneInsightBanner) const SizedBox(height: 20),

            if (hasStandaloneDigestBanner)
              _stagger(
                ++staggerIdx,
                _DigestBanner(
                  onTap: () => Navigator.push(
                    context,
                    WeRoboMotion.fadeRoute<void>(const DigestScreen()),
                  ),
                ),
              ),
            if (hasStandaloneDigestBanner) const SizedBox(height: 20),

            _stagger(
              ++staggerIdx,
              _DepositsPanel(
                activities: activities,
                accountSummary: accountSummary,
              ),
            ),
            const SizedBox(height: 20),
            Divider(
              color: WeRoboThemeColors.of(
                context,
              ).border.withValues(alpha: 0.15),
              height: 1,
              thickness: 0.5,
            ),
            const SizedBox(height: 20),
            _stagger(
              ++staggerIdx,
              _PortfolioAllocationPanel(
                details: allocationDetails,
                baseValue: _portfolioAllocationBaseValue(accountSummary),
                showAmounts: _showAllocationAmounts,
                hasResolvedPortfolio: hasResolvedPortfolio,
                onValueModeChanged: (showAmounts) {
                  setState(() => _showAllocationAmounts = showAmounts);
                },
              ),
            ),
            if (accountSummary != null) const SizedBox(height: 20),
            if (accountSummary != null)
              _stagger(
                ++staggerIdx,
                _ReserveCashPanel(
                  reserveCashAmount: accountSummary.cashBalance,
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _HomeIssueFeedData {
  final MobileDigestResponse? digest;
  final RebalanceInsight? latestInsight;
  final bool usesPlaceholderDigest;
  final bool usesPlaceholderInsight;

  const _HomeIssueFeedData({
    required this.digest,
    required this.latestInsight,
    required this.usesPlaceholderDigest,
    required this.usesPlaceholderInsight,
  });
}

class _HomeIssueFeedDataSource {
  static const _placeholderDigest = MobileDigestResponse(
    digestDate: '2026-05-05',
    periodStart: '2026-04-05',
    periodEnd: '2026-05-05',
    totalReturnPct: -2.8,
    totalReturnWon: -280000,
    narrativeKo: '최근 한 달 동안 포트폴리오 움직임이 평소보다 커졌어요.',
    hasNarrative: true,
    drivers: [
      DigestDriver(
        ticker: 'GLD',
        nameKo: '금',
        sectorCode: 'gold',
        weightPct: 18,
        returnPct: 3.1,
        contributionWon: 180000,
      ),
    ],
    detractors: [
      DigestDriver(
        ticker: 'QQQ',
        nameKo: '미국 성장주',
        sectorCode: 'us_growth',
        weightPct: 42,
        returnPct: -5.4,
        contributionWon: -460000,
      ),
    ],
    sourcesUsed: ['미국 금리 전망', '성장주 변동성'],
    disclaimer: '',
    generatedAt: '2026-05-05T09:00:00Z',
    degradationLevel: 0,
    triggerSigmaMultiple: 2.8,
  );

  static const _placeholderInsight = RebalanceInsight(
    id: -1,
    rebalanceDate: '2026-05-05',
    allocations: [],
    tradeDetails: [],
    trigger: '포트폴리오 변동성 확대',
    tradeCount: 3,
    cashBefore: 80000,
    cashFromSales: 24791,
    cashToBuys: 1879,
    cashAfter: 103256,
    netCashChange: 23256,
    explanationText: '포트폴리오 변동성이 커져 알고리즘이 비중 조정을 감지했어요.',
    isRead: false,
    createdAt: '2026-05-05T09:00:00Z',
  );

  static _HomeIssueFeedData resolve({
    required bool hasResolvedPortfolio,
    required MobileDigestResponse? liveDigest,
    required RebalanceInsight? liveInsight,
  }) {
    if (!hasResolvedPortfolio) {
      return const _HomeIssueFeedData(
        digest: null,
        latestInsight: null,
        usesPlaceholderDigest: false,
        usesPlaceholderInsight: false,
      );
    }

    return _HomeIssueFeedData(
      digest: liveDigest ?? _placeholderDigest,
      latestInsight: liveInsight ?? _placeholderInsight,
      usesPlaceholderDigest: liveDigest == null,
      usesPlaceholderInsight: liveInsight == null,
    );
  }
}

// ─── Hero chart: value + chart + time range ─────────

class _PortfolioHeroChart extends StatefulWidget {
  final InvestmentType type;
  const _PortfolioHeroChart({required this.type});

  @override
  State<_PortfolioHeroChart> createState() => _PortfolioHeroChartState();
}

class _PortfolioHeroChartState extends State<_PortfolioHeroChart>
    with TickerProviderStateMixin {
  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체', '미래'];
  static const _rangeDays = [7, 90, 365, 1825, 99999, -1];
  static const _baseInvestment = 10000000.0;

  late AnimationController _drawCtrl;
  late CurvedAnimation _drawCurve;
  late AnimationController _glowCtrl;
  // The draw animation is deferred until comparison-backtest data is
  // available, so all four lines (portfolio + benchmarks) sweep in
  // left-to-right together as a single pass. A timer enforces a max
  // wait so the chart still animates if backtest fetch is slow or fails.
  bool _drawStarted = false;
  Timer? _drawDelayTimer;
  int _range = 4; // 전체
  int? _touchIndex;

  List<ChartPoint> get _allValue {
    final accountHistory = PortfolioStateProvider.of(context).accountHistory;
    if (accountHistory.isNotEmpty) {
      return _ensureRenderable([
        for (final point in accountHistory)
          ChartPoint(date: point.date, value: point.portfolioValue),
      ]);
    }
    final backtest = PortfolioStateProvider.of(
      context,
    ).portfolioValuePoints(baseInvestment: _baseInvestment);
    if (backtest.isNotEmpty) return backtest;
    final riskCode = PortfolioStateProvider.of(context).type.riskCode;
    return MockEarningsData.dailyCumulativePoints(
      riskCode: riskCode,
      baseInvestment: _baseInvestment,
    );
  }

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _drawCurve = CurvedAnimation(parent: _drawCtrl, curve: Curves.linear);
    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    // Fallback: if backtest never lands (offline, mock fallback, etc.),
    // start the animation anyway so the portfolio line still draws in.
    _drawDelayTimer = Timer(const Duration(milliseconds: 1200), () {
      _startDrawAnimation();
    });
  }

  void _startDrawAnimation() {
    if (_drawStarted || !mounted) return;
    _drawStarted = true;
    _drawDelayTimer?.cancel();
    _drawCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_drawStarted) {
      final hasBenchmarks =
          PortfolioStateProvider.of(context).comparisonLines.isNotEmpty;
      if (hasBenchmarks) {
        _startDrawAnimation();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _PortfolioHeroChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _touchIndex = null;
      _drawCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drawDelayTimer?.cancel();
    _glowCtrl.dispose();
    _drawCurve.dispose();
    _drawCtrl.dispose();
    super.dispose();
  }

  List<ChartPoint> _filterByRange(List<ChartPoint> all) {
    if (all.isEmpty) return all;
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    final filtered = all.where((p) => p.date.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  List<ChartPoint> _ensureRenderable(List<ChartPoint> points) {
    if (points.length != 1) {
      return points;
    }
    final point = points.first;
    return [
      ChartPoint(
        date: point.date.subtract(const Duration(days: 1)),
        value: point.value,
      ),
      point,
    ];
  }

  /// Rebase a KRW-valued `ChartPoint` series to percent return from the
  /// first point. The output's `value` field carries fractional return
  /// (`0.0` = 0%, `0.05` = +5%). First point is always exactly `0.0`.
  List<ChartPoint> _pctSeries(List<ChartPoint> krw) {
    if (krw.isEmpty) return const [];
    final base = krw.first.value;
    if (base == 0) return const [];
    return [
      for (final p in krw)
        ChartPoint(date: p.date, value: (p.value - base) / base),
    ];
  }

  /// Market benchmark line (`benchmark_avg`), filtered to the visible
  /// range, rebased to 0% at the first visible point. Returns an empty
  /// list when the comparison backtest hasn't loaded yet.
  List<ChartPoint> _marketSeries(List<ChartPoint> portfolioRangePts) {
    if (portfolioRangePts.isEmpty) return const [];
    final all = PortfolioStateProvider.of(context).comparisonLines;
    final market = all.firstWhere(
      (l) => l.key == 'benchmark_avg',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (market.points.length < 2) return const [];

    final cutoff = portfolioRangePts.first.date;
    final filtered =
        market.points.where((p) => !p.date.isBefore(cutoff)).toList();
    if (filtered.length < 2) return const [];

    final base = filtered.first.value;
    final result = <ChartPoint>[
      for (final p in filtered) ChartPoint(date: p.date, value: p.value - base),
    ];
    // Carry the last known value forward to the chart's right edge when
    // the backtest data lags the portfolio's account history (a common
    // gap on the 1주 view). Standard finance-app convention: "no new
    // trading day yet → hold yesterday's close." Without this, the
    // 시장 line would visibly stop short of the chart's right edge.
    final portfolioLastDate = portfolioRangePts.last.date;
    if (result.last.date.isBefore(portfolioLastDate)) {
      result.add(
        ChartPoint(date: portfolioLastDate, value: result.last.value),
      );
    }
    return result;
  }

  /// 채권 수익률 — drawn as a 2-point dashed line from the start of the
  /// visible range (0%) to the treasury's end-of-range cumulative return.
  /// Mirrors the `bond_trend` derivation in `portfolio_charts.dart`.
  List<ChartPoint> _bondEndpoints(List<ChartPoint> portfolioRangePts) {
    if (portfolioRangePts.isEmpty) return const [];
    final all = PortfolioStateProvider.of(context).comparisonLines;
    final treasury = all.firstWhere(
      (l) => l.key == 'treasury',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (treasury.points.length < 2) return const [];

    final cutoff = portfolioRangePts.first.date;
    final filtered =
        treasury.points.where((p) => !p.date.isBefore(cutoff)).toList();
    if (filtered.length < 2) return const [];

    final base = filtered.first.value;
    // End the dashed line at the chart's right edge (portfolio's last
    // date), not where the treasury data happens to stop. Same "carry
    // last value forward" convention as `_marketSeries`.
    final endDate = portfolioRangePts.last.date.isAfter(filtered.last.date)
        ? portfolioRangePts.last.date
        : filtered.last.date;
    return [
      ChartPoint(date: filtered.first.date, value: 0.0),
      ChartPoint(date: endDate, value: filtered.last.value - base),
    ];
  }

  /// 연 기대수익률 — 2-point dashed line from the start of the visible
  /// range (0%) to `expectedReturn × elapsedYears`. Returns empty when
  /// `expectedReturn` is null or the visible range is empty.
  List<ChartPoint> _expectedReturnEndpoints(
    List<ChartPoint> portfolioRangePts,
  ) {
    if (portfolioRangePts.length < 2) return const [];
    final expected = PortfolioStateProvider.of(context).expectedReturn;
    if (expected == null) return const [];
    final first = portfolioRangePts.first.date;
    final last = portfolioRangePts.last.date;
    final elapsedDays = math.max(0, last.difference(first).inDays);
    final terminalReturn = expected * (elapsedDays / 365.25);
    return [
      ChartPoint(date: first, value: 0.0),
      ChartPoint(date: last, value: terminalReturn),
    ];
  }

  ({
    double x,
    double y,
    double portfolioPct,
    double? marketPct,
    List<({String name, double pct})> assetRows,
  })? _buildCardData(
    List<ChartPoint> valuePts, {
    required double fullWidth,
    required double stackWidth,
  }) {
    final ti = _touchIndex;
    if (ti == null || ti < 1 || ti >= valuePts.length) return null;

    // Day-over-day portfolio %.
    final curr = valuePts[ti].value;
    final prev = valuePts[ti - 1].value;
    if (prev == 0) return null;
    final portfolioPct = (curr - prev) / prev;

    // Day-over-day market %, if benchmark data exists.
    double? marketPct;
    final state = PortfolioStateProvider.of(context);
    final marketLine = state.comparisonLines.firstWhere(
      (l) => l.key == 'benchmark_avg',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (marketLine.points.length >= 2) {
      final touchDate = valuePts[ti].date;
      final mIdx = marketLine.points.indexWhere(
        (p) =>
            p.date.year == touchDate.year &&
            p.date.month == touchDate.month &&
            p.date.day == touchDate.day,
      );
      if (mIdx >= 1) {
        // comparisonLines values are cumulative returns (e.g. 0.12 = +12%
        // from backtest start). The day-over-day rate is NOT the raw
        // subtraction — that would only be correct for small mPrev. The
        // exact conversion from cumulative-return space to daily-return
        // space is (mCurr - mPrev) / (1 + mPrev), which equals the asset
        // value's actual day-over-day percent change.
        final mCurr = marketLine.points[mIdx].value;
        final mPrev = marketLine.points[mIdx - 1].value;
        final denom = 1 + mPrev;
        if (denom != 0) {
          marketPct = (mCurr - mPrev) / denom;
        }
      }
      // If the touch date isn't in the market series (typically a non-
      // trading day — weekend/holiday — where the portfolio value also
      // didn't change), show 0% rather than dropping the row entirely.
      // The portfolio row will read +0.00% on the same day, so the two
      // rows stay consistent.
      marketPct ??= 0.0;
    }

    // Top 2 asset gainers/losers based on portfolio direction.
    final assetReturns = state.dayOverDayAssetReturns(valuePts[ti].date);
    final names = <String, String>{
      for (final s in (state.selectedPortfolio?.sectorAllocations ??
          const <MobileSectorAllocation>[]))
        s.assetCode: s.assetName,
    };
    final entries = assetReturns.entries
        .where((e) => names.containsKey(e.key))
        .map((e) => (name: names[e.key]!, pct: e.value))
        .toList();
    if (portfolioPct >= 0) {
      entries.sort((a, b) => b.pct.compareTo(a.pct));
    } else {
      entries.sort((a, b) => a.pct.compareTo(b.pct));
    }
    // When portfolio is exactly 0%, the underlying account history likely
    // repeated yesterday's snapshot (non-trading day or sparse backend
    // data). Showing per-asset movement for the same date contradicts the
    // 0% portfolio number and confuses readers — drop the asset rows so
    // the card reads consistently as "no movement on this date."
    final assetRows = portfolioPct == 0
        ? const <({String name, double pct})>[]
        : entries.take(2).toList();

    // Position: anchor x at touch index, y above the dot if room else below.
    // touchX is in Stack-relative coords: the chart canvas is laid out at
    // `fullWidth` via OverflowBox, then shifted left by 24px (the parent
    // SingleChildScrollView's horizontal padding). Clamp the card against
    // the Stack's actual width, not the chart canvas width, so it doesn't
    // overflow into the parent's right padding.
    const padX = 8.0;
    const cardWidth = _DragContextCard.width;
    final touchX = (ti / (valuePts.length - 1)) * fullWidth - 24;
    final x = (touchX - cardWidth / 2)
        .clamp(padX, stackWidth - cardWidth - padX)
        .toDouble();

    // Compute the actual portfolio dot Y using the painter's range math
    // (global min/max across all 4 line series + 5% padding) so the card
    // can be positioned with real awareness of where the orange line is.
    final portfolioPctSeries = _pctSeries(valuePts);
    final marketPts = _marketSeries(valuePts);
    final expectedPts = _expectedReturnEndpoints(valuePts);
    final bondPts = _bondEndpoints(valuePts);
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    void scan(List<ChartPoint> pts) {
      for (final p in pts) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
    }

    scan(portfolioPctSeries);
    scan(marketPts);
    scan(expectedPts);
    scan(bondPts);
    if (minY == double.infinity) {
      minY = 0;
      maxY = 0;
    }
    final yRange = (maxY - minY).clamp(0.0001, double.infinity);
    final paddedMin = minY - yRange * 0.05;
    final paddedMax = maxY + yRange * 0.05;
    final paddedRange = paddedMax - paddedMin;
    const graphTopPad = 36.0;
    const graphBotPad = 50.0;
    const chartTotalH = 320.0;
    const chartH = chartTotalH - graphTopPad - graphBotPad;
    final currPctValue =
        ti < portfolioPctSeries.length ? portfolioPctSeries[ti].value : 0.0;
    final dotY = graphTopPad +
        chartH -
        ((currPctValue - paddedMin) / paddedRange) * chartH;

    // Place the card on the side of the dot with more room, with a 24px
    // breathing margin so the card never sits ON or NEAR the orange line.
    const cardHeight = _DragContextCard.height;
    const margin = 24.0;
    const padY = 8.0;
    final spaceAbove = dotY - padY;
    final spaceBelow = chartTotalH - dotY - padY;
    double y;
    if (spaceAbove >= cardHeight + margin) {
      y = dotY - margin - cardHeight;
    } else if (spaceBelow >= cardHeight + margin) {
      y = dotY + margin;
    } else {
      // Tight on both sides — pick the larger gap and clamp.
      y = spaceAbove > spaceBelow ? padY : chartTotalH - cardHeight - padY;
    }
    y = y.clamp(padY, chartTotalH - cardHeight - padY).toDouble();

    return (
      x: x,
      y: y,
      portfolioPct: portfolioPct,
      marketPct: marketPct,
      assetRows: assetRows,
    );
  }

  void _selectRange(int idx) {
    // "미래" tab navigates to ProjectionScreen
    if (idx == _rangeLabels.length - 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProjectionScreen()),
      );
      return;
    }
    if (idx == _range) return;
    setState(() {
      _range = idx;
      _touchIndex = null;
    });
    _drawCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final accountSummary = portfolioState.accountSummary;
    final allValue = _allValue;
    final valuePts = _filterByRange(allValue);

    // Compute hero stats from filtered data
    final currentValue = accountSummary?.currentValue ??
        (valuePts.isNotEmpty ? valuePts.last.value : 0.0);
    final startValue = valuePts.isNotEmpty ? valuePts.first.value : 0.0;
    final change = accountSummary?.profitLoss ?? (currentValue - startValue);
    final changePct = accountSummary != null
        ? accountSummary.profitLossPct * 100
        : (startValue > 0 ? (change / startValue) * 100 : 0.0);
    // Compute drag-aware values from touch position
    double? crosshairValue;
    if (_touchIndex != null && _touchIndex! < valuePts.length) {
      crosshairValue = valuePts[_touchIndex!].value;
    }

    // Without a cost-basis line, drag-time deltas are computed against the
    // chart's first visible point (start of the selected range).
    final displayChange =
        crosshairValue != null ? crosshairValue - startValue : change;
    final displayChangePct = crosshairValue != null && startValue > 0
        ? ((crosshairValue - startValue) / startValue) * 100
        : changePct;
    final displayIsPositive = displayChange >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          '현재 자산',
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),

        // Value (animated count-up, updates on drag)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: currentValue),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            final v = crosshairValue ?? val;
            return Text(
              '₩${_formatCurrency(v.toInt())}',
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Performance badge (always visible, values update on drag)
        _PerformanceBadge(
          changePct: displayChangePct,
          changeAmount: displayChange,
          isPositive: displayIsPositive,
          rangeLabel: _rangeLabels[_range],
        ),

        const SizedBox(height: 20),

        // Chart (edge-to-edge)
        LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth + 48;
            // Date label for drag position
            final dateLabel =
                _touchIndex != null && _touchIndex! < valuePts.length
                    ? () {
                        final d = valuePts[_touchIndex!].date;
                        return '${d.year}년 ${d.month}월 ${d.day}일';
                      }()
                    : '';
            // Compute card data when dragging at a non-zero index
            final cardData = _touchIndex != null && _touchIndex! >= 1
                ? _buildCardData(
                    valuePts,
                    fullWidth: fullWidth,
                    stackWidth: constraints.maxWidth,
                  )
                : null;
            return SizedBox(
              height: 320,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  OverflowBox(
                    maxWidth: fullWidth,
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: const Offset(-24, 0),
                      child: GestureDetector(
                        onPanDown: (d) {
                          final x = d.localPosition.dx;
                          final idx = ((x / fullWidth) * (valuePts.length - 1))
                              .round()
                              .clamp(0, valuePts.length - 1);
                          _glowCtrl.repeat(reverse: true);
                          setState(() => _touchIndex = idx);
                        },
                        onPanUpdate: (d) {
                          final x = d.localPosition.dx;
                          final idx = ((x / fullWidth) * (valuePts.length - 1))
                              .round()
                              .clamp(0, valuePts.length - 1);
                          setState(() => _touchIndex = idx);
                        },
                        onPanEnd: (_) {
                          _glowCtrl.stop();
                          _glowCtrl.value = 0;
                          setState(() => _touchIndex = null);
                        },
                        onPanCancel: () {
                          _glowCtrl.stop();
                          _glowCtrl.value = 0;
                          setState(() => _touchIndex = null);
                        },
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_drawCurve, _glowCtrl]),
                          builder: (context, _) {
                            // lines[0] is drawn last (on top); benchmarks
                            // are drawn back-to-front by the painter. Cache
                            // helper outputs so the animation builder
                            // doesn't re-walk comparisonLines + reallocate
                            // every frame.
                            final portfolioPts = _pctSeries(valuePts);
                            final marketPts = _marketSeries(valuePts);
                            final expectedPts =
                                _expectedReturnEndpoints(valuePts);
                            final bondPts = _bondEndpoints(valuePts);
                            return CustomPaint(
                              size: Size(fullWidth, 320),
                              painter: _HomePerformancePainter(
                                lines: [
                                  ChartLine(
                                    key: 'portfolio',
                                    label: '포트폴리오',
                                    color: WeRoboColors.primary,
                                    points: portfolioPts,
                                  ),
                                  if (marketPts.isNotEmpty)
                                    ChartLine(
                                      key: 'market',
                                      label: '시장',
                                      color: tc.textSecondary,
                                      points: marketPts,
                                    ),
                                  if (expectedPts.isNotEmpty)
                                    ChartLine(
                                      key: 'expected',
                                      label: '연 기대수익률',
                                      color: WeRoboColors.primary.withValues(
                                        alpha: 0.5,
                                      ),
                                      dashed: true,
                                      points: expectedPts,
                                    ),
                                  if (bondPts.isNotEmpty)
                                    ChartLine(
                                      // Short form. The comparison chart
                                      // uses '채권 수익률' — the home legend
                                      // keeps the shorter '채권' to fit 4
                                      // entries on a phone.
                                      key: 'bond',
                                      label: '채권',
                                      color: tc.textTertiary.withValues(
                                        alpha: 0.7,
                                      ),
                                      dashed: true,
                                      points: bondPts,
                                    ),
                                ],
                                progress: _drawCurve.value,
                                touchIndex: _touchIndex,
                                glowPhase: _glowCtrl.value,
                                dateLabel: dateLabel,
                                glowColor: WeRoboColors.assetTier3,
                                gridColor: tc.border,
                                crosshairColor: tc.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (cardData != null)
                    Positioned(
                      left: cardData.x,
                      top: cardData.y,
                      child: _DragContextCard(
                        portfolioPct: cardData.portfolioPct,
                        marketPct: cardData.marketPct,
                        assetRows: cardData.assetRows,
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Legend sits ABOVE the range chips, full-width-centered so the
        // four entries balance across the screen rather than hugging the
        // column's start edge.
        SizedBox(
          width: double.infinity,
          child: _ChartLegend(
            entries: [
              (
                label: '포트폴리오',
                color: WeRoboColors.primary,
                dashed: false,
              ),
              (
                label: '시장',
                color: tc.textSecondary,
                dashed: false,
              ),
              (
                label: '연 기대수익률',
                color: WeRoboColors.primary.withValues(alpha: 0.5),
                dashed: true,
              ),
              (
                label: '채권',
                color: tc.textTertiary.withValues(alpha: 0.7),
                dashed: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Time range chips. Inactive chips use tc.textSecondary so they
        // read against the warm-gray app background.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_rangeLabels.length, (i) {
            final active = i == _range;
            final isFuture = i == _rangeLabels.length - 1;

            final chip = GestureDetector(
              onTap: () => _selectRange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active && !isFuture
                      ? WeRoboColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _rangeLabels[i],
                  style: TextStyle(
                    fontFamily: WeRoboFonts.body,
                    fontSize: 12,
                    fontWeight: (isFuture || active)
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isFuture
                        ? WeRoboColors.primary
                        : active
                            ? WeRoboColors.white
                            : tc.textSecondary,
                  ),
                ),
              ),
            );

            final child = isFuture
                ? GlowingBorder(borderRadius: 8, shrinkWrap: true, child: chip)
                : chip;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: child,
            );
          }),
        ),
      ],
    );
  }
}

// ─── Portfolio issue feed ──────────────────────────────────────

class _PortfolioIssueFeed extends StatelessWidget {
  static const _maxItems = 5;

  final MobileDigestResponse? digest;
  final RebalanceInsight? latestInsight;
  final VoidCallback? onDigestTap;
  final VoidCallback? onInsightTap;

  const _PortfolioIssueFeed({
    required this.digest,
    required this.latestInsight,
    this.onDigestTap,
    this.onInsightTap,
  });

  static bool hasItems({
    required MobileDigestResponse? digest,
    required RebalanceInsight? latestInsight,
  }) {
    return digest != null || latestInsight != null;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '포트폴리오 주요 이슈 알림',
          style: WeRoboTypography.bodySmall.copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          key: const Key('portfolio_issue_timeline_rail'),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++)
                _PortfolioIssueRow(
                  item: items[i],
                  index: i,
                  isFirst: i == 0,
                  isLast: i == items.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_PortfolioIssueItem> _buildItems() {
    final items = <_PortfolioIssueItem>[];
    if (digest != null) {
      items.add(_digestStatusItem(digest!, onDigestTap));
    }

    final contribution = _topContribution(digest);
    if (contribution != null) {
      final isPositive = contribution.contributionWon >= 0;
      final periodLabel = _digestPeriodLabel(digest!);
      items.add(
        _PortfolioIssueItem(
          icon: isPositive
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          iconColor: isPositive ? WeRoboColors.accent : WeRoboColors.error,
          eyebrow: periodLabel,
          title: '기여도 알림',
          body: _contributionBody(contribution, periodLabel),
          onTap: onDigestTap,
        ),
      );
    }

    if (_hasVolatilitySignal(digest)) {
      final multiple = digest!.triggerSigmaMultiple!;
      final periodLabel = _digestPeriodLabel(digest!);
      items.add(
        _PortfolioIssueItem(
          icon: Icons.show_chart_rounded,
          iconColor: WeRoboColors.warning,
          eyebrow: '변동성 감지',
          title: '시장 변동성 경고',
          body: '$periodLabel 움직임이 평소보다 ${multiple.toStringAsFixed(1)}배 컸어요.',
          onTap: onDigestTap,
        ),
      );
    }

    if (latestInsight != null) {
      items.add(
        _PortfolioIssueItem(
          icon: Icons.auto_graph_rounded,
          iconColor: WeRoboColors.primary,
          eyebrow: _issueDateLabel(latestInsight!.rebalanceDate),
          title: '알고리즘 시그널',
          body: latestInsight!.historySummary,
          onTap: onInsightTap,
        ),
      );
    }

    if (_hasNewsSignal(digest)) {
      final sources = digest!.sourcesUsed.take(2).join(', ');
      items.add(
        _PortfolioIssueItem(
          icon: Icons.article_outlined,
          iconColor: WeRoboColors.assetTier3,
          eyebrow: '최근 뉴스',
          title: '자산군 뉴스',
          body: '$sources 기반 주요 뉴스가 다이제스트에 반영됐어요.',
          onTap: onDigestTap,
        ),
      );
    }

    return items.take(_maxItems).toList();
  }

  static _PortfolioIssueItem _digestStatusItem(
    MobileDigestResponse digest,
    VoidCallback? onDigestTap,
  ) {
    final available = digest.available;
    final periodLabel = _digestPeriodLabel(digest);
    final pct = _formatSignedPercent(digest.totalReturnPct);
    final won = _formatSignedWon(digest.totalReturnWon);
    return _PortfolioIssueItem(
      icon: available ? Icons.summarize_rounded : Icons.hourglass_empty_rounded,
      iconColor: available ? WeRoboColors.primary : WeRoboColors.textTertiary,
      eyebrow: periodLabel,
      title: _digestTitle(digest),
      body: available
          ? '$periodLabel 수익률 $pct, $won 움직임이 감지됐어요.'
          : '이번 주는 평소 변동 범위 안이라 주요 이슈만 모니터링 중이에요.',
      onTap: available ? onDigestTap : null,
    );
  }

  static String _digestTitle(MobileDigestResponse digest) {
    final periodLabel = _digestPeriodLabel(digest);
    if (periodLabel == '최근 한 달') {
      return '최근 한 달 다이제스트';
    }
    return '이번 주 다이제스트';
  }

  static String _digestPeriodLabel(MobileDigestResponse digest) {
    final start = DateTime.tryParse(digest.periodStart);
    final end = DateTime.tryParse(digest.periodEnd);
    if (start == null || end == null) return '최근 7일';
    final days = end.difference(start).inDays.abs();
    if (days >= 27) return '최근 한 달';
    if (days >= 10) return '최근 $days일';
    return '최근 7일';
  }

  static DigestDriver? _topContribution(MobileDigestResponse? digest) {
    if (digest?.available != true) return null;
    final items = [
      ...digest!.drivers,
      ...digest.detractors,
    ]..sort(
        (a, b) => b.contributionWon.abs().compareTo(a.contributionWon.abs()),
      );
    return items.isEmpty ? null : items.first;
  }

  static bool _hasVolatilitySignal(MobileDigestResponse? digest) {
    final multiple = digest?.triggerSigmaMultiple;
    return digest?.available == true && multiple != null && multiple >= 2;
  }

  static bool _hasNewsSignal(MobileDigestResponse? digest) {
    return digest?.available == true && digest!.sourcesUsed.isNotEmpty;
  }

  static String _contributionBody(DigestDriver driver, String periodLabel) {
    final name = driver.nameKo.isNotEmpty ? driver.nameKo : driver.ticker;
    final won = _formatSignedWon(driver.contributionWon);
    if (driver.contributionWon >= 0) {
      return '$name가 $periodLabel 수익에 $won 기여했어요.';
    }
    return '$name가 $periodLabel 수익에 $won 영향을 줬어요.';
  }

  static String _issueDateLabel(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return '최근 신호';
    return '${parsed.month}월 ${parsed.day}일';
  }
}

class _PortfolioIssueItem {
  final IconData icon;
  final Color iconColor;
  final String eyebrow;
  final String title;
  final String body;
  final VoidCallback? onTap;

  const _PortfolioIssueItem({
    required this.icon,
    required this.iconColor,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.onTap,
  });
}

class _PortfolioIssueRow extends StatelessWidget {
  final _PortfolioIssueItem item;
  final int index;
  final bool isFirst;
  final bool isLast;

  const _PortfolioIssueRow({
    required this.item,
    required this.index,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 34,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: isFirst ? 18 : 0,
                    bottom: isLast ? 42 : 0,
                    child: Container(
                      width: 1,
                      color: tc.border.withValues(alpha: 0.30),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    child: Container(
                      key: ValueKey('portfolio_issue_timeline_node_$index'),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.iconColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: item.iconColor.withValues(alpha: 0.34),
                          width: 1,
                        ),
                      ),
                      child: Icon(item.icon, size: 15, color: item.iconColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.eyebrow,
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (item.onTap != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: tc.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (item.onTap == null) return row;
    return Pressable(onTap: item.onTap!, child: row);
  }
}

// ─── Performance badge ────────────────────────────────────────

class _PerformanceBadge extends StatelessWidget {
  final double changePct;
  final double changeAmount;
  final bool isPositive;
  final String rangeLabel;

  const _PerformanceBadge({
    required this.changePct,
    required this.changeAmount,
    required this.isPositive,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final color = isPositive ? tc.accent : WeRoboColors.error;
    final arrow = isPositive ? '▲' : '▼';

    return Text(
      '$arrow ₩${_formatCurrency(changeAmount.abs().toInt())} (${changePct.abs().toStringAsFixed(1)}%) $rangeLabel',
      style: TextStyle(
        fontFamily: WeRoboFonts.english,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

// ─── Multi-line % return chart painter ───────────────────────

class _HomePerformancePainter extends CustomPainter {
  /// Lines to draw. The portfolio line (index 0) is drawn last and sits
  /// on top of every benchmark. Benchmarks at higher indices are drawn
  /// earlier and therefore sit below benchmarks at lower indices.
  final List<ChartLine> lines;
  final double progress;
  final int? touchIndex;
  final double glowPhase;
  final String dateLabel;
  final Color glowColor;
  final Color gridColor;
  final Color crosshairColor;

  _HomePerformancePainter({
    required this.lines,
    required this.progress,
    this.touchIndex,
    this.glowPhase = 0,
    required this.dateLabel,
    required this.glowColor,
    required this.gridColor,
    required this.crosshairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || lines.first.points.length < 2) return;

    final w = size.width;
    final h = size.height;
    final isDragging = touchIndex != null;
    const lineTopPad = 16.0;
    const graphTopPad = 36.0;
    const graphBotPad = 50.0;
    final chartH = h - graphTopPad - graphBotPad;

    // Y-range across all lines (% space — symmetric padding).
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final p in line.points) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
    }
    if (minY == double.infinity) return;
    final range = (maxY - minY).clamp(0.0001, double.infinity);
    minY -= range * 0.05;
    maxY += range * 0.05;
    final rangeY = maxY - minY;

    final basePts = lines.first.points;
    double toX(int i, int total) => w * i / (total - 1);
    double toY(double val) =>
        graphTopPad + chartH - ((val - minY) / rangeY) * chartH;

    // Grid lines — dimmed to 0.08 (was 0.15) so the chart reads
    // "no Y axis" while keeping spatial reference.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = graphTopPad + chartH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final fIdx = (basePts.length - 1) * progress.clamp(0.0, 1.0);
    final complete = fIdx.floor();
    final frac = fIdx - complete;
    final drawCount = (complete + 1).clamp(2, basePts.length);
    // The animation cursor (drives left-to-right reveal) is decoupled
    // from the drag cursor — drag only moves the crosshair / glow dot,
    // it never clips or fades the lines themselves. So `ti` is purely
    // the touch index when dragging (used by the crosshair); benchmark
    // and portfolio drawing use `drawCount` based on `progress`.
    final ti =
        isDragging ? touchIndex!.clamp(0, basePts.length - 1) : drawCount - 1;

    // Draw benchmarks first (behind portfolio). Map by DATE — benchmark
    // series may have a different point count than the portfolio (e.g.,
    // 2-point projection lines, or shorter market data). Index-based
    // mapping squashes 2-point lines to a stub at x=0 and ends shorter
    // series early.
    final minDate = basePts.first.date;
    final maxDate = basePts.last.date;
    final animCursorIdx = math.min(drawCount - 1, basePts.length - 1);
    final drawnUpToDate = basePts[animCursorIdx].date;
    for (var lineIdx = lines.length - 1; lineIdx >= 1; lineIdx--) {
      _drawBenchmarkLine(
        canvas,
        lines[lineIdx],
        minDate,
        maxDate,
        drawnUpToDate,
        w,
        toY,
      );
    }

    // Portfolio line on top. Always drawn fully per the animation cursor
    // — drag moves the crosshair only, it does not clip or fade the line.
    _drawPortfolioLine(
      canvas,
      lines.first.points,
      lines.first.color,
      basePts.length,
      drawCount,
      complete,
      frac,
      toX,
      toY,
    );

    // Crosshair + glow + date label (only when dragging).
    if (isDragging) {
      _drawCrosshair(
        canvas,
        size,
        ti,
        basePts.length,
        toX,
        toY,
        lines.first.points,
        drawCount,
        lineTopPad,
      );
    }
  }

  void _drawBenchmarkLine(
    Canvas canvas,
    ChartLine line,
    DateTime minDate,
    DateTime maxDate,
    DateTime drawnUpToDate,
    double w,
    double Function(double) toY,
  ) {
    final pts = line.points;
    if (pts.length < 2) return;
    final totalMs = maxDate.difference(minDate).inMilliseconds;
    if (totalMs <= 0) return;

    double xForDate(DateTime d) {
      final elapsedMs = d.difference(minDate).inMilliseconds;
      return w * (elapsedMs / totalMs).clamp(0.0, 1.0);
    }

    final path = Path();
    var moved = false;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      if (!p.date.isAfter(drawnUpToDate)) {
        // Point fully revealed by the animation cursor.
        final x = xForDate(p.date);
        final y = toY(p.value);
        if (!moved) {
          path.moveTo(x, y);
          moved = true;
        } else {
          path.lineTo(x, y);
        }
      } else if (moved) {
        // Animation cursor falls inside this segment — interpolate
        // proportionally so the line grows in lock-step with the
        // portfolio's draw-in animation.
        final p0 = pts[i - 1];
        final segMs = p.date.difference(p0.date).inMilliseconds;
        if (segMs > 0) {
          final fracMs = drawnUpToDate.difference(p0.date).inMilliseconds;
          final frac = (fracMs / segMs).clamp(0.0, 1.0);
          final x0 = xForDate(p0.date);
          final x1 = xForDate(p.date);
          final y0 = toY(p0.value);
          final y1 = toY(p.value);
          path.lineTo(x0 + frac * (x1 - x0), y0 + frac * (y1 - y0));
        }
        break;
      } else {
        // First point already past the cursor — nothing to draw yet.
        return;
      }
    }
    if (!moved) return;

    final paint = Paint()
      ..color = line.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (line.dashed) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawPortfolioLine(
    Canvas canvas,
    List<ChartPoint> pts,
    Color color,
    int totalPts,
    int drawCount,
    int complete,
    double frac,
    double Function(int, int) toX,
    double Function(double) toY,
  ) {
    final fullPath = Path();
    for (int i = 0; i <= complete; i++) {
      final x = toX(i, totalPts);
      final y = toY(pts[i].value);
      if (i == 0) {
        fullPath.moveTo(x, y);
      } else {
        fullPath.lineTo(x, y);
      }
    }
    if (frac > 0 && complete < pts.length - 1) {
      final x0 = toX(complete, totalPts);
      final y0 = toY(pts[complete].value);
      final x1 = toX(complete + 1, totalPts);
      final y1 = toY(pts[complete + 1].value);
      fullPath.lineTo(x0 + frac * (x1 - x0), y0 + frac * (y1 - y0));
    }
    canvas.drawPath(
      fullPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawCrosshair(
    Canvas canvas,
    Size size,
    int ti,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    List<ChartPoint> portfolioPts,
    int drawCount,
    double lineTopPad,
  ) {
    final w = size.width;
    final h = size.height;
    final tx = toX(ti, totalPts);
    final lineTop = lineTopPad;
    final lineBot = h - lineTopPad;
    final lineShader = ui.Gradient.linear(
      Offset(tx, lineTop),
      Offset(tx, lineBot),
      [
        gridColor.withValues(alpha: 0.12),
        crosshairColor.withValues(alpha: 0.55),
        crosshairColor.withValues(alpha: 0.55),
        gridColor.withValues(alpha: 0.12),
      ],
      [0.0, 0.12, 0.88, 1.0],
    );
    canvas.drawLine(
      Offset(tx, lineTop),
      Offset(tx, lineBot),
      Paint()
        ..shader = lineShader
        ..strokeWidth = 0.8,
    );

    if (dateLabel.isNotEmpty) {
      final dateTp = TextPainter(
        text: TextSpan(
          text: dateLabel,
          style: TextStyle(
            fontSize: 10,
            color: crosshairColor.withValues(alpha: 0.85),
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dateX = (tx - dateTp.width / 2).clamp(4.0, w - dateTp.width - 4);
      dateTp.paint(canvas, Offset(dateX, lineTop - dateTp.height - 2));
    }

    if (ti < drawCount && ti < portfolioPts.length) {
      final vy = toY(portfolioPts[ti].value);
      final glowRadius = 14 + 4 * glowPhase;
      final glowAlpha = 0.25 + 0.15 * glowPhase;
      canvas.drawCircle(
        Offset(tx, vy),
        glowRadius,
        Paint()
          ..color = glowColor.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(tx, vy),
        4,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(Offset(tx, vy), 3, Paint()..color = Colors.white);
    }
  }

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

  @override
  bool shouldRepaint(covariant _HomePerformancePainter old) =>
      old.progress != progress ||
      old.touchIndex != touchIndex ||
      old.glowPhase != glowPhase;
  // `lines` is freshly constructed every build (new list, new ChartLine
  // instances) so reference equality is always false — we'd always
  // repaint. Range/data changes already trigger a setState that
  // unconditionally rebuilds, so omitting `lines` here is safe.
}

// ─── Chart legend ─────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final bool dashed;
  const _LegendDot({required this.color, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 2,
      child: CustomPaint(
        painter: _LegendDotPainter(color: color, dashed: dashed),
      ),
    );
  }
}

class _LegendDotPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LegendDotPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dashed) {
      // 3-on/2-off dash pattern within the 12 px sample
      const dashLen = 3.0;
      const gapLen = 2.0;
      double x = 0;
      while (x < size.width) {
        final end = math.min(x + dashLen, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x = end + gapLen;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendDotPainter old) =>
      old.color != color || old.dashed != dashed;
}

class _ChartLegend extends StatelessWidget {
  final List<({String label, Color color, bool dashed})> entries;
  const _ChartLegend({required this.entries});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendDot(color: e.color, dashed: e.dashed),
              const SizedBox(width: 4),
              Text(
                e.label,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Drag context card ────────────────────────────────────────

class _DragContextCard extends StatelessWidget {
  final double portfolioPct;
  final double? marketPct;
  final List<({String name, double pct})> assetRows;

  const _DragContextCard({
    required this.portfolioPct,
    required this.marketPct,
    required this.assetRows,
  });

  /// Fixed width bounds the row's Expanded label inside a Positioned
  /// (which provides loose constraints). Height is a max-case upper
  /// bound used by `_buildCardData` for the gap-from-line placement —
  /// the actual card sizes to its content via `mainAxisSize.min`, so
  /// rows with no asset breakdown make it shorter.
  static const double width = 150.0;
  static const double height = 110.0;

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    // Frosted-glass annotation. The BackdropFilter blurs the chart lines
    // visible behind the card so they read as soft ghosts — the card
    // never opaquely blocks them, while still giving the numbers enough
    // contrast to scan. No explicit border: the blur edge + alpha
    // surface implies the boundary without adding chrome.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          color: tc.surface.withValues(alpha: 0.62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DragContextRow(label: '포트폴리오', pct: portfolioPct),
              if (marketPct != null)
                _DragContextRow(label: '시장', pct: marketPct!),
              if (assetRows.isNotEmpty) const SizedBox(height: 4),
              for (final row in assetRows)
                _DragContextRow(label: row.name, pct: row.pct),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragContextRow extends StatelessWidget {
  final String label;
  final double pct;
  const _DragContextRow({
    required this.label,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final color = pct >= 0 ? tc.accent : WeRoboColors.error;
    final sign = pct >= 0 ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: WeRoboFonts.body,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: tc.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${(pct * 100).abs().toStringAsFixed(2)}%',
            style: TextStyle(
              fontFamily: WeRoboFonts.english,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────

String _formatCurrency(int amount) {
  final str = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

String _formatSignedWon(double amount) {
  final sign = amount >= 0 ? '+' : '-';
  return '$sign₩${_formatCurrency(amount.abs().round())}';
}

String _formatSignedPercent(double percentage) {
  final sign = percentage >= 0 ? '+' : '-';
  return '$sign${percentage.abs().toStringAsFixed(1)}%';
}

String _formatPercentLabel(double percentage) {
  return '${percentage.toStringAsFixed(2)}%';
}

String _formatWonFromRatio(double? baseValue, double percentage) {
  if (baseValue == null || baseValue <= 0) {
    return '-';
  }
  final amount = (baseValue * percentage / 100).round();
  return '₩${_formatCurrency(amount)}';
}

String _formatWonAmount(double? amount) {
  if (amount == null) {
    return '-';
  }
  return '₩${_formatCurrency(amount.round())}';
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
  final nextDay = math.min(date.day, lastDayOfNextMonth);
  return DateTime(nextYear, nextMonth, nextDay);
}

String _formatKoreanMonthDay(DateTime date) {
  return '${date.month}월 ${date.day}일';
}

// ─── Welcome banner ───────────────────────────────────────────

// ─── Insight banner ──────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  final RebalanceInsight latestInsight;
  final int unreadCount;

  const _InsightBanner({
    required this.latestInsight,
    required this.unreadCount,
  });

  String _formatKoreanDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return '${date.year}년 ${date.month}월';
  }

  String _summaryText() {
    final allocs = latestInsight.allocations;
    if (allocs.isEmpty) return '포트폴리오 비중을 조정했어요.';

    // Find the allocation with the largest absolute display delta
    RebalanceInsightAllocation biggest = allocs.first;
    for (final a in allocs) {
      if (a.displayDelta.abs() > biggest.displayDelta.abs()) {
        biggest = a;
      }
    }

    if (!biggest.hasChanged) {
      return '포트폴리오 비중을 조정했어요.';
    }

    final pct = biggest.displayDelta.abs().toStringAsFixed(1);
    if (biggest.displayDelta > 0) {
      return '${biggest.displayName} 비중을 $pct% 늘렸어요.';
    }
    return '${biggest.displayName} 비중을 $pct% 줄였어요.';
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);

    return Pressable(
      onTap: () {
        Navigator.push(
          context,
          WeRoboMotion.fadeRoute<void>(
            InsightDetailPage(insight: latestInsight),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Icon
            InsightDonutThumbnail(
              allocations: latestInsight.allocations,
              size: 40,
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'New · ${_formatKoreanDate(latestInsight.rebalanceDate)}',
                        style: WeRoboTypography.caption.copyWith(
                          color: tc.textTertiary,
                        ),
                      ),
                      if (unreadCount > 1) ...[
                        Text(
                          '  ·  ',
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                        Text(
                          '+${unreadCount - 1}개 더 보기',
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _summaryText(),
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(Icons.chevron_right_rounded, size: 18, color: tc.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Welcome banner ─────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final InvestmentType type;
  final VoidCallback onDismiss;

  const _WelcomeBanner({required this.type, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WeRoboColors.primary,
            WeRoboColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.label} 포트폴리오가 설정되었습니다!',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: WeRoboColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '투자 여정을 시작해 보세요',
                  style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: WeRoboColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
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
              : '₩${_formatCurrency(latestAmount.round())}'
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
              : '₩${_formatCurrency(upcomingAmount.round())}'
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

class _PortfolioAllocationPanel extends StatelessWidget {
  final List<PortfolioCategoryDetail> details;
  final double? baseValue;
  final bool showAmounts;
  final bool hasResolvedPortfolio;
  final ValueChanged<bool> onValueModeChanged;

  const _PortfolioAllocationPanel({
    required this.details,
    required this.baseValue,
    required this.showAmounts,
    required this.hasResolvedPortfolio,
    required this.onValueModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 16),
        if (details.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              hasResolvedPortfolio
                  ? '자산군 비중 데이터가 아직 없습니다.'
                  : '포트폴리오 데이터를 불러오는 중입니다.',
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textSecondary,
              ),
            ),
          )
        else
          ...List.generate(details.length, (index) {
            final detail = details[index];
            return Column(
              children: [
                _PortfolioAllocationRow(
                  detail: detail,
                  baseValue: baseValue,
                  showAmounts: showAmounts,
                  onTap: () => _openAllocationDetailPage(context, detail),
                ),
                Divider(
                  color: tc.border.withValues(alpha: 0.4),
                  height: 1,
                  thickness: 0.5,
                ),
              ],
            );
          }),
        const SizedBox(height: 16),
        Pressable(
          onTap: () {},
          child: Text(
            '포트폴리오 조정',
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
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
                      '₩',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: showAmounts ? tc.textPrimary : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
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

// ─── Digest banner ──────────────────────────────────────────

class _DigestBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DigestBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GlowingBorder(
      borderRadius: WeRoboColors.radiusXL,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WeRoboColors.primary.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: WeRoboColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주간 다이제스트',
                      style: WeRoboTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI가 분석한 이번 주 포트폴리오 리포트',
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tc.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Notification icon ──────────────────────────────────────

class _NotificationIconButton extends StatelessWidget {
  final bool hasUnread;
  const _NotificationIconButton({this.hasUnread = false});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: () => Navigator.push(
        context,
        WeRoboMotion.fadeRoute<void>(const ActivityHubPage()),
      ),
      child: Icon(
        hasUnread
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded,
        size: 24,
        color: tc.textSecondary,
      ),
    );
  }
}
