import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chart_data.dart';
import '../models/mobile_backend_models.dart';
import '../models/portfolio_data.dart';
import '../services/mobile_backend_api.dart';

/// App-level state holder for auth, onboarding bootstrap state, and portfolio data.
class PortfolioState extends ChangeNotifier {
  static const String _authSessionStorageKey = 'werobo.auth_session';
  static const String _portfolioBootstrapStorageKey =
      'werobo.portfolio_bootstrap';

  InvestmentType _type = InvestmentType.balanced;
  MobileRecommendationResponse? _recommendation;
  MobileComparisonBacktestResponse? _backtest;
  MobileFrontierPreviewResponse? _frontierPreview;
  MobileFrontierSelectionResponse? _frontierSelection;
  MobileAuthSession? _authSession;
  MobileAccountDashboard? _accountDashboard;

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
  bool get isLoggedIn => _authSession != null;
  bool get hasPrototypeAccount => _accountDashboard?.hasAccount == true;
  bool get hasCompletedPortfolioSetup =>
      _frontierSelection != null || _recommendation != null;
  bool get canAutoEnterHome =>
      isLoggedIn && (hasCompletedPortfolioSetup || hasPrototypeAccount);

  /// The selected portfolio from the API recommendation.
  MobilePortfolioRecommendation? get selectedPortfolio {
    if (_frontierSelection != null) {
      return _frontierSelection!.portfolio;
    }
    if (_recommendation == null) return null;
    for (final p in _recommendation!.portfolios) {
      if (p.investmentType == _type) return p;
    }
    final accountSummary = _accountDashboard?.summary;
    if (accountSummary == null) {
      return null;
    }
    if (investmentTypeFromRiskCode(accountSummary.portfolioCode) != _type) {
      return null;
    }
    return MobilePortfolioRecommendation(
      code: accountSummary.portfolioCode,
      label: accountSummary.portfolioLabel,
      portfolioId: accountSummary.portfolioId,
      targetVolatility: accountSummary.targetVolatility,
      expectedReturn: accountSummary.expectedReturn,
      volatility: accountSummary.volatility,
      sharpeRatio: accountSummary.sharpeRatio,
      sectorAllocations: accountSummary.sectorAllocations,
      stockAllocations: accountSummary.stockAllocations,
    );
  }

  List<PortfolioCategory> get categories {
    return selectedPortfolio?.toCategories() ?? const [];
  }

  List<PortfolioCategoryDetail> get categoryDetails {
    return selectedPortfolio?.toCategoryDetails() ?? const [];
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

  Future<void> restorePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await _restoreAuthSessionFromPrefs(prefs);
    await _restorePortfolioBootstrapFromPrefs(prefs);
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
    _frontierPreview = null;
    _backtest = null;
    _accountDashboard = null;
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
    _accountDashboard = null;
    if (notify) {
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authSessionStorageKey);
    await prefs.remove(_portfolioBootstrapStorageKey);
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
      _accountDashboard = null;
      if (notify) {
        notifyListeners();
      }
      return null;
    }

    try {
      final dashboard = await MobileBackendApi.instance
          .fetchPortfolioAccountDashboard(accessToken: accessToken);
      _accountDashboard = dashboard;
      final summary = dashboard.summary;
      if (summary != null) {
        _type = investmentTypeFromRiskCode(summary.portfolioCode);
      }
      if (notify) {
        notifyListeners();
      }
      return dashboard;
    } on MobileBackendException catch (error) {
      if (error.statusCode == 401) {
        await clearAllPersistedState(notify: true);
        return null;
      }
      rethrow;
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
    );
    _accountDashboard = dashboard;
    final summary = dashboard.summary;
    if (summary != null) {
      _type = investmentTypeFromRiskCode(summary.portfolioCode);
    }
    notifyListeners();
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
    _accountDashboard = dashboard;
    final summary = dashboard.summary;
    if (summary != null) {
      _type = investmentTypeFromRiskCode(summary.portfolioCode);
    }
    notifyListeners();
    return dashboard;
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
    return _backtest!.lines
        .map((line) => ChartLine(
              key: line.key,
              label: line.label,
              color: parseBackendHexColor(line.color),
              dashed: line.style != 'solid',
              points: line.points
                  .map((p) => ChartPoint(date: p.date, value: p.returnPct))
                  .toList(),
            ))
        .toList();
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
      final frontierPreviewJson = decoded['frontier_preview'];
      if (frontierPreviewJson is Map<String, dynamic>) {
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
