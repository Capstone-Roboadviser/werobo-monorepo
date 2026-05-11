import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

MobileAccountDashboard _dashboardWith(List<MobileAccountHistoryPoint> history) {
  return MobileAccountDashboard(
    hasAccount: true,
    summary: null,
    history: history,
    recentActivity: const [],
  );
}

MobileAccountHistoryPoint _point(DateTime d, double value) {
  return MobileAccountHistoryPoint(
    date: d,
    portfolioValue: value,
    investedAmount: value,
    profitLoss: 0,
    profitLossPct: 0,
  );
}

void main() {
  group('trailingMonthReturn', () {
    test('returns positive percent when value rose over 30 days', () {
      final state = PortfolioState();
      final now = DateTime(2026, 5, 12);
      final history = [
        for (int i = 30; i >= 0; i--)
          _point(now.subtract(Duration(days: i)), 100.0 + (30 - i) * 0.5),
      ];
      state.debugSetAccountDashboard(_dashboardWith(history));
      // Value moved from ~100 to 115 over the window (exact start point
      // depends on the time-of-day cutoff, so we verify direction and
      // rough magnitude).
      expect(state.trailingMonthReturn, closeTo(0.15, 0.01));
    });

    test('returns null when fewer than 20 points in window', () {
      final state = PortfolioState();
      final now = DateTime(2026, 5, 12);
      final history = [
        for (int i = 10; i >= 0; i--)
          _point(now.subtract(Duration(days: i)), 100.0),
      ];
      state.debugSetAccountDashboard(_dashboardWith(history));
      expect(state.trailingMonthReturn, isNull);
    });
  });

  group('topContributorOver30d', () {
    test('returns null when earnings history is missing', () {
      final state = PortfolioState();
      expect(state.topContributorOver30d, isNull);
    });
    // Full earnings-history fixture covered by widget-level smoke later.
  });

  group('portfolioVolatilitySpike', () {
    test('returns null when no volatility history set', () {
      final state = PortfolioState();
      expect(state.portfolioVolatilitySpike, isNull);
    });

    test('returns spike when last point exceeds 1.5x trailing-30d avg', () {
      final state = PortfolioState();
      final today = DateTime(2026, 5, 12);
      final points = <MobileVolatilityPoint>[
        for (int i = 30; i >= 1; i--)
          MobileVolatilityPoint(
            date: today.subtract(Duration(days: i)),
            volatility: 0.10,
          ),
        MobileVolatilityPoint(date: today, volatility: 0.20),
      ];
      state.debugSetVolatilityHistory(MobileVolatilityHistoryResponse(
        portfolioCode: 'X',
        portfolioLabel: 'X',
        rollingWindow: 20,
        earliestDataDate: today.subtract(const Duration(days: 30)),
        latestDataDate: today,
        points: points,
      ));
      final spike = state.portfolioVolatilitySpike;
      expect(spike, isNotNull);
      expect(spike!.percentAboveAverage, closeTo(1.0, 0.01));
    });

    test('returns null when last point is below threshold', () {
      final state = PortfolioState();
      final today = DateTime(2026, 5, 12);
      final points = <MobileVolatilityPoint>[
        for (int i = 30; i >= 1; i--)
          MobileVolatilityPoint(
            date: today.subtract(Duration(days: i)),
            volatility: 0.10,
          ),
        MobileVolatilityPoint(date: today, volatility: 0.12),
      ];
      state.debugSetVolatilityHistory(MobileVolatilityHistoryResponse(
        portfolioCode: 'X',
        portfolioLabel: 'X',
        rollingWindow: 20,
        earliestDataDate: today.subtract(const Duration(days: 30)),
        latestDataDate: today,
        points: points,
      ));
      expect(state.portfolioVolatilitySpike, isNull);
    });
  });
}
