import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/models/portfolio_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  MobileSectorAllocation sector({
    required String code,
    required String name,
    required double weight,
  }) {
    return MobileSectorAllocation(
      assetCode: code,
      assetName: name,
      weight: weight,
      riskContribution: weight,
    );
  }

  MobileStockAllocation stock({
    required String ticker,
    required String name,
    required String sectorCode,
    required String sectorName,
    required double weight,
  }) {
    return MobileStockAllocation(
      ticker: ticker,
      name: name,
      sectorCode: sectorCode,
      sectorName: sectorName,
      weight: weight,
    );
  }

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

    test('restorePersistedState ignores stale cached frontier preview version',
        () async {
      SharedPreferences.setMockInitialValues({
        'werobo.portfolio_bootstrap': '''
{"selected_type":"balanced","recommendation":{"resolved_profile":{"code":"balanced","label":"균형형","propensity_score":45,"target_volatility":0.12,"investment_horizon":"medium"},"recommended_portfolio_code":"balanced","data_source":"managed_universe","portfolios":[{"code":"balanced","label":"균형형","portfolio_id":"p1","target_volatility":0.12,"expected_return":0.08,"volatility":0.11,"sharpe_ratio":0.7,"sector_allocations":[],"stock_allocations":[]}]},"frontier_selection":null,"frontier_preview_version":1,"frontier_preview":{"resolved_profile":{"code":"balanced","label":"균형형","propensity_score":45,"target_volatility":0.12,"investment_horizon":"medium"},"recommended_portfolio_code":"balanced","data_source":"managed_universe","total_point_count":2,"min_volatility":0.05,"max_volatility":0.10,"points":[{"index":0,"volatility":0.05,"expected_return":0.04,"is_recommended":true}]}}
''',
      });
      state = PortfolioState();

      await state.restorePersistedState();

      expect(state.recommendation?.recommendedPortfolioCode, 'balanced');
      expect(state.frontierPreview, isNull);
    });

    test('selectedPortfolio prefers account dashboard over cached selection',
        () {
      state.setFrontierSelection(
        MobileFrontierSelectionResponse(
          resolvedProfile: const MobileResolvedProfile(
            code: 'balanced',
            label: '균형형',
            propensityScore: 45,
            targetVolatility: 0.12,
            investmentHorizon: 'medium',
          ),
          dataSource: 'managed_universe',
          asOfDate: null,
          requestedTargetVolatility: 0.12,
          selectedTargetVolatility: 0.12,
          selectedPointIndex: 30,
          totalPointCount: 61,
          representativeCode: 'balanced',
          representativeLabel: '균형형',
          portfolio: const MobilePortfolioRecommendation(
            code: 'balanced',
            label: '균형형',
            portfolioId: 'cached-portfolio',
            targetVolatility: 0.12,
            expectedReturn: 0.08,
            volatility: 0.11,
            sharpeRatio: 0.7,
            sectorAllocations: [],
            stockAllocations: [],
          ),
        ),
      );

      state.setAccountDashboard(
        MobileAccountDashboard(
          hasAccount: true,
          summary: MobileAccountSummary(
            portfolioCode: 'balanced',
            portfolioLabel: '균형형',
            portfolioId: 'account-portfolio',
            dataSource: 'managed_universe',
            investmentHorizon: 'medium',
            targetVolatility: 0.12,
            expectedReturn: 0.08,
            volatility: 0.11,
            sharpeRatio: 0.7,
            startedAt: '2026-03-01',
            lastSnapshotDate: '2026-04-15',
            currentValue: 10500000,
            investedAmount: 10000000,
            profitLoss: 500000,
            cashBalance: 25000,
            profitLossPct: 0.05,
            sectorAllocations: [
              sector(code: 'us_value', name: '미국 가치주', weight: 0.6),
              sector(code: 'gold', name: '금', weight: 0.4),
            ],
            stockAllocations: [
              stock(
                ticker: 'VTV',
                name: 'Vanguard Value ETF',
                sectorCode: 'us_value',
                sectorName: '미국 가치주',
                weight: 0.6,
              ),
              stock(
                ticker: 'GLD',
                name: 'SPDR Gold Shares',
                sectorCode: 'gold',
                sectorName: '금',
                weight: 0.4,
              ),
            ],
          ),
          history: const [],
          recentActivity: const [],
        ),
      );

      expect(state.selectedPortfolio, isNotNull);
      expect(state.selectedPortfolio?.portfolioId, 'account-portfolio');
      expect(state.categories, isNotEmpty);
      expect(state.categoryDetails, isNotEmpty);
    });
  });
}
