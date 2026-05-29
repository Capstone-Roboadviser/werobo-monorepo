import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'comparison_backtest_chart_mapper.dart';
import 'debug_page_logger.dart';
import 'theme.dart' show AssetClass, AssetClassLabel;
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

/// Portfolio volatility spike value object. Populated by
/// [PortfolioState.portfolioVolatilitySpike] when the most-recent rolling
/// volatility exceeds 1.5x the trailing-30-day average.
class VolatilitySpike {
  final double currentVolatility;
  final double averageVolatility;

  /// (current / avg) - 1, e.g. 1.0 = 100% above average.
  final double percentAboveAverage;

  const VolatilitySpike({
    required this.currentVolatility,
    required this.averageVolatility,
    required this.percentAboveAverage,
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
  static const String _storySeenKey = 'werobo.story_seen';
  static const String _alertFrequencyKey = 'alertFrequency';

  static DateTime prototypeAccountStartDate(DateTime now) {
    return DateTime(now.year, 3, 1);
  }

  InvestmentType _type = InvestmentType.balanced;
  MobileRecommendationResponse? _recommendation;
  MobileComparisonBacktestResponse? _backtest;
  MobileEarningsHistoryResponse? _earningsHistory;
  MobileVolatilityHistoryResponse? _portfolioVolatility;
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
  bool _storySeen = false;
  MobileDigestResponse? _weeklyDigest;
  AlertFrequency _alertFrequency = AlertFrequency.normal;
  // Forward-compat for the deferred home dashboard rework: backend will flip
  // this on when a 긴급-level alert lands so the 홈 nav tab can render an
  // unread dot. No production consumer triggers this today (MVP scope), but
  // the flag + setter are exposed so debug/test paths can simulate the badge.
  bool _hasUnreadEmergencyAlert = false;

  /// Injectable wall-clock seam. Production uses [DateTime.now]; tests pass a
  /// fixed clock so the trailing-window getters ([trailingMonthReturn],
  /// [trailingWeekReturn]) stay deterministic instead of drifting as the real
  /// date advances past a test's synthetic history.
  final DateTime Function() _clock;

  PortfolioState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  InvestmentType get type => _type;
  MobileRecommendationResponse? get recommendation => _recommendation;
  MobileComparisonBacktestResponse? get backtest => _backtest;
  MobileEarningsHistoryResponse? get earningsHistory => _earningsHistory;
  MobileVolatilityHistoryResponse? get portfolioVolatilityHistory =>
      _portfolioVolatility;
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
  bool get hasSeenStory => _storySeen;
  MobileDigestResponse? get weeklyDigest => _weeklyDigest;
  bool get isWeeklyDigestAvailable => _weeklyDigest?.available == true;
  AlertFrequency get alertFrequency => _alertFrequency;
  bool get hasUnreadEmergencyAlert => _hasUnreadEmergencyAlert;

  // ─── Notification-row derived getters ─────────────────────────────────────

  /// Trailing-30-day portfolio return as a fraction (e.g. 0.042 = +4.2%).
  /// Returns null when fewer than 20 daily points exist in the window.
  double? get trailingMonthReturn {
    final history = accountHistory;
    if (history.length < 20) return null;
    final now = _clock();
    final cutoff = now.subtract(const Duration(days: 30));
    final window = history.where((p) => !p.date.isBefore(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (window.length < 20) return null;
    final start = window.first.portfolioValue;
    final end = window.last.portfolioValue;
    if (start <= 0) return null;
    return (end / start) - 1.0;
  }

  /// Trailing-7-day portfolio return as a fraction (e.g. 0.012 = +1.2%).
  /// Returns null when fewer than 5 daily points exist in the window — same
  /// "at least one trading week" threshold used to gate the weekly view.
  double? get trailingWeekReturn {
    final history = accountHistory;
    if (history.length < 5) return null;
    final now = _clock();
    final cutoff = now.subtract(const Duration(days: 7));
    final window = history.where((p) => !p.date.isBefore(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (window.length < 5) return null;
    final start = window.first.portfolioValue;
    final end = window.last.portfolioValue;
    if (start <= 0) return null;
    return (end / start) - 1.0;
  }

  /// Top contributor by |weight * cumulative return| over the last 30 days.
  /// Returns null when earnings history is unavailable or no asset clears the
  /// 0.5% absolute-contribution threshold.
  ContributionEntry? get topContributorOver30d {
    final history = _earningsHistory;
    final portfolio = selectedPortfolio;
    if (history == null || portfolio == null) return null;
    if (history.points.length < 2) return null;

    final weights = <AssetClass, double>{};
    for (final alloc in portfolio.sectorAllocations) {
      final cls = _assetCodeToAssetClass(alloc.assetCode);
      if (cls == null) continue;
      weights[cls] = (weights[cls] ?? 0.0) + alloc.weight;
    }
    if (weights.isEmpty) return null;

    final start = history.points.first;
    final end = history.points.last;
    final cutoff = end.date.subtract(const Duration(days: 30));
    final startWindow = history.points.lastWhere(
      (p) => !p.date.isAfter(cutoff),
      orElse: () => start,
    );

    ContributionEntry? best;
    weights.forEach((cls, weight) {
      final code = _assetClassToEarningsCode(cls); // English asset codes; see _assetClassToEarningsCode helper
      if (code == null) return;
      final endValue = end.assetEarnings[code];
      final startValue = startWindow.assetEarnings[code];
      if (endValue == null || startValue == null || startValue == 0) return;
      final assetReturn = (endValue / startValue) - 1.0;
      final impact = weight * assetReturn;
      if (impact.abs() < 0.005) return; // 0.5% threshold
      final entry = ContributionEntry(
        cls: cls,
        label: cls.koLabel,
        weight: weight,
        assetReturn: assetReturn,
        krwImpact: impact,
      );
      if (best == null || impact.abs() > best!.krwImpact.abs()) {
        best = entry;
      }
    });
    return best;
  }

  /// Day-over-day portfolio return as a fraction (e.g., 0.0084 = +0.84%).
  /// Uses the last two `accountHistory` points (sorted by date). Returns null
  /// when fewer than 2 points exist or the prior value is non-positive.
  double? get dailyReturn {
    final history = accountHistory;
    if (history.length < 2) return null;
    final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
    final prior = sorted[sorted.length - 2].portfolioValue;
    final latest = sorted.last.portfolioValue;
    if (prior <= 0) return null;
    return (latest / prior) - 1.0;
  }

  /// Top N contributors by |weight * 1-day asset return|, descending. Uses
  /// the last two earnings-history points. Returns an empty list when data
  /// is missing or no asset clears the 0.05% absolute-contribution threshold.
  List<ContributionEntry> topContributorsOverDay(int n) {
    final history = _earningsHistory;
    final portfolio = selectedPortfolio;
    if (history == null || portfolio == null) return const [];
    if (history.points.length < 2) return const [];

    final weights = <AssetClass, double>{};
    for (final alloc in portfolio.sectorAllocations) {
      final cls = _assetCodeToAssetClass(alloc.assetCode);
      if (cls == null) continue;
      weights[cls] = (weights[cls] ?? 0.0) + alloc.weight;
    }
    if (weights.isEmpty) return const [];

    final sorted = [...history.points]..sort((a, b) => a.date.compareTo(b.date));
    final prior = sorted[sorted.length - 2];
    final latest = sorted.last;

    final entries = <ContributionEntry>[];
    weights.forEach((cls, weight) {
      final code = _assetClassToEarningsCode(cls);
      if (code == null) return;
      final endValue = latest.assetEarnings[code];
      final startValue = prior.assetEarnings[code];
      if (endValue == null || startValue == null || startValue == 0) return;
      final assetReturn = (endValue / startValue) - 1.0;
      final impact = weight * assetReturn;
      // Lower threshold than 30d window — 1-day moves are smaller.
      if (impact.abs() < 0.0005) return;
      entries.add(ContributionEntry(
        cls: cls,
        label: cls.koLabel,
        weight: weight,
        assetReturn: assetReturn,
        krwImpact: impact,
      ));
    });
    entries.sort(
      (a, b) => b.krwImpact.abs().compareTo(a.krwImpact.abs()),
    );
    return entries.take(n).toList();
  }

  /// Portfolio volatility spike: most-recent point >= 1.5x trailing-30d avg.
  /// Returns null when no spike, no data, or insufficient history.
  VolatilitySpike? get portfolioVolatilitySpike {
    final vol = _portfolioVolatility;
    // Need 21 total points: 1 "current" + 20 "trailing window" minimum.
    if (vol == null || vol.points.length < 21) return null;
    final sorted = [...vol.points]..sort((a, b) => a.date.compareTo(b.date));
    final current = sorted.last.volatility;
    final cutoff =
        sorted.last.date.subtract(const Duration(days: 30));
    final window = sorted
        .where(
          (p) =>
              !p.date.isBefore(cutoff) &&
              p.date.isBefore(sorted.last.date),
        )
        .toList();
    if (window.length < 20) return null;
    final avg =
        window.map((p) => p.volatility).reduce((a, b) => a + b) /
            window.length;
    if (avg <= 0) return null;
    final ratio = current / avg;
    if (ratio < 1.5) return null;
    return VolatilitySpike(
      currentVolatility: current,
      averageVolatility: avg,
      percentAboveAverage: ratio - 1.0,
    );
  }

  /// Public setter used by the notification dropdown's on-open volatility
  /// fetch (Task 8).
  void setPortfolioVolatilityHistory(
    MobileVolatilityHistoryResponse? value,
  ) {
    _portfolioVolatility = value;
    notifyListeners();
  }

  // ─── Notification-row internal helpers ────────────────────────────────────

  /// Maps [AssetClass] to the canonical English asset code used as keys in
  /// [MobileEarningsPoint.assetEarnings] (both mock fixture and backend).
  String? _assetClassToEarningsCode(AssetClass cls) {
    // Earnings map keys are English asset codes (canonical form used by both
    // the mock fixture and the backend's earnings endpoints).
    switch (cls) {
      case AssetClass.cash:
        return 'cash_equivalents';
      case AssetClass.shortBond:
        return 'short_term_bond';
      case AssetClass.infraBond:
        return 'infra_bond';
      case AssetClass.gold:
        return 'gold';
      case AssetClass.usValue:
        return 'us_value';
      case AssetClass.usGrowth:
        return 'us_growth';
      case AssetClass.newGrowth:
        return 'new_growth';
    }
  }

  AssetClass? _assetCodeToAssetClass(String assetCode) {
    switch (assetCode) {
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
      case 'innovation':
        return AssetClass.newGrowth;
      default:
        return null;
    }
  }

  bool get isLoggedIn => _authSession != null;
  bool get hasPrototypeAccount => _accountDashboard?.hasAccount == true;
  bool get hasCompletedPortfolioSetup =>
      _frontierSelection != null || _recommendation != null;
  // Keep the completed account data, but do not use it to bypass onboarding.
  // The prototype flow intentionally replays onboarding after app restart/login
  // so users can review the frontier before entering home.
  bool get canAutoEnterHome => false;

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

  void setEarningsHistory(MobileEarningsHistoryResponse? value) {
    _earningsHistory = value;
    notifyListeners();
  }

  /// Per-asset percent change from the prior data point to [date]'s point.
  /// Returns an empty map if [date] is the first point, has no matching
  /// point, or earnings history hasn't been set yet. Skips assets whose
  /// prior value is zero (division by zero).
  Map<String, double> dayOverDayAssetReturns(DateTime date) {
    final history = _earningsHistory;
    if (history == null || history.points.length < 2) {
      return const {};
    }
    final targetIdx = history.points.indexWhere(
      (p) =>
          p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day,
    );
    if (targetIdx < 1) {
      return const {};
    }
    final prior = history.points[targetIdx - 1];
    final current = history.points[targetIdx];
    final result = <String, double>{};
    current.assetEarnings.forEach((code, value) {
      final priorValue = prior.assetEarnings[code];
      if (priorValue == null || priorValue == 0) {
        return;
      }
      result[code] = (value - priorValue) / priorValue;
    });
    return result;
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
    _storySeen = prefs.getBool(_storySeenKey) ?? false;
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
    _earningsHistory = null;
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
    _earningsHistory = null;
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
    // Note: _alertFrequency and _storySeen are intentionally NOT cleared
    // here — they are device-level preferences that should survive
    // logout/login on the same device. The onboarding story plays once per
    // device, not per account.
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
    DateTime? startedAt,
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
      startedAt: startedAt ?? prototypeAccountStartDate(DateTime.now()),
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

  Future<void> markStorySeen() async {
    if (_storySeen) return;
    _storySeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storySeenKey, true);
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
    MobileComparisonLine? line;
    final preferredKeys = <String>[
      if (_frontierSelection != null) 'selected',
      _type.riskCode,
      'selected',
    ];
    for (final key in preferredKeys.toSet()) {
      for (final l in _backtest!.lines) {
        if (l.key == key) {
          line = l;
          break;
        }
      }
      if (line != null) break;
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

  // ─── Test-only setters ────────────────────────────────────────────────────

  @visibleForTesting
  void debugSetAccountDashboard(MobileAccountDashboard dashboard) {
    _accountDashboard = dashboard;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetVolatilityHistory(MobileVolatilityHistoryResponse value) {
    _portfolioVolatility = value;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetInsights(List<RebalanceInsight> insights) {
    _insights = insights;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetRecommendation(MobileRecommendationResponse rec) {
    _recommendation = rec;
    notifyListeners();
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
