import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'comparison_backtest_chart_mapper.dart';
import 'debug_page_logger.dart';
import 'theme.dart' show AssetClass;
import '../models/chart_data.dart';
import '../models/mobile_backend_models.dart';
import '../models/portfolio_data.dart';
import '../models/rebalance_insight.dart';
import '../screens/onboarding/onboarding_screen.dart'
    show OnboardingFrontierSelection;
import '../services/alert_analytics.dart';
import '../services/mobile_backend_api.dart';

/// User-facing alert frequency setting. Maps internally to a σ threshold.
/// Plain-language labels never expose σ to the user.
enum AlertFrequency {
  often, // 자주 받기 → 1.5σ → ~월 2-3회
  normal, // 보통 → 2.0σ → ~월 1-2회 (default)
  important; // 중요할 때만 → 3.0σ → ~분기 1회

  double get sigmaThreshold => switch (this) {
        AlertFrequency.often => 1.5,
        AlertFrequency.normal => 2.0,
        AlertFrequency.important => 3.0,
      };

  String get koLabel => switch (this) {
        AlertFrequency.often => '자주 받기',
        AlertFrequency.normal => '보통',
        AlertFrequency.important => '중요할 때만',
      };
}

/// Top-N contribution analysis for a moment in the portfolio simulation.
/// Consumed by the deferred Phase 4 ContributionTooltip widget.
class ContributionAnalysis {
  /// Sorted by `|krwImpact|` descending; capped to the top 2 entries.
  final List<ContributionEntry> topEntries;

  /// True when any of the top entries is `AssetClass.newGrowth`. Drives the
  /// "데이터 정합성 검토 중" caveat shown next to 신성장주 figures.
  final bool containsNewGrowth;

  const ContributionAnalysis({
    required this.topEntries,
    required this.containsNewGrowth,
  });

  factory ContributionAnalysis.fromEntries(List<ContributionEntry> entries) {
    final top = [...entries]
      ..sort((a, b) => b.krwImpact.abs().compareTo(a.krwImpact.abs()));
    final top2 = top.take(2).toList();
    return ContributionAnalysis(
      topEntries: top2,
      containsNewGrowth: top2.any((e) => e.cls == AssetClass.newGrowth),
    );
  }
}

/// One row of the contribution-analysis breakdown.
class ContributionEntry {
  final AssetClass cls;
  final String label;
  final double weight;
  final double assetReturn;
  final double krwImpact;
  final bool isOutlier;

  const ContributionEntry({
    required this.cls,
    required this.label,
    required this.weight,
    required this.assetReturn,
    required this.krwImpact,
    this.isOutlier = false,
  });
}

/// App-level state holder for auth, onboarding bootstrap state, and portfolio data.
class PortfolioState extends ChangeNotifier {
  static const String _authSessionStorageKey = 'werobo.auth_session';
  static const String _portfolioBootstrapStorageKey =
      'werobo.portfolio_bootstrap';
  static const int _frontierPreviewStorageVersion = 3;
  static const String _digestSeenDateKey = 'werobo.digest_seen_date';
  static const String _welcomeBannerSeenKey = 'werobo.welcome_banner_seen';
  static const String _alertFrequencyKey = 'alertFrequency';

  InvestmentType _type = InvestmentType.balanced;
  MobileRecommendationResponse? _recommendation;
  MobileComparisonBacktestResponse? _backtest;
  MobileFrontierPreviewResponse? _frontierPreview;
  MobileFrontierSelectionResponse? _frontierSelection;
  // Captured at 투자 확정 from the post-frontier review screen so the home
  // tab can read what the user picked even before the authoritative
  // backend selection arrives.
  OnboardingFrontierSelection? _onboardingFrontierSelection;
  MobileAuthSession? _authSession;
  MobileAccountDashboard? _accountDashboard;
  List<RebalanceInsight> _insights = [];
  String? _digestSeenDate;
  bool _welcomeBannerSeen = false;
  MobileDigestResponse? _weeklyDigest;
  AlertFrequency _alertFrequency = AlertFrequency.normal;
  // Forward-compat for the deferred home dashboard rework: backend will flip
  // this on when a 긴급-level alert lands so the 홈 nav tab can render an
  // unread dot. No production consumer triggers this today (MVP scope), but
  // the flag + setter are exposed so debug/test paths can simulate the badge.
  bool _hasUnreadEmergencyAlert = false;

  InvestmentType get type => _type;
  MobileRecommendationResponse? get recommendation => _recommendation;
  MobileComparisonBacktestResponse? get backtest => _backtest;
  MobileFrontierPreviewResponse? get frontierPreview => _frontierPreview;
  MobileFrontierSelectionResponse? get frontierSelection => _frontierSelection;
  MobileAuthSession? get authSession => _authSession;
  MobileAuthUser? get currentUser => _authSession?.user;
  MobileAccountDashboard? get accountDashboard => _accountDashboard;
  MobileAccountSummary? get accountSummary => _accountDashboard?.summary;
  List<MobileAccountHistoryPoint> get accountHistory =>
      _accountDashboard?.history ?? const [];
  List<MobileAccountActivity> get accountActivities =>
      _accountDashboard?.recentActivity ?? const [];
  List<RebalanceInsight> get insights =>
      _insights.where((i) => i.hasRealChanges).toList();
  List<RebalanceInsight> get unreadInsights =>
      _insights.where((i) => !i.isRead && i.hasRealChanges).toList();
  int get unreadInsightCount =>
      _insights.where((i) => !i.isRead && i.hasRealChanges).length;
  String? get digestSeenDate => _digestSeenDate;
  bool get hasSeenCurrentDigest => _digestSeenDate != null;
  bool get welcomeBannerSeen => _welcomeBannerSeen;
  MobileDigestResponse? get weeklyDigest => _weeklyDigest;
  bool get isWeeklyDigestAvailable => _weeklyDigest?.available == true;
  AlertFrequency get alertFrequency => _alertFrequency;
  bool get hasUnreadEmergencyAlert => _hasUnreadEmergencyAlert;

  bool get isLoggedIn => _authSession != null;
  bool get hasPrototypeAccount => _accountDashboard?.hasAccount == true;
  bool get hasCompletedPortfolioSetup =>
      _frontierSelection != null || _recommendation != null;
  bool get canAutoEnterHome =>
      isLoggedIn && (hasCompletedPortfolioSetup || hasPrototypeAccount);

  /// The selected portfolio from the API recommendation.
  MobilePortfolioRecommendation? get selectedPortfolio {
    final accountPortfolio =
        _portfolioFromAccountSummary(_accountDashboard?.summary);
    if (accountPortfolio != null) {
      return accountPortfolio;
    }
    if (_frontierSelection != null) {
      return _frontierSelection!.portfolio;
    }
    if (_recommendation == null) return null;
    for (final p in _recommendation!.portfolios) {
      if (p.investmentType == _type) return p;
    }
    return null;
  }

  List<PortfolioCategory> get categories {
    return selectedPortfolio?.toCategories() ?? const [];
  }

  List<PortfolioCategoryDetail> get categoryDetails {
    return selectedPortfolio?.toCategoryDetails() ?? const [];
  }

  /// Expected annual return for Monte Carlo projection.
  double? get expectedReturn => selectedPortfolio?.expectedReturn;

  /// Annual volatility for Monte Carlo projection.
  double? get portfolioVolatility => selectedPortfolio?.volatility;

  MobilePortfolioRecommendation? _portfolioFromAccountSummary(
    MobileAccountSummary? summary,
  ) {
    if (summary == null) {
      return null;
    }
    if (summary.sectorAllocations.isEmpty && summary.stockAllocations.isEmpty) {
      return null;
    }
    return MobilePortfolioRecommendation(
      code: summary.portfolioCode,
      label: summary.portfolioLabel,
      portfolioId: summary.portfolioId,
      targetVolatility: summary.targetVolatility,
      expectedReturn: summary.expectedReturn,
      volatility: summary.volatility,
      sharpeRatio: summary.sharpeRatio,
      sectorAllocations: summary.sectorAllocations,
      stockAllocations: summary.stockAllocations,
    );
  }

  /// Returns the top-N contribution breakdown at `time`. Returns null in the
  /// MVP — backend wiring lands with the deferred home dashboard rework.
  ///
  /// BACKEND TODO: when wiring to MobileBackendApi.fetchContributionAnalysis,
  /// build via ContributionAnalysis.fromEntries(...) so containsNewGrowth
  /// is set correctly for the "데이터 정합성 검토 중" caveat.
  ContributionAnalysis? contributionAnalysisAt(DateTime time) {
    return null;
  }

  void setType(InvestmentType newType) {
    if (_type != newType) {
      _type = newType;
      notifyListeners();
      _persistPortfolioBootstrapState();
    }
  }

  void setRecommendation(MobileRecommendationResponse rec) {
    _recommendation = rec;
    notifyListeners();
    _persistPortfolioBootstrapState();
  }

  void setBacktest(MobileComparisonBacktestResponse bt) {
    _backtest = bt;
    logApi(
      'success',
      'fetchComparisonBacktest',
      {
        'lineKeys': bt.lines.map((line) => line.key).join(','),
        'lineCount': bt.lines.length,
      },
    );
    notifyListeners();
  }

  void setFrontierPreview(MobileFrontierPreviewResponse preview) {
    _frontierPreview = preview;
    notifyListeners();
    _persistPortfolioBootstrapState();
  }

  void setFrontierSelection(MobileFrontierSelectionResponse? selection) {
    _frontierSelection = selection;
    notifyListeners();
    _persistPortfolioBootstrapState();
  }

  /// Snapshot of the user's onboarding-side pick — what t/preview was
  /// selected on the slider, regardless of whether the authoritative
  /// backend selection has resolved yet.
  OnboardingFrontierSelection? get onboardingFrontierSelection =>
      _onboardingFrontierSelection;

  /// Persist the onboarding-flow frontier pick so screens beyond
  /// onboarding (home tab, etc.) can read it after 투자 확정.
  void recordFrontierSelection(OnboardingFrontierSelection selection) {
    _onboardingFrontierSelection = selection;
    notifyListeners();
  }

  Future<void> restorePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await _restoreAuthSessionFromPrefs(prefs);
    await _restorePortfolioBootstrapFromPrefs(prefs);
    _digestSeenDate = prefs.getString(_digestSeenDateKey);
    _welcomeBannerSeen = prefs.getBool(_welcomeBannerSeenKey) ?? false;
    await _restoreAlertFrequency();
  }

  Future<void> setAlertFrequency(AlertFrequency f) async {
    if (_alertFrequency == f) return;
    _alertFrequency = f;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertFrequencyKey, f.name);
    // Fire-and-forget so persistence/notify aren't blocked on telemetry.
    unawaited(AlertAnalytics.instance.recordPreferenceChange(f));
    notifyListeners();
  }

  /// Clears the unread 긴급-alert flag (e.g., once the user opens the home
  /// tab and sees the alert).
  void markEmergencyAlertSeen() {
    if (!_hasUnreadEmergencyAlert) return;
    _hasUnreadEmergencyAlert = false;
    notifyListeners();
  }

  /// Backend will call this when a 긴급-level alert lands. Exposed publicly
  /// so debug/test paths can simulate the badge ahead of the post-MVP
  /// backend wiring.
  void setHasUnreadEmergencyAlert(bool v) {
    if (_hasUnreadEmergencyAlert == v) return;
    _hasUnreadEmergencyAlert = v;
    notifyListeners();
  }

  Future<void> _restoreAlertFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alertFrequencyKey);
    if (raw != null) {
      _alertFrequency = AlertFrequency.values.firstWhere(
        (f) => f.name == raw,
        orElse: () => AlertFrequency.normal,
      );
    }
  }

  Future<bool> validateAuthSession() async {
    final session = _authSession;
    if (session == null) {
      return false;
    }

    final expiresAt = DateTime.tryParse(session.expiresAt);
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      await clearAllPersistedState(notify: true);
      return false;
    }

    try {
      final currentSession = await MobileBackendApi.instance
          .fetchCurrentAuthSession(accessToken: session.accessToken);
      final refreshedSession = MobileAuthSession(
        accessToken: session.accessToken,
        tokenType: session.tokenType,
        expiresAt: currentSession.expiresAt,
        user: currentSession.user,
      );
      await setAuthSession(refreshedSession, notify: true);
      return true;
    } on MobileBackendException catch (error) {
      if (error.statusCode == 401) {
        await clearAllPersistedState(notify: true);
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setAuthSession(
    MobileAuthSession session, {
    bool notify = true,
  }) async {
    _authSession = session;
    if (notify) {
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _authSessionStorageKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<void> logout() async {
    final accessToken = _authSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        await MobileBackendApi.instance.logout(accessToken: accessToken);
      } catch (_) {}
    }
    await clearAllPersistedState(notify: true);
  }

  Future<void> clearAuthSession({bool notify = true}) async {
    _authSession = null;
    if (notify) {
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authSessionStorageKey);
  }

  Future<void> clearPortfolioBootstrap({bool notify = true}) async {
    _type = InvestmentType.balanced;
    _recommendation = null;
    _frontierSelection = null;
    _onboardingFrontierSelection = null;
    _frontierPreview = null;
    _backtest = null;
    _accountDashboard = null;
    _insights = [];
    if (notify) {
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_portfolioBootstrapStorageKey);
  }

  Future<void> clearAllPersistedState({bool notify = true}) async {
    _authSession = null;
    _type = InvestmentType.balanced;
    _recommendation = null;
    _backtest = null;
    _frontierPreview = null;
    _frontierSelection = null;
    _onboardingFrontierSelection = null;
    _accountDashboard = null;
    _insights = [];
    _digestSeenDate = null;
    _welcomeBannerSeen = false;
    _weeklyDigest = null;
    _hasUnreadEmergencyAlert = false;
    if (notify) {
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authSessionStorageKey);
    await prefs.remove(_portfolioBootstrapStorageKey);
    await prefs.remove(_digestSeenDateKey);
    await prefs.remove(_welcomeBannerSeenKey);
    // Note: _alertFrequency is intentionally NOT cleared here — it's a
    // device-level preference that should survive logout/login on the same
    // device.
  }

  void setTypeAndRecommendation(
    InvestmentType newType,
    MobileRecommendationResponse rec,
  ) {
    _type = newType;
    _recommendation = rec;
    notifyListeners();
    _persistPortfolioBootstrapState();
  }

  Future<MobileAccountDashboard?> refreshAccountDashboard({
    bool notify = true,
  }) async {
    final accessToken = _authSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      setAccountDashboard(null, notify: notify);
      return null;
    }

    try {
      final dashboard = await MobileBackendApi.instance
          .fetchPortfolioAccountDashboard(accessToken: accessToken);
      setAccountDashboard(dashboard, notify: notify);
      return dashboard;
    } on MobileBackendException catch (error) {
      if (error.statusCode == 401) {
        await clearAllPersistedState(notify: true);
        return null;
      }
      rethrow;
    }
  }

  Future<void> refreshWeeklyDigest({bool notify = true}) async {
    final accessToken = _authSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      setWeeklyDigest(null, notify: notify);
      return;
    }

    try {
      final digest = await MobileBackendApi.instance
          .fetchDigest(accessToken: accessToken);
      setWeeklyDigest(digest, notify: notify);
    } on MobileBackendException {
      // 422 (insufficient data), 401, network errors → leave digest null so
      // isWeeklyDigestAvailable is false and the home banner stays hidden.
      setWeeklyDigest(null, notify: notify);
    } catch (_) {
      setWeeklyDigest(null, notify: notify);
    }
  }

  Future<MobileAccountDashboard> createPrototypeAccount({
    required MobileFrontierSelectionResponse selection,
    double initialCashAmount = 10000000,
  }) async {
    final accessToken = _authSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const MobileBackendException('프로토타입 자산 계정을 만들려면 로그인이 필요합니다.');
    }
    final portfolio = selection.portfolio;
    final dashboard = await MobileBackendApi.instance.createPortfolioAccount(
      accessToken: accessToken,
      dataSource: selection.dataSource,
      investmentHorizon: selection.resolvedProfile.investmentHorizon,
      portfolio: portfolio,
      portfolioCode: selection.classificationCode,
      portfolioLabel: portfolio.label,
      initialCashAmount: initialCashAmount,
      startedAt: selection.asOfDate,
    );
    setAccountDashboard(dashboard);
    return dashboard;
  }

  Future<MobileAccountDashboard> cashInPrototypeAccount({
    required double amount,
  }) async {
    final accessToken = _authSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const MobileBackendException('입금을 진행하려면 로그인이 필요합니다.');
    }
    final dashboard = await MobileBackendApi.instance.cashInPortfolioAccount(
      accessToken: accessToken,
      amount: amount,
    );
    setAccountDashboard(dashboard);
    return dashboard;
  }

  void setAccountDashboard(
    MobileAccountDashboard? dashboard, {
    bool notify = true,
  }) {
    _accountDashboard = dashboard;
    final summary = dashboard?.summary;
    if (summary != null) {
      _type = investmentTypeFromRiskCode(summary.portfolioCode);
    }
    if (notify) {
      notifyListeners();
    }
  }

  void setWeeklyDigest(
    MobileDigestResponse? digest, {
    bool notify = true,
  }) {
    _weeklyDigest = digest;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> refreshInsights({bool notify = true}) async {
    final accessToken = _authSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final response = await MobileBackendApi.instance
            .fetchRebalanceInsights(accessToken: accessToken);
        _insights = response.insights;
        if (notify) notifyListeners();
        return;
      } catch (_) {}
    }
    // Fall back to mock insights based on current portfolio
    _insights = MockInsightData.insightsFor(categories);
    if (notify) notifyListeners();
  }

  Future<void> markWelcomeBannerSeen() async {
    _welcomeBannerSeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeBannerSeenKey, true);
  }

  Future<void> markDigestSeen(String digestDate) async {
    _digestSeenDate = digestDate;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_digestSeenDateKey, digestDate);
  }

  Future<void> markInsightAsRead(int insightId) async {
    // For mock or synthetic insights (negative IDs), just update locally.
    if (insightId < 0) {
      _markInsightReadLocally(insightId);
      return;
    }
    final accessToken = _authSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;
    try {
      await MobileBackendApi.instance.markInsightRead(
        accessToken: accessToken,
        insightId: insightId,
      );
      _markInsightReadLocally(insightId);
    } catch (_) {}
  }

  void _markInsightReadLocally(int insightId) {
    final idx = _insights.indexWhere((i) => i.id == insightId);
    if (idx >= 0) {
      final old = _insights[idx];
      _insights[idx] = RebalanceInsight(
        id: old.id,
        rebalanceDate: old.rebalanceDate,
        allocations: old.allocations,
        tradeDetails: old.tradeDetails,
        trigger: old.trigger,
        tradeCount: old.tradeCount,
        cashBefore: old.cashBefore,
        cashFromSales: old.cashFromSales,
        cashToBuys: old.cashToBuys,
        cashAfter: old.cashAfter,
        netCashChange: old.netCashChange,
        explanationText: old.explanationText,
        isRead: true,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }

  List<ChartPoint> portfolioValuePoints({
    double baseInvestment = 10000000,
  }) {
    if (_backtest == null) return const [];
    final code = _type.riskCode;
    MobileComparisonLine? line;
    for (final l in _backtest!.lines) {
      if (l.key == code) {
        line = l;
        break;
      }
    }
    if (line == null || line.points.isEmpty) return const [];
    return line.points
        .map((p) => ChartPoint(
              date: p.date,
              value: baseInvestment * (1 + p.returnPct),
            ))
        .toList();
  }

  List<ChartLine> get comparisonLines {
    if (_backtest == null) return const [];
    return comparisonChartLinesFromResponse(_backtest!);
  }

  List<DateTime> get rebalanceDates => _backtest?.rebalanceDates ?? const [];

  void setFromDotT(double dotT) {
    setType(InvestmentType.fromDotT(dotT));
  }

  Future<void> _restoreAuthSessionFromPrefs(SharedPreferences prefs) async {
    final raw = prefs.getString(_authSessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _authSession = MobileAuthSession.fromJson(decoded);
      } else {
        await prefs.remove(_authSessionStorageKey);
      }
    } catch (_) {
      await prefs.remove(_authSessionStorageKey);
    }
  }

  Future<void> _restorePortfolioBootstrapFromPrefs(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_portfolioBootstrapStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_portfolioBootstrapStorageKey);
        return;
      }
      final typeCode = decoded['selected_type']?.toString() ?? 'balanced';
      _type = investmentTypeFromRiskCode(typeCode);
      final recommendationJson = decoded['recommendation'];
      if (recommendationJson is Map<String, dynamic>) {
        _recommendation = MobileRecommendationResponse.fromJson(
          recommendationJson,
        );
      }
      final frontierSelectionJson = decoded['frontier_selection'];
      if (frontierSelectionJson is Map<String, dynamic>) {
        _frontierSelection = MobileFrontierSelectionResponse.fromJson(
          frontierSelectionJson,
        );
      }
      final previewVersion = switch (decoded['frontier_preview_version']) {
        int value => value,
        num value => value.toInt(),
        _ => 1,
      };
      final frontierPreviewJson = decoded['frontier_preview'];
      if (previewVersion == _frontierPreviewStorageVersion &&
          frontierPreviewJson is Map<String, dynamic>) {
        _frontierPreview = MobileFrontierPreviewResponse.fromJson(
          frontierPreviewJson,
        );
      }
    } catch (_) {
      await prefs.remove(_portfolioBootstrapStorageKey);
    }
  }

  Future<void> _persistPortfolioBootstrapState() async {
    if (_recommendation == null && _frontierSelection == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'selected_type': _type.riskCode,
      'recommendation': _recommendation?.toJson(),
      'frontier_selection': _frontierSelection?.toJson(),
      'frontier_preview_version': _frontierPreviewStorageVersion,
      'frontier_preview': _frontierPreview?.toJson(),
    };
    await prefs.setString(
      _portfolioBootstrapStorageKey,
      jsonEncode(payload),
    );
  }
}

class PortfolioStateProvider extends InheritedNotifier<PortfolioState> {
  const PortfolioStateProvider({
    super.key,
    required PortfolioState state,
    required super.child,
  }) : super(notifier: state);

  static PortfolioState of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<PortfolioStateProvider>();
    assert(provider != null, 'No PortfolioStateProvider in widget tree');
    return provider!.notifier!;
  }
}
