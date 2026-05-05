import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/models/portfolio_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PortfolioState', () {
    late PortfolioState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = PortfolioState();
    });

    tearDown(() {
      state.dispose();
    });

    test('defaults to balanced', () {
      expect(state.type, InvestmentType.balanced);
    });

    test('setType updates the type', () {
      state.setType(InvestmentType.safe);
      expect(state.type, InvestmentType.safe);
    });

    test('setType notifies listeners', () {
      var notified = false;
      state.addListener(() => notified = true);
      state.setType(InvestmentType.growth);
      expect(notified, true);
    });

    test('setType does not notify when value unchanged', () {
      var notifyCount = 0;
      state.addListener(() => notifyCount++);
      state.setType(InvestmentType.balanced); // same as default
      expect(notifyCount, 0);
    });

    test('setFromDotT maps correctly', () {
      state.setFromDotT(0.1);
      expect(state.type, InvestmentType.safe);

      state.setFromDotT(0.5);
      expect(state.type, InvestmentType.balanced);

      state.setFromDotT(0.9);
      expect(state.type, InvestmentType.growth);
    });

    test('restorePersistedState restores auth session and portfolio bootstrap',
        () async {
      SharedPreferences.setMockInitialValues({
        'werobo.auth_session': '''
{"access_token":"token-1","token_type":"bearer","expires_at":"2099-01-01T00:00:00Z","user":{"id":7,"email":"user@example.com","name":"홍길동","provider":"password","created_at":"2026-04-13T00:00:00Z"}}
''',
        'werobo.portfolio_bootstrap': '''
{"selected_type":"balanced","recommendation":{"resolved_profile":{"code":"balanced","label":"균형형","propensity_score":45,"target_volatility":0.12,"investment_horizon":"medium"},"recommended_portfolio_code":"balanced","data_source":"managed_universe","portfolios":[{"code":"balanced","label":"균형형","portfolio_id":"p1","target_volatility":0.12,"expected_return":0.08,"volatility":0.11,"sharpe_ratio":0.7,"sector_allocations":[],"stock_allocations":[]}]},"frontier_selection":null}
''',
      });
      state = PortfolioState();

      await state.restorePersistedState();

      expect(state.isLoggedIn, true);
      expect(state.currentUser?.email, 'user@example.com');
      expect(state.type, InvestmentType.balanced);
      expect(state.recommendation?.recommendedPortfolioCode, 'balanced');
      expect(state.canAutoEnterHome, true);
    });

    test('setAuthSession persists provider-aware session', () async {
      final session = MobileAuthSession(
        accessToken: 'token-2',
        tokenType: 'bearer',
        expiresAt: '2099-01-01T00:00:00Z',
        user: const MobileAuthUser(
          id: 1,
          email: 'investor@werobo.app',
          name: '홍길동',
          provider: AuthProviderType.password,
          createdAt: '2026-04-13T00:00:00Z',
        ),
      );

      await state.setAuthSession(session);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('werobo.auth_session');
      expect(raw, isNotNull);
      expect(raw, contains('"provider":"password"'));
    });

    test('selectedPortfolio prefers exact frontier selection over type bucket',
        () {
      const recommendation = MobileRecommendationResponse(
        resolvedProfile: MobileResolvedProfile(
          code: 'balanced',
          label: '균형형',
          propensityScore: 45,
          targetVolatility: 0.12,
          investmentHorizon: 'medium',
        ),
        recommendedPortfolioCode: 'balanced',
        dataSource: 'managed_universe',
        portfolios: [
          MobilePortfolioRecommendation(
            code: 'balanced',
            label: '균형형',
            portfolioId: 'balanced-id',
            targetVolatility: 0.12,
            expectedReturn: 0.08,
            volatility: 0.12,
            sharpeRatio: 0.7,
            sectorAllocations: [],
            stockAllocations: [],
          ),
        ],
      );
      const selected = MobileFrontierSelectionResponse(
        resolvedProfile: MobileResolvedProfile(
          code: 'balanced',
          label: '균형형',
          propensityScore: 45,
          targetVolatility: 0.12,
          investmentHorizon: 'medium',
        ),
        dataSource: 'managed_universe',
        requestedTargetVolatility: 0.151,
        selectedTargetVolatility: 0.16,
        selectedPointIndex: 19,
        totalPointCount: 80,
        representativeCode: 'growth',
        representativeLabel: '성장형',
        portfolio: MobilePortfolioRecommendation(
          code: 'selected',
          label: '선택 포트폴리오',
          portfolioId: 'selected-id',
          targetVolatility: 0.16,
          expectedReturn: 0.11,
          volatility: 0.16,
          sharpeRatio: 0.8,
          sectorAllocations: [],
          stockAllocations: [],
        ),
      );

      state.setRecommendation(recommendation);
      state.setFrontierSelection(selected);

      expect(state.type, InvestmentType.balanced);
      expect(state.selectedPortfolio?.code, 'selected');
      expect(state.selectedPortfolio?.expectedReturn, 0.11);
    });

    test('portfolioValuePoints uses selected backtest line for frontier point',
        () {
      const selected = MobileFrontierSelectionResponse(
        resolvedProfile: MobileResolvedProfile(
          code: 'balanced',
          label: '균형형',
          propensityScore: 45,
          targetVolatility: 0.12,
          investmentHorizon: 'medium',
        ),
        dataSource: 'managed_universe',
        requestedTargetVolatility: 0.151,
        selectedTargetVolatility: 0.16,
        selectedPointIndex: 19,
        totalPointCount: 80,
        representativeCode: 'growth',
        representativeLabel: '성장형',
        portfolio: MobilePortfolioRecommendation(
          code: 'selected',
          label: '선택 포트폴리오',
          portfolioId: 'selected-id',
          targetVolatility: 0.16,
          expectedReturn: 0.11,
          volatility: 0.16,
          sharpeRatio: 0.8,
          sectorAllocations: [],
          stockAllocations: [],
        ),
      );
      final backtest = MobileComparisonBacktestResponse(
        trainStartDate: DateTime(2024),
        trainEndDate: DateTime(2024, 1, 1),
        testStartDate: DateTime(2024, 1, 2),
        startDate: DateTime(2024, 1, 2),
        endDate: DateTime(2024, 1, 3),
        splitRatio: 0.9,
        rebalanceDates: const [],
        lines: [
          MobileComparisonLine(
            key: 'selected',
            label: '선택 포트폴리오',
            color: '#20A7DB',
            style: 'solid',
            points: [
              MobileComparisonLinePoint(
                date: DateTime(2024, 1, 2),
                returnPct: 0.0,
              ),
              MobileComparisonLinePoint(
                date: DateTime(2024, 1, 3),
                returnPct: 0.2,
              ),
            ],
          ),
        ],
      );

      state.setFrontierSelection(selected);
      state.setBacktest(backtest);

      final points = state.portfolioValuePoints(baseInvestment: 100);

      expect(points, hasLength(2));
      expect(points.last.value, 120);
    });
  });
}
