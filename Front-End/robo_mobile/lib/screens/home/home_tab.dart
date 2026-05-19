import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'widgets/digest_sheet.dart';
import 'insight_detail_page.dart';
import 'range_digest_detail_page.dart';
import 'widgets/glowing_border.dart';
import 'projection_screen.dart';
import 'widgets/insight_transition_chart.dart';

// Korean convention (per Eugene): red for gain, blue for loss. This is the
// opposite of the Korean stock sign convention but matches the meeting spec.
// Values from the UIUX-2026-05-20 spec.
const Color _gainColor = Color(0xFFFF0200);
const Color _lossColor = Color(0xFF267ACF);

typedef RangeDigestApiOverride = Future<MobileRangeDigestResponse> Function({
  required String accessToken,
  required DateTime startDate,
  required DateTime endDate,
  required double startValue,
  required double endValue,
});

RangeDigestApiOverride? _rangeDigestApiOverride;

@visibleForTesting
void debugSetRangeDigestApiOverride(RangeDigestApiOverride? override) {
  _rangeDigestApiOverride = override;
}

Map<String, double> earningsHistoryWeightsFor(
  MobilePortfolioRecommendation portfolio,
) {
  final weights = <String, double>{};
  for (final allocation in portfolio.stockAllocations) {
    final ticker = allocation.ticker.trim().toUpperCase();
    final weight = allocation.weight;
    if (ticker.isEmpty || weight <= 0) {
      continue;
    }
    weights[ticker] = (weights[ticker] ?? 0) + weight;
  }
  return weights;
}

// Backend returns each point's `asset_earnings` as **cumulative gain** per
// asset (starts at 0). Downstream consumers (drag context card,
// topContributorOver30d) treat values as **absolute portfolio value per
// asset** (base + gain). Convert here at the API boundary so both views see
// the same semantics as the mock fixture. See note in mock_earnings_data.dart.
MobileEarningsHistoryResponse _earningsHistoryAsAbsolute(
  MobileEarningsHistoryResponse r,
) {
  final base = <String, double>{
    for (final s in r.assetSummary) s.assetCode: s.weight * r.investmentAmount,
  };
  if (base.isEmpty) return r;
  return MobileEarningsHistoryResponse(
    points: [
      for (final p in r.points)
        MobileEarningsPoint(
          date: p.date,
          totalEarnings: p.totalEarnings,
          totalReturnPct: p.totalReturnPct,
          assetEarnings: {
            for (final e in p.assetEarnings.entries)
              if (base.containsKey(e.key)) e.key: base[e.key]! + e.value,
          },
        ),
    ],
    investmentAmount: r.investmentAmount,
    startDate: r.startDate,
    endDate: r.endDate,
    totalReturnPct: r.totalReturnPct,
    totalEarnings: r.totalEarnings,
    assetSummary: r.assetSummary,
  );
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  late final ScrollController _scrollController;
  bool _earningsHistoryFetchStarted = false;
  bool _isRangeDigestMode = false;
  _ChartRangeSelection? _selectedDigestRange;
  MobileRangeDigestResponse? _rangeDigest;
  bool _rangeDigestLoading = false;
  String? _rangeDigestError;
  int _rangeDigestRequestId = 0;
  String? _loadedEarningsRiskCode;

  @override
  void initState() {
    super.initState();
    logPageEnter('HomeTab');
    _scrollController = ScrollController();
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    logPageExit('HomeTab');
    _staggerCtrl.dispose();
    _scrollController.dispose();
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
    final weights = earningsHistoryWeightsFor(selected);
    if (weights.isEmpty) {
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
        weights: weights,
        startDate: startedAt,
      );
      if (!mounted) return;
      state.setEarningsHistory(_earningsHistoryAsAbsolute(response));
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

  void _enterRangeDigestMode() {
    setState(() {
      _isRangeDigestMode = true;
      _selectedDigestRange = null;
      _rangeDigest = null;
      _rangeDigestLoading = false;
      _rangeDigestError = null;
      _rangeDigestRequestId++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: WeRoboMotion.medium,
        curve: WeRoboMotion.enter,
      );
    });
  }

  void _exitRangeDigestMode() {
    setState(() {
      _isRangeDigestMode = false;
      _selectedDigestRange = null;
      _rangeDigest = null;
      _rangeDigestLoading = false;
      _rangeDigestError = null;
      _rangeDigestRequestId++;
    });
  }

  void _setDigestRange(_ChartRangeSelection? selection) {
    if (selection == null) {
      setState(() {
        _selectedDigestRange = null;
        _rangeDigest = null;
        _rangeDigestLoading = false;
        _rangeDigestError = null;
        _rangeDigestRequestId++;
      });
      return;
    }
    setState(() => _selectedDigestRange = selection);
    _loadRangeDigest(selection);
  }

  Future<void> _loadRangeDigest(_ChartRangeSelection selection) async {
    final state = PortfolioStateProvider.of(context);
    final accessToken = state.authSession?.accessToken;
    final requestId = ++_rangeDigestRequestId;
    if (accessToken == null || accessToken.isEmpty) {
      setState(() {
        _rangeDigest = null;
        _rangeDigestLoading = false;
        _rangeDigestError = '로그인이 필요해요.';
      });
      return;
    }

    setState(() {
      _rangeDigest = null;
      _rangeDigestLoading = true;
      _rangeDigestError = null;
    });

    try {
      final fetchRangeDigest =
          _rangeDigestApiOverride ?? MobileBackendApi.instance.fetchRangeDigest;
      final digest = await fetchRangeDigest(
        accessToken: accessToken,
        startDate: selection.startDate,
        endDate: selection.endDate,
        startValue: selection.startValue,
        endValue: selection.endValue,
      );
      if (!mounted || requestId != _rangeDigestRequestId) return;
      setState(() {
        _rangeDigest = digest;
        _rangeDigestLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _rangeDigestRequestId) return;
      developer.log(
        'fetchRangeDigest failed: $e',
        name: 'HomeTab',
      );
      setState(() {
        _rangeDigest = null;
        _rangeDigestLoading = false;
        _rangeDigestError = '분석을 불러오지 못했어요.';
      });
    }
  }

  void _openRangeDigestDetail() {
    final digest = _rangeDigest;
    if (digest == null) return;
    Navigator.push(
      context,
      WeRoboMotion.fadeRoute<void>(
        RangeDigestDetailPage(digest: digest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final type = state.type;
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
        key: const Key('home_tab_scroll'),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Wordmark only — the notification bell lives in HomeShell as a
            // global overlay (UIUX 2026-05-20 spec). Right-pad so the
            // wordmark doesn't sit underneath the bell.
            Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WeRobo',
                  key: const Key('home_werobo_logo'),
                  style: WeRoboTypography.logo.copyWith(
                    color: WeRoboColors.primary,
                    fontSize: 22,
                    height: 1.1,
                  ),
                ),
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
              _PortfolioHeroChart(
                type: type,
                digest: issueDigest,
                rangeDigestMode: _isRangeDigestMode,
                rangeDigestLocked: _selectedDigestRange != null,
                selectedDigestRange: _selectedDigestRange,
                onRangeSelectionChanged: _setDigestRange,
                onEnterRangeDigestMode: _enterRangeDigestMode,
                onExitRangeDigestMode: _exitRangeDigestMode,
              ),
            ),
            if (hasIssueFeed) const SizedBox(height: 16),
            if (hasIssueFeed)
              _stagger(
                ++staggerIdx,
                _PortfolioIssueFeed(
                  digest: issueDigest,
                  latestInsight: issueInsight,
                  dailyReturn: state.dailyReturn,
                  dailyContributors: state.topContributorsOverDay(2),
                  rangeDigestMode: _isRangeDigestMode,
                  selectedDigestRange: _selectedDigestRange,
                  rangeDigest: _rangeDigest,
                  rangeDigestLoading: _rangeDigestLoading,
                  rangeDigestError: _rangeDigestError,
                  onExitRangeDigestMode: _exitRangeDigestMode,
                  onRetryRangeDigest: _selectedDigestRange == null
                      ? null
                      : () => _loadRangeDigest(_selectedDigestRange!),
                  onRangeDigestDetailTap: _openRangeDigestDetail,
                  onDigestTap: issueData.usesPlaceholderDigest
                      ? null
                      : () => DigestSheet.show(context),
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
                  onTap: () => DigestSheet.show(context),
                ),
              ),
            if (hasStandaloneDigestBanner) const SizedBox(height: 20),

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

  const _HomeIssueFeedData({
    required this.digest,
    required this.latestInsight,
    required this.usesPlaceholderDigest,
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
      );
    }

    final usePlaceholderDigest = liveDigest == null || !liveDigest.available;

    return _HomeIssueFeedData(
      digest: usePlaceholderDigest ? _placeholderDigest : liveDigest,
      latestInsight: liveInsight ?? _placeholderInsight,
      usesPlaceholderDigest: usePlaceholderDigest,
    );
  }
}

// ─── Hero chart: value + chart + time range ─────────

class _PortfolioHeroChart extends StatefulWidget {
  final InvestmentType type;
  final MobileDigestResponse? digest;
  final bool rangeDigestMode;
  final bool rangeDigestLocked;
  final _ChartRangeSelection? selectedDigestRange;
  final ValueChanged<_ChartRangeSelection?> onRangeSelectionChanged;
  final VoidCallback onEnterRangeDigestMode;
  final VoidCallback onExitRangeDigestMode;

  const _PortfolioHeroChart({
    required this.type,
    this.digest,
    required this.rangeDigestMode,
    required this.rangeDigestLocked,
    required this.selectedDigestRange,
    required this.onRangeSelectionChanged,
    required this.onEnterRangeDigestMode,
    required this.onExitRangeDigestMode,
  });

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
  int? _rangeStartIndex;
  int? _rangeEndIndex;
  bool _rangeSelectionLocked = false;
  // Cache of cumulative asset returns since the start of the visible
  // range, keyed by date. Rebuilt when the range changes or the earnings
  // history reference changes.
  int? _cumulativeCacheRange;
  Object? _cumulativeCacheHistoryRef;
  DateTime? _cumulativeCacheStartDate;
  List<MapEntry<DateTime, Map<String, double>>>? _cumulativeCache;

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
      _rangeStartIndex = null;
      _rangeEndIndex = null;
      _rangeSelectionLocked = false;
      _drawCtrl.forward(from: 0);
    }
    if (oldWidget.rangeDigestMode != widget.rangeDigestMode) {
      _touchIndex = null;
      _glowCtrl.stop();
      _glowCtrl.value = 0;
      if (!widget.rangeDigestMode) {
        _rangeStartIndex = null;
        _rangeEndIndex = null;
        _rangeSelectionLocked = false;
      }
    }
    if (widget.rangeDigestMode &&
        oldWidget.selectedDigestRange != null &&
        widget.selectedDigestRange == null) {
      _rangeStartIndex = null;
      _rangeEndIndex = null;
      _rangeSelectionLocked = false;
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

  Map<String, String> _assetReturnLabels(PortfolioState state) {
    final labels = <String, String>{};

    void addLabel(String code, String label) {
      final trimmedCode = code.trim();
      if (trimmedCode.isEmpty) return;
      final trimmedLabel = label.trim();
      final display = trimmedLabel.isEmpty ? trimmedCode : trimmedLabel;
      labels.putIfAbsent(trimmedCode, () => display);
      labels.putIfAbsent(trimmedCode.toUpperCase(), () => display);
    }

    final portfolio = state.selectedPortfolio;
    for (final sector
        in portfolio?.sectorAllocations ?? const <MobileSectorAllocation>[]) {
      addLabel(sector.assetCode, sector.assetName);
    }
    for (final stock
        in portfolio?.stockAllocations ?? const <MobileStockAllocation>[]) {
      final ticker = stock.ticker.trim().toUpperCase();
      addLabel(ticker, ticker);
    }
    for (final summary in state.earningsHistory?.assetSummary ??
        const <MobileAssetEarningSummary>[]) {
      addLabel(summary.assetCode, summary.assetName);
    }

    return labels;
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

  /// Cumulative per-asset returns from the start of the visible range up
  /// to [valuePts]\[ti], computed by compounding the day-over-day values
  /// from the earnings history. Cached per range and per history snapshot
  /// so the cost is paid once per visible range, not per drag frame.
  Map<String, double> _cumulativeAssetReturnsLocal(
    List<ChartPoint> valuePts,
    int ti,
  ) {
    if (valuePts.isEmpty || ti < 1 || ti >= valuePts.length) {
      return const {};
    }
    final state = PortfolioStateProvider.of(context);
    final history = state.earningsHistory;
    if (history == null || history.points.length < 2) return const {};
    final startDate = valuePts.first.date;
    final needsRebuild = _cumulativeCache == null ||
        _cumulativeCacheRange != _range ||
        !identical(_cumulativeCacheHistoryRef, history) ||
        _cumulativeCacheStartDate != startDate;
    if (needsRebuild) {
      _cumulativeCacheRange = _range;
      _cumulativeCacheHistoryRef = history;
      _cumulativeCacheStartDate = startDate;
      _cumulativeCache = _buildCumulativeCache(history.points, startDate);
    }
    final cache = _cumulativeCache!;
    if (cache.isEmpty) return const {};
    final targetDate = valuePts[ti].date;
    // Find the last cache entry with date <= targetDate. Binary search
    // would be tidier; the cache is small (one entry per trading day in
    // the visible range) so a linear scan is fine.
    Map<String, double>? best;
    for (final entry in cache) {
      if (entry.key.isAfter(targetDate)) break;
      best = entry.value;
    }
    return best ?? const {};
  }

  List<MapEntry<DateTime, Map<String, double>>> _buildCumulativeCache(
    List<MobileEarningsPoint> points,
    DateTime startDate,
  ) {
    // Locate the first earnings-history point at or after the visible
    // range's start date.
    var startIdx = points.indexWhere((p) => !p.date.isBefore(startDate));
    if (startIdx < 0) return const [];
    // Use that point's values as the baseline. Each subsequent point's
    // cumulative return is the compound product of day-over-day returns
    // from the prior point, which equals (current - base) / base when
    // base is the starting value. Direct subtraction is cheaper and is
    // mathematically equivalent.
    final baseValues = points[startIdx].assetEarnings;
    final result = <MapEntry<DateTime, Map<String, double>>>[];
    result.add(MapEntry(points[startIdx].date, const {}));
    for (var i = startIdx + 1; i < points.length; i++) {
      final current = points[i].assetEarnings;
      final cumulative = <String, double>{};
      current.forEach((code, value) {
        final baseValue = baseValues[code];
        if (baseValue == null || baseValue == 0) return;
        cumulative[code] = (value - baseValue) / baseValue;
      });
      result.add(MapEntry(points[i].date, cumulative));
    }
    return result;
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

    // Cumulative portfolio % since the start of the visible range. Matches
    // the hero numbers above the chart so the drag card never tells a
    // different story than the headline.
    final base = valuePts.first.value;
    if (base == 0) return null;
    final portfolioPct = (valuePts[ti].value - base) / base;

    // Cumulative market % at the touched date. _marketSeries already
    // rebases to 0% at the first visible point, so we read directly.
    final state = PortfolioStateProvider.of(context);
    double? marketPct;
    final mPts = _marketSeries(valuePts);
    if (mPts.isNotEmpty) {
      final touchDate = valuePts[ti].date;
      final mIdx = mPts.indexWhere((p) => !p.date.isBefore(touchDate));
      marketPct = mIdx >= 0 ? mPts[mIdx].value : mPts.last.value;
    }

    // Cumulative asset returns since the start of the visible range,
    // computed by compounding day-over-day returns from the earnings
    // history up to the touched date.
    // TODO: move to PortfolioState.cumulativeAssetReturnsUpTo for shared
    // caching across screens.
    final assetReturns = _cumulativeAssetReturnsLocal(valuePts, ti);
    final labels = _assetReturnLabels(state);
    final entries = assetReturns.entries
        .map((e) => (
              name: labels[e.key] ?? labels[e.key.toUpperCase()] ?? e.key,
              pct: e.value,
            ))
        .toList();
    // Highest contribution first either way. In up days these are the
    // top gainers. In down days these are the assets that defended best
    // (least negative, sometimes positive), surfacing strength rather
    // than dwelling on the biggest losses.
    entries.sort((a, b) => b.pct.compareTo(a.pct));
    // When the portfolio is exactly flat at this point, the underlying
    // account history likely repeated yesterday's snapshot (non-trading
    // day or sparse backend data). Showing per-asset movement on the same
    // day contradicts the 0% portfolio number and confuses readers.
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

  int _indexForChartX(double x, double fullWidth, int pointCount) {
    if (pointCount <= 1) return 0;
    return ((x / fullWidth) * (pointCount - 1))
        .round()
        .clamp(0, pointCount - 1)
        .toInt();
  }

  bool get _isRangeSelectionLocked =>
      _rangeSelectionLocked || widget.rangeDigestLocked;

  void _beginRangeSelectionAt(
    double x,
    double fullWidth,
    List<ChartPoint> valuePts,
  ) {
    if (_isRangeSelectionLocked || valuePts.length < 2) return;
    final idx = _indexForChartX(x, fullWidth, valuePts.length);
    setState(() {
      _touchIndex = null;
      _rangeStartIndex = idx;
      _rangeEndIndex = idx;
    });
  }

  void _updateRangeSelectionAt(
    double x,
    double fullWidth,
    List<ChartPoint> valuePts,
  ) {
    if (_isRangeSelectionLocked ||
        valuePts.length < 2 ||
        _rangeStartIndex == null) {
      return;
    }
    final idx = _indexForChartX(x, fullWidth, valuePts.length);
    setState(() => _rangeEndIndex = idx);
  }

  void _completeRangeSelection(List<ChartPoint> valuePts) {
    if (_isRangeSelectionLocked) return;
    final startIdx = _rangeStartIndex;
    final endIdx = _rangeEndIndex;
    if (valuePts.length < 2 || startIdx == null || endIdx == null) {
      widget.onRangeSelectionChanged(null);
      return;
    }

    final normalizedStart = math.min(startIdx, endIdx);
    final normalizedEnd = math.max(startIdx, endIdx);
    if (normalizedEnd - normalizedStart < 1) {
      widget.onRangeSelectionChanged(null);
      return;
    }

    final start = valuePts[normalizedStart];
    final end = valuePts[normalizedEnd];
    setState(() {
      _rangeStartIndex = normalizedStart;
      _rangeEndIndex = normalizedEnd;
      _rangeSelectionLocked = true;
    });
    widget.onRangeSelectionChanged(
      _ChartRangeSelection(
        startDate: start.date,
        endDate: end.date,
        startValue: start.value,
        endValue: end.value,
      ),
    );
  }

  void _cancelRangeSelection() {
    if (_isRangeSelectionLocked) return;
    setState(() {
      _rangeStartIndex = null;
      _rangeEndIndex = null;
    });
    widget.onRangeSelectionChanged(null);
  }

  void _selectRange(int idx) {
    if (_isRangeSelectionLocked) return;
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
      _rangeStartIndex = null;
      _rangeEndIndex = null;
    });
    widget.onRangeSelectionChanged(null);
    _drawCtrl.forward(from: 0);
  }

  String _formatChartRangeDate(DateTime date) =>
      '${date.month}.${date.day.toString().padLeft(2, '0')}';

  ({double x, String label})? _rangeDateLabelData(
    List<ChartPoint> valuePts, {
    required double fullWidth,
    required double stackWidth,
  }) {
    if (!widget.rangeDigestMode || valuePts.length < 2) return null;
    final start = _rangeStartIndex;
    final end = _rangeEndIndex;
    if (start == null || end == null) return null;

    final leftIdx = math.min(start, end).clamp(0, valuePts.length - 1).toInt();
    final rightIdx = math.max(start, end).clamp(0, valuePts.length - 1).toInt();
    if (rightIdx - leftIdx < 1) return null;

    double xForIndex(int index) => fullWidth * index / (valuePts.length - 1);
    // The chart canvas is shifted 24px left so it can draw edge-to-edge.
    // Mirror that offset for the widget overlay so it sits above the
    // selected range, not above the clipped Stack coordinates.
    final left = xForIndex(leftIdx) - 24;
    final right = xForIndex(rightIdx) - 24;
    final center = (left + right) / 2;
    final maxLeft =
        math.max(0.0, stackWidth - _RangeDigestChartDateLabel.width);
    final x = (center - _RangeDigestChartDateLabel.width / 2)
        .clamp(0.0, maxLeft)
        .toDouble();

    return (
      x: x,
      label:
          '${_formatChartRangeDate(valuePts[leftIdx].date)} - ${_formatChartRangeDate(valuePts[rightIdx].date)}',
    );
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
    final isGain = displayChange >= 0;
    final pnlColor = isGain ? _gainColor : _lossColor;
    final sign = isGain ? '+' : '-';
    final formattedPnl =
        '$sign${_formatCurrency(displayChange.abs().toInt())} 원';
    final formattedPct = '($sign${displayChangePct.abs().toStringAsFixed(2)}%)';
    final investedAmount = accountSummary?.investedAmount ?? startValue;
    final headerCurrentValue = crosshairValue ?? currentValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 총손익 label (wordmark moved up next to the notification icon)
        Text(
          '총손익',
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),

        // Total return (won) + percent, baseline aligned
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formattedPnl,
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: pnlColor,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedPct,
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: pnlColor,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Invested vs current value stack
        _InvestedVsCurrentStack(
          invested: investedAmount,
          current: headerCurrentValue,
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
            final cardData = !widget.rangeDigestMode &&
                    _touchIndex != null &&
                    _touchIndex! >= 1
                ? _buildCardData(
                    valuePts,
                    fullWidth: fullWidth,
                    stackWidth: constraints.maxWidth,
                  )
                : null;
            final rangeDateLabelData = _rangeDateLabelData(
              valuePts,
              fullWidth: fullWidth,
              stackWidth: constraints.maxWidth,
            );
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
                        key: const Key('home_performance_chart_gesture'),
                        behavior: HitTestBehavior.opaque,
                        onPanDown: (d) {
                          if (widget.rangeDigestMode) {
                            _beginRangeSelectionAt(
                              d.localPosition.dx,
                              fullWidth,
                              valuePts,
                            );
                            return;
                          }
                          final idx = _indexForChartX(
                            d.localPosition.dx,
                            fullWidth,
                            valuePts.length,
                          );
                          _glowCtrl.repeat(reverse: true);
                          setState(() => _touchIndex = idx);
                        },
                        onPanStart: (d) {
                          if (widget.rangeDigestMode) {
                            _beginRangeSelectionAt(
                              d.localPosition.dx,
                              fullWidth,
                              valuePts,
                            );
                          }
                        },
                        onPanUpdate: (d) {
                          if (widget.rangeDigestMode) {
                            _updateRangeSelectionAt(
                              d.localPosition.dx,
                              fullWidth,
                              valuePts,
                            );
                            return;
                          }
                          final idx = _indexForChartX(
                            d.localPosition.dx,
                            fullWidth,
                            valuePts.length,
                          );
                          setState(() => _touchIndex = idx);
                        },
                        onPanEnd: (_) {
                          if (widget.rangeDigestMode) {
                            _completeRangeSelection(valuePts);
                            return;
                          }
                          _glowCtrl.stop();
                          _glowCtrl.value = 0;
                          setState(() => _touchIndex = null);
                        },
                        onPanCancel: () {
                          if (widget.rangeDigestMode) {
                            _cancelRangeSelection();
                            return;
                          }
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
                                selectedRangeStartIndex: widget.rangeDigestMode
                                    ? _rangeStartIndex
                                    : null,
                                selectedRangeEndIndex: widget.rangeDigestMode
                                    ? _rangeEndIndex
                                    : null,
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
                  Positioned(
                    right: 0,
                    top: 8,
                    child: IgnorePointer(
                      ignoring:
                          _touchIndex != null && !widget.rangeDigestMode,
                      child: AnimatedOpacity(
                        opacity: _touchIndex != null && !widget.rangeDigestMode
                            ? 0.0
                            : 1.0,
                        duration: const Duration(milliseconds: 140),
                        child: _RangeDigestChartAiButton(
                          active: widget.rangeDigestMode,
                          onTap: widget.rangeDigestMode
                              ? widget.onExitRangeDigestMode
                              : widget.onEnterRangeDigestMode,
                        ),
                      ),
                    ),
                  ),
                  if (rangeDateLabelData != null)
                    Positioned(
                      left: rangeDateLabelData.x,
                      top: 6,
                      width: _RangeDigestChartDateLabel.width,
                      child: _RangeDigestChartDateLabel(
                        label: rangeDateLabelData.label,
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

class _RangeDigestChartDateLabel extends StatelessWidget {
  static const double width = 112;

  final String label;

  const _RangeDigestChartDateLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Text(
      label,
      key: const Key('range_digest_chart_date_label'),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: TextStyle(
        fontFamily: WeRoboFonts.english,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: tc.textSecondary.withValues(alpha: 0.82),
        height: 1.2,
        shadows: [
          Shadow(
            color: tc.surface.withValues(alpha: 0.9),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _RangeDigestChartAiButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _RangeDigestChartAiButton({
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final fg = active ? WeRoboColors.white : WeRoboColors.primary;
    return Pressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            key:
                Key(active ? 'range_digest_exit' : 'range_digest_chart_ai_button'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? WeRoboColors.primary.withValues(alpha: 0.78)
                  : tc.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? WeRoboColors.primary.withValues(alpha: 0.55)
                    : WeRoboColors.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.close_rounded : Icons.auto_awesome_rounded,
                  size: 15,
                  color: fg,
                ),
                const SizedBox(width: 5),
                active
                    ? Icon(Icons.crop_free_rounded, size: 15, color: fg)
                    : Text(
                        'AI',
                        style: WeRoboTypography.caption.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Portfolio issue feed ──────────────────────────────────────

class _PortfolioIssueFeed extends StatelessWidget {
  final MobileDigestResponse? digest;
  final RebalanceInsight? latestInsight;
  final double? dailyReturn;
  final List<ContributionEntry> dailyContributors;
  final bool rangeDigestMode;
  final _ChartRangeSelection? selectedDigestRange;
  final MobileRangeDigestResponse? rangeDigest;
  final bool rangeDigestLoading;
  final String? rangeDigestError;
  final VoidCallback onExitRangeDigestMode;
  final VoidCallback? onRetryRangeDigest;
  final VoidCallback? onRangeDigestDetailTap;
  final VoidCallback? onDigestTap;

  const _PortfolioIssueFeed({
    required this.digest,
    required this.latestInsight,
    required this.dailyReturn,
    required this.dailyContributors,
    required this.rangeDigestMode,
    required this.selectedDigestRange,
    required this.rangeDigest,
    required this.rangeDigestLoading,
    required this.rangeDigestError,
    required this.onExitRangeDigestMode,
    this.onRetryRangeDigest,
    this.onRangeDigestDetailTap,
    this.onDigestTap,
  });

  static bool hasItems({
    required MobileDigestResponse? digest,
    required RebalanceInsight? latestInsight,
  }) {
    return digest != null || latestInsight != null;
  }

  @override
  Widget build(BuildContext context) {
    if (rangeDigestMode) {
      return _RangeDigestIssueCard(
        selection: selectedDigestRange,
        digest: rangeDigest,
        loading: rangeDigestLoading,
        error: rangeDigestError,
        onExit: onExitRangeDigestMode,
        onRetry: onRetryRangeDigest,
        onDetailTap: onRangeDigestDetailTap,
      );
    }

    final tc = WeRoboThemeColors.of(context);
    // Daily digest replaces the old AI summary card (UIUX 2026-05-20 spec).
    // One short card: yesterday's return and the two assets that mattered most.
    final pct = dailyReturn;
    final hasPct = pct != null;
    final isGain = hasPct && pct >= 0;
    final pctColor = isGain ? _gainColor : _lossColor;
    final pctText = hasPct
        ? '${isGain ? '+' : '-'}${(pct.abs() * 100).toStringAsFixed(2)}%'
        : '—';
    final contributorText = dailyContributors.isEmpty
        ? null
        : dailyContributors.map((c) => c.label).join(', ');

    return Container(
      key: const Key('portfolio_daily_digest'),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Pressable(
        onTap: onDigestTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '어제 대비 ',
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textSecondary,
                    ),
                  ),
                  Text(
                    pctText,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: hasPct ? pctColor : tc.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (contributorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  '강세: $contributorText',
                  style: WeRoboTypography.caption.copyWith(
                    color: tc.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

class _RangeDigestIssueCard extends StatelessWidget {
  final _ChartRangeSelection? selection;
  final MobileRangeDigestResponse? digest;
  final bool loading;
  final String? error;
  final VoidCallback onExit;
  final VoidCallback? onRetry;
  final VoidCallback? onDetailTap;

  const _RangeDigestIssueCard({
    required this.selection,
    required this.digest,
    required this.loading,
    required this.error,
    required this.onExit,
    this.onRetry,
    this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final summary = _RangeDigestSummary.resolve(
      selection: selection,
      digest: digest,
      loading: loading,
      error: error,
    );
    final showLoading = selection != null && loading;
    final showRetry = selection != null && error != null && onRetry != null;
    final showDetail =
        selection != null && digest != null && onDetailTap != null;

    return Container(
      key: Key(selection == null
          ? 'portfolio_range_digest_card'
          : 'range_digest_selection_active'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        border: Border.all(
          color: WeRoboColors.primary.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_graph_rounded,
                size: 17,
                color: WeRoboColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                summary.meta,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Pressable(
                onTap: onExit,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: tc.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.title,
            style: WeRoboTypography.heading3.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.body,
            maxLines: digest == null ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
              height: 1.45,
            ),
          ),
          if (showLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: WeRoboColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini가 구간 근거를 정리 중이에요.',
                  style: WeRoboTypography.caption.copyWith(
                    color: tc.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (showRetry || showDetail) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: _RangeDigestActionButton(
                label: showDetail ? '자세히 보기' : '다시 시도',
                icon: showDetail
                    ? Icons.chevron_right_rounded
                    : Icons.refresh_rounded,
                onTap: showDetail ? onDetailTap! : onRetry!,
              ),
            ),
          ],
          if (selection == null) ...[
            const SizedBox(height: 12),
            Text(
              '손을 떼면 선택한 구간이 유지돼요.',
              style: WeRoboTypography.caption.copyWith(
                color: tc.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartRangeSelection {
  final DateTime startDate;
  final DateTime endDate;
  final double startValue;
  final double endValue;

  const _ChartRangeSelection({
    required this.startDate,
    required this.endDate,
    required this.startValue,
    required this.endValue,
  });

  double get change => endValue - startValue;
  double get changePct => startValue == 0 ? 0 : change / startValue * 100;
}

class _RangeDigestSummary {
  final String title;
  final String meta;
  final String body;

  const _RangeDigestSummary({
    required this.title,
    required this.meta,
    required this.body,
  });

  factory _RangeDigestSummary.resolve({
    required _ChartRangeSelection? selection,
    required MobileRangeDigestResponse? digest,
    required bool loading,
    required String? error,
  }) {
    if (selection == null) {
      return const _RangeDigestSummary(
        title: '이 구간은 왜 움직였을까?',
        meta: '구간 분석',
        body: '차트에서 궁금한 구간을 드래그해 선택하세요.',
      );
    }
    if (loading) {
      final range = _formatDateRange(selection.startDate, selection.endDate);
      final signedPct = _formatSignedPercent(selection.changePct);
      final signedWon = _formatSignedWon(selection.change);
      return _RangeDigestSummary(
        title: '이 구간의 변화를 분석하고 있어요',
        meta: '선택 구간 · $range',
        body: '$range 동안 $signedPct, $signedWon 움직였어요.',
      );
    }
    if (digest != null) {
      return _RangeDigestSummary.fromDigest(
          selection: selection, digest: digest);
    }
    if (error != null) {
      final base = _RangeDigestSummary.fromSelection(selection);
      return _RangeDigestSummary(
        title: error,
        meta: base.meta,
        body: base.body,
      );
    }
    return _RangeDigestSummary.fromSelection(selection);
  }

  factory _RangeDigestSummary.fromSelection(_ChartRangeSelection selection) {
    final pct = selection.changePct;
    final title = pct > 0.1
        ? '이 구간에서 왜 올랐을까?'
        : pct < -0.1
            ? '이 구간에서 왜 내려갔을까?'
            : '왜 큰 변화가 없었을까?';
    final range = _formatDateRange(selection.startDate, selection.endDate);
    final signedPct = _formatSignedPercent(pct);
    final signedWon = _formatSignedWon(selection.change);
    return _RangeDigestSummary(
      title: title,
      meta: '선택 구간 · $range',
      body: '$range 동안 $signedPct, $signedWon 움직였어요. '
          '변화 원인 분석은 곧 연결됩니다.',
    );
  }

  factory _RangeDigestSummary.fromDigest({
    required _ChartRangeSelection selection,
    required MobileRangeDigestResponse digest,
  }) {
    final pct = digest.totalReturnPct;
    final title = pct > 0.1
        ? '왜 올랐을까?'
        : pct < -0.1
            ? '왜 내려갔을까?'
            : '왜 큰 변화가 없었을까?';
    final range = _formatDateRange(selection.startDate, selection.endDate);
    final narrative = digest.narrativeKo?.trim();
    final body =
        digest.hasNarrative && narrative != null && narrative.isNotEmpty
            ? narrative
            : _RangeDigestSummary.fromSelection(selection).body;
    return _RangeDigestSummary(
      title: title,
      meta: 'AI 요약 · $range',
      body: body,
    );
  }
}

class _RangeDigestActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RangeDigestActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: WeRoboColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: WeRoboTypography.bodySmall.copyWith(
                color: WeRoboColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: WeRoboColors.primary),
          ],
        ),
      ),
    );
  }
}

String _formatDateRange(DateTime start, DateTime end) {
  return '${start.month}월 ${start.day}일-${end.month}월 ${end.day}일';
}

// ─── Invested vs current value stack ──────────────────────────

class _InvestedVsCurrentStack extends StatelessWidget {
  final double invested;
  final double current;

  const _InvestedVsCurrentStack({
    required this.invested,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final labelStyle = WeRoboTypography.bodySmall.copyWith(
      color: tc.textSecondary,
    );
    // Spec: numbers match the label's bodySmall size, stay black, NOT bold.
    final amountStyle = WeRoboTypography.bodySmall.copyWith(
      color: tc.textPrimary,
      fontWeight: FontWeight.w400,
      fontFamily: WeRoboFonts.english,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('투자금액', style: labelStyle),
            const SizedBox(width: 8),
            Text(
              '${_formatCurrency(invested.toInt())} 원',
              style: amountStyle,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('평가금액', style: labelStyle),
            const SizedBox(width: 8),
            Text(
              '${_formatCurrency(current.toInt())} 원',
              style: amountStyle,
            ),
          ],
        ),
      ],
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
  final int? selectedRangeStartIndex;
  final int? selectedRangeEndIndex;
  final double glowPhase;
  final String dateLabel;
  final Color glowColor;
  final Color gridColor;
  final Color crosshairColor;

  _HomePerformancePainter({
    required this.lines,
    required this.progress,
    this.touchIndex,
    this.selectedRangeStartIndex,
    this.selectedRangeEndIndex,
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

    _drawSelectedRange(canvas, basePts.length, toX, graphTopPad, chartH);

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

  void _drawSelectedRange(
    Canvas canvas,
    int pointCount,
    double Function(int, int) toX,
    double graphTopPad,
    double chartH,
  ) {
    final start = selectedRangeStartIndex;
    final end = selectedRangeEndIndex;
    if (start == null || end == null || pointCount < 2) return;

    final leftIdx = math.min(start, end).clamp(0, pointCount - 1).toInt();
    final rightIdx = math.max(start, end).clamp(0, pointCount - 1).toInt();
    final left = toX(leftIdx, pointCount);
    final right = toX(rightIdx, pointCount);
    if ((right - left).abs() < 1) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, graphTopPad, right, graphTopPad + chartH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = WeRoboColors.primary.withValues(alpha: 0.08),
    );

    final handlePaint = Paint()
      ..color = WeRoboColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(left, graphTopPad),
      Offset(left, graphTopPad + chartH),
      handlePaint,
    );
    canvas.drawLine(
      Offset(right, graphTopPad),
      Offset(right, graphTopPad + chartH),
      handlePaint,
    );
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
      old.selectedRangeStartIndex != selectedRangeStartIndex ||
      old.selectedRangeEndIndex != selectedRangeEndIndex ||
      old.glowPhase != glowPhase;
  // `lines` is freshly constructed every build (new list, new ChartLine
  // instances) so reference equality is always false. We'd always
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
    // visible behind the card so they read as soft ghosts. The card
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
              Text(
                '누적 (시작 대비)',
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              _DragContextRow(label: '포트폴리오', pct: portfolioPct),
              if (marketPct != null)
                _DragContextRow(label: '시장', pct: marketPct!),
              if (assetRows.isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  key: const Key('drag_context_asset_divider'),
                  height: 1,
                  color: tc.border.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 5),
              ],
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
  return '$sign${_formatCurrency(amount.abs().round())} 원';
}

String _formatSignedPercent(double percentage) {
  final sign = percentage >= 0 ? '+' : '-';
  return '$sign${percentage.abs().toStringAsFixed(1)}%';
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


// ─── Notification dropdown sheet ────────────────────────────

typedef NotificationsApiOverride = ({
  Future<MobileVolatilityHistoryResponse> Function() fetchVolatility,
  Future<MobileAssetClassNewsResponse> Function(AssetClass cls) fetchNews,
});

NotificationsApiOverride? _notificationsApiOverride;

@visibleForTesting
void debugSetNotificationsApiOverride(NotificationsApiOverride? override) {
  _notificationsApiOverride = override;
}

/// Public entry point so widget tests can drive the sheet without going
/// through the bell icon's GestureDetector.
void showNotificationsSheet(BuildContext context) {
  // Capture state before the dialog route so it is available in the new
  // route's widget tree (GeneralDialog creates an isolated context).
  final state = PortfolioStateProvider.of(context);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '알림 닫기',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: WeRoboMotion.medium,
    pageBuilder: (_, __, ___) => PortfolioStateProvider(
      state: state,
      child: const _NotificationsSheet(),
    ),
    transitionBuilder: (_, anim, __, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: WeRoboMotion.enter));
      return SlideTransition(position: slide, child: child);
    },
  );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  MobileAssetClassNewsResponse? _news;
  bool _newsErrored = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAsync());
  }

  Future<void> _loadAsync() async {
    final state = PortfolioStateProvider.of(context);
    final override = _notificationsApiOverride;
    final fetchVolatility = override?.fetchVolatility ??
        () {
          final portfolio = state.selectedPortfolio;
          final riskProfile = portfolio?.code ?? state.type.riskCode;
          return MobileBackendApi.instance.fetchVolatilityHistory(
            riskProfile: riskProfile,
            stockWeights: portfolio?.stockWeights,
          );
        };
    final topAsset = _topWeightedAssetClass(state);
    final fetchNews = override?.fetchNews ??
        (AssetClass cls) => MobileBackendApi.instance.fetchAssetClassNews(cls);

    final volFuture = _safeVoid(() async {
      final vol = await fetchVolatility();
      if (!mounted) return;
      state.setPortfolioVolatilityHistory(vol);
    });

    final newsFuture = topAsset == null
        ? Future<void>.value()
        : _safeVoid(
            () async {
              final news = await fetchNews(topAsset);
              if (!mounted) return;
              setState(() {
                _news = news;
              });
            },
            onError: () {
              if (!mounted) return;
              setState(() => _newsErrored = true);
            },
          );

    await Future.wait<void>([volFuture, newsFuture]);
    if (!mounted) return;
    setState(() {
      _ready = true;
    });
  }

  Future<void> _safeVoid(
    Future<void> Function() body, {
    VoidCallback? onError,
  }) async {
    try {
      await body();
    } catch (_) {
      onError?.call();
    }
  }

  AssetClass? _topWeightedAssetClass(PortfolioState state) {
    final portfolio = state.selectedPortfolio;
    if (portfolio == null) return null;
    final weights = <AssetClass, double>{};
    for (final alloc in portfolio.sectorAllocations) {
      final cls = _sectorCodeToAssetClass(alloc.assetCode);
      if (cls == null) continue;
      weights[cls] = (weights[cls] ?? 0.0) + alloc.weight;
    }
    if (weights.isEmpty) return null;
    final sorted = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  AssetClass? _sectorCodeToAssetClass(String code) {
    switch (code) {
      case 'cash':
      case 'cash_equivalent':
      case 'cash_equivalents':
        return AssetClass.cash;
      case 'short_term_bond':
      case 'bond':
      case 'treasury':
        return AssetClass.shortBond;
      case 'infra':
      case 'infra_bond':
      case 'infrastructure':
      case 'infrastructure_bond':
        return AssetClass.infraBond;
      case 'gold':
      case 'commodity_gold':
        return AssetClass.gold;
      case 'us_value':
      case 'value_stock':
        return AssetClass.usValue;
      case 'us_growth':
      case 'growth_stock':
        return AssetClass.usGrowth;
      case 'new_growth':
        return AssetClass.newGrowth;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);

    final rows = <Widget>[];

    // 1. Monthly summary.
    final monthly = state.trailingMonthReturn;
    if (monthly != null) {
      final sign = monthly >= 0 ? '+' : '−';
      final pct = (monthly.abs() * 100).toStringAsFixed(1);
      rows.add(_NotificationRow(
        kind: _NotificationKind.monthlySummary,
        category: _categoryLabel(_NotificationKind.monthlySummary),
        title: '지난 30일 포트폴리오 $sign$pct%',
        onTap: () => _navigateToComingSoon(
          context,
          _categoryLabel(_NotificationKind.monthlySummary),
        ),
      ));
    }

    // 2. Contribution.
    final contributor = state.topContributorOver30d;
    if (contributor != null) {
      final pct =
          (contributor.weight * contributor.assetReturn * 100).abs().round();
      rows.add(_NotificationRow(
        kind: _NotificationKind.contribution,
        category: _categoryLabel(_NotificationKind.contribution),
        title: '이번 달 ${contributor.label}이 수익의 $pct%를 기여했어요',
        onTap: () => _navigateToComingSoon(
          context,
          _categoryLabel(_NotificationKind.contribution),
        ),
      ));
    }

    // 3. Algorithm signal — one row per rebalance insight, most recent first.
    rows.addAll(_buildAlgorithmSignalRows(state, context));

    // 4. Volatility row — always rendered. Copy depends on whether a spike
    //    was detected after the async fetch completed.
    final spike = state.portfolioVolatilitySpike;
    final volatilityTitle = !_ready
        ? '변동성 데이터를 불러오는 중이에요'
        : spike != null
            ? '포트폴리오 변동성 +${(spike.percentAboveAverage * 100).round()}% 주의 구간이에요'
            : '현재 시장 변동성은 안정세를 유지하고 있어요';
    rows.add(_NotificationRow(
      kind: _NotificationKind.volatilityAlert,
      category: _categoryLabel(_NotificationKind.volatilityAlert),
      title: volatilityTitle,
      onTap: () => _navigateToComingSoon(
        context,
        _categoryLabel(_NotificationKind.volatilityAlert),
      ),
    ));

    // 5. News row — always rendered. Title falls back when the fetch fails
    //    or hasn't completed yet.
    final newsTitle = !_ready
        ? '뉴스를 불러오는 중이에요'
        : (_news != null && !_newsErrored)
            ? _news!.title
            : '뉴스를 불러올 수 없어요';
    rows.add(_NotificationRow(
      kind: _NotificationKind.assetNews,
      category: _categoryLabel(_NotificationKind.assetNews),
      title: newsTitle,
      onTap: _ready && _news != null && !_newsErrored
          ? () => _openNewsLink(_news!.link)
          : () => _navigateToComingSoon(
                context,
                _categoryLabel(_NotificationKind.assetNews),
              ),
    ));

    final body = rows.isEmpty && _ready
        ? <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Text(
                '오늘은 새로운 알림이 없어요',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textTertiary,
                ),
              ),
            ),
          ]
        : <Widget>[
            // Cap height at 60% of the screen so a long insight history
            // doesn't push the sheet off the bottom of the device. The
            // "지난 알림 모두 보기" link is appended as the final list item
            // so it scrolls with the content rather than sticking at the
            // bottom of the sheet.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: rows.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  if (i < rows.length) return rows[i];
                  return _SeeAllRow(
                    onTap: () => Navigator.of(context).push(
                      WeRoboMotion.fadeRoute<void>(const ActivityHubPage()),
                    ),
                  );
                },
              ),
            ),
          ];

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: tc.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '오늘의 알림',
                          textAlign: TextAlign.center,
                          style: WeRoboTypography.heading3.themed(context),
                        ),
                      ),
                      Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: tc.card,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: tc.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: tc.card),
                ...body,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNewsLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _navigateToComingSoon(BuildContext context, String title) {
    Navigator.of(context).push(
      WeRoboMotion.fadeRoute<void>(_ComingSoonPage(title: title)),
    );
  }

  Iterable<_NotificationRow> _buildAlgorithmSignalRows(
    PortfolioState state,
    BuildContext context,
  ) sync* {
    // "오늘의 알림" is by definition today's signals only. Filter on the
    // rebalanceDate (the actual event date), not createdAt — createdAt
    // may be a metadata timestamp that's always recent. Older insights
    // are reachable via "지난 알림 모두 보기" at the bottom of the sheet.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final insight in state.insights) {
      final rebalDate = _parseIsoDate(insight.rebalanceDate);
      if (rebalDate == null || rebalDate.isBefore(today)) continue;

      final dateLabel = _formatKoreanDate(insight.rebalanceDate);
      final triggerSentence = _triggerSentence(insight.trigger);
      final title =
          dateLabel == null ? triggerSentence : '$dateLabel $triggerSentence';
      yield _NotificationRow(
        kind: _NotificationKind.algorithmSignal,
        category: _categoryLabel(_NotificationKind.algorithmSignal),
        title: title,
        onTap: () {
          Navigator.of(context).push(
            WeRoboMotion.fadeRoute<void>(
              InsightDetailPage(insight: insight),
            ),
          );
        },
      );
    }
  }

  String? _formatKoreanDate(String iso) {
    // Expects "YYYY-MM-DD"; returns "M월 D일".
    if (iso.length < 10) return null;
    final month = int.tryParse(iso.substring(5, 7));
    final day = int.tryParse(iso.substring(8, 10));
    if (month == null || day == null) return null;
    return '$month월 $day일';
  }

  DateTime? _parseIsoDate(String iso) {
    if (iso.length < 10) return null;
    final year = int.tryParse(iso.substring(0, 4));
    final month = int.tryParse(iso.substring(5, 7));
    final day = int.tryParse(iso.substring(8, 10));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _triggerSentence(String? trigger) {
    // Backend trigger codes (see account_service._rebalance_activity_title).
    switch (trigger) {
      case 'scheduled':
        return '정기 리밸런싱이 실행됐어요';
      case 'drift_guard':
        return '드리프트 가드가 작동했어요';
      case 'threshold':
        return '임계치 초과로 조정됐어요';
      case null:
        return '리밸런싱이 실행됐어요';
      default:
        return '리밸런싱이 실행됐어요';
    }
  }
}

enum _NotificationKind {
  monthlySummary,
  contribution,
  algorithmSignal,
  volatilityAlert,
  assetNews,
}

String _categoryLabel(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.monthlySummary:
      return '월간 요약';
    case _NotificationKind.contribution:
      return '기여도 알림';
    case _NotificationKind.algorithmSignal:
      return '알고리즘 시그널';
    case _NotificationKind.volatilityAlert:
      return '시장 변동성 경고';
    case _NotificationKind.assetNews:
      return '자산군별 뉴스';
  }
}

String _iconAsset(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.monthlySummary:
      return 'assets/icons/calendar.png';
    case _NotificationKind.contribution:
      return 'assets/icons/contribution-alarm.png';
    case _NotificationKind.algorithmSignal:
      return 'assets/icons/algorithm-signal.png';
    case _NotificationKind.volatilityAlert:
      return 'assets/icons/change-alert.png';
    case _NotificationKind.assetNews:
      return 'assets/icons/asset-news.png';
  }
}

class _ComingSoonPage extends StatelessWidget {
  final String title;
  const _ComingSoonPage({required this.title});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tc.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '준비중입니다',
                  style: WeRoboTypography.body.copyWith(
                    color: tc.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final _NotificationKind kind;
  final String category;
  final String title;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.kind,
    required this.category,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tc.card,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset(_iconAsset(kind), fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeAllRow extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '지난 알림 모두 보기',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tc.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
