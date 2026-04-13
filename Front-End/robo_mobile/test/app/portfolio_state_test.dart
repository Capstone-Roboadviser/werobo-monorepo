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
  });
}
