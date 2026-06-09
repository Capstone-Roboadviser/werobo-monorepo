import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart' show AssetClass;
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
      final now = DateTime(2026, 5, 12);
      final state = PortfolioState(clock: () => now);
      final history = [
        for (int i = 30; i >= 0; i--)
          _point(now.subtract(Duration(days: i)), 100.0 + (30 - i) * 0.5),
      ];
      state.debugSetAccountDashboard(_dashboardWith(history));
      // With the clock pinned to 2026-05-12, the 30-day window spans the full
      // synthetic history (2026-04-12 → 2026-05-12), so the value moves from
      // 100 to 115: +15%.
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

  group('trailingWeekReturn', () {
    test('returns positive percent when value rose over the trailing week', () {
      final now = DateTime(2026, 5, 12);
      final state = PortfolioState(clock: () => now);
      final history = [
        for (int i = 7; i >= 0; i--)
          _point(now.subtract(Duration(days: i)), 100.0 + (7 - i) * 1.0),
      ];
      state.debugSetAccountDashboard(_dashboardWith(history));
      // With the clock pinned to 2026-05-12, the 7-day window spans
      // 2026-05-05 → 2026-05-12, so the value moves from 100 to 107: +7%.
      expect(state.trailingWeekReturn, closeTo(0.07, 0.01));
    });
  });

  group('dailyReturn', () {
    test('returns null when fewer than 2 history points exist', () {
      final state = PortfolioState();
      state.debugSetAccountDashboard(_dashboardWith(const []));
      expect(state.dailyReturn, isNull);

      state.debugSetAccountDashboard(_dashboardWith([
        _point(DateTime(2026, 5, 12), 100),
      ]));
      expect(state.dailyReturn, isNull);
    });

    test('returns the day-over-day percent change from the last two points',
        () {
      final state = PortfolioState();
      state.debugSetAccountDashboard(_dashboardWith([
        _point(DateTime(2026, 5, 11), 100),
        _point(DateTime(2026, 5, 12), 100.84),
      ]));
      expect(state.dailyReturn, closeTo(0.0084, 1e-9));
    });

    test('handles unsorted history by sorting before picking last two', () {
      final state = PortfolioState();
      // Insert latest first to verify the helper sorts before slicing.
      state.debugSetAccountDashboard(_dashboardWith([
        _point(DateTime(2026, 5, 12), 99),
        _point(DateTime(2026, 5, 11), 100),
      ]));
      expect(state.dailyReturn, closeTo(-0.01, 1e-9));
    });
  });

  group('topContributorOver30d', () {
    test('returns null when earnings history is missing', () {
      final state = PortfolioState();
      expect(state.topContributorOver30d, isNull);
    });

    test('picks asset with highest absolute contribution above threshold', () {
      final state = PortfolioState();

      // Set up: a portfolio that holds 50% us_growth and 50% short_term_bond.
      // Earnings history: two points, 30 days apart.
      //   us_growth: 100 → 120  (+20% return, weight 0.5 → +10% contribution)
      //   short_term_bond: 100 → 102 (+2% return, weight 0.5 → +1% contribution)
      // Expected winner: us_growth.
      final start = DateTime(2026, 4, 12);
      final end = DateTime(2026, 5, 12);
      final earnings = MobileEarningsHistoryResponse(
        points: [
          MobileEarningsPoint(
            date: start,
            totalEarnings: 0,
            totalReturnPct: 0,
            assetEarnings: {'us_growth': 100.0, 'short_term_bond': 100.0},
          ),
          MobileEarningsPoint(
            date: end,
            totalEarnings: 22,
            totalReturnPct: 11,
            assetEarnings: {'us_growth': 120.0, 'short_term_bond': 102.0},
          ),
        ],
        investmentAmount: 200.0,
        startDate: '2026-04-12',
        endDate: '2026-05-12',
        totalReturnPct: 11,
        totalEarnings: 22,
        assetSummary: const [],
      );
      state.setEarningsHistory(earnings);

      // Set up: matching sector allocations (50/50).
      state.debugSetRecommendation(MobileRecommendationResponse(
        resolvedProfile: const MobileResolvedProfile(
          code: 'balanced',
          label: '균형형',
          propensityScore: null,
          targetVolatility: 0.1,
          investmentHorizon: 'medium',
        ),
        recommendedPortfolioCode: 'balanced',
        dataSource: 'test',
        asOfDate: null,
        portfolios: [
          const MobilePortfolioRecommendation(
            code: 'balanced',
            label: 'Balanced',
            portfolioId: '1',
            targetVolatility: 0.1,
            expectedReturn: 0.08,
            volatility: 0.1,
            sharpeRatio: 0.8,
            sectorAllocations: [
              MobileSectorAllocation(
                assetCode: 'us_growth',
                assetName: 'US Growth',
                weight: 0.5,
                riskContribution: 0.5,
              ),
              MobileSectorAllocation(
                assetCode: 'short_term_bond',
                assetName: 'Short Bond',
                weight: 0.5,
                riskContribution: 0.5,
              ),
            ],
            stockAllocations: [],
          ),
        ],
      ));

      final top = state.topContributorOver30d;
      expect(top, isNotNull);
      expect(top!.cls, AssetClass.usGrowth);
      expect(top.weight, 0.5);
      expect(top.assetReturn, closeTo(0.20, 0.001));
      expect(top.krwImpact, closeTo(0.10, 0.001));
    });

    test('returns null when no asset clears the 0.5% threshold', () {
      final state = PortfolioState();
      final start = DateTime(2026, 4, 12);
      final end = DateTime(2026, 5, 12);
      // 50% weight x 0.5% return = 0.25% impact, below 0.5% threshold.
      final earnings = MobileEarningsHistoryResponse(
        points: [
          MobileEarningsPoint(
            date: start,
            totalEarnings: 0,
            totalReturnPct: 0,
            assetEarnings: {'us_growth': 100.0},
          ),
          MobileEarningsPoint(
            date: end,
            totalEarnings: 0.25,
            totalReturnPct: 0.25,
            assetEarnings: {'us_growth': 100.5},
          ),
        ],
        investmentAmount: 100.0,
        startDate: '2026-04-12',
        endDate: '2026-05-12',
        totalReturnPct: 0.25,
        totalEarnings: 0.25,
        assetSummary: const [],
      );
      state.setEarningsHistory(earnings);
      state.debugSetRecommendation(MobileRecommendationResponse(
        resolvedProfile: const MobileResolvedProfile(
          code: 'balanced',
          label: '균형형',
          propensityScore: null,
          targetVolatility: 0.1,
          investmentHorizon: 'medium',
        ),
        recommendedPortfolioCode: 'balanced',
        dataSource: 'test',
        asOfDate: null,
        portfolios: [
          const MobilePortfolioRecommendation(
            code: 'balanced',
            label: 'Balanced',
            portfolioId: '1',
            targetVolatility: 0.1,
            expectedReturn: 0.08,
            volatility: 0.1,
            sharpeRatio: 0.8,
            sectorAllocations: [
              MobileSectorAllocation(
                assetCode: 'us_growth',
                assetName: 'US Growth',
                weight: 0.5,
                riskContribution: 0.5,
              ),
            ],
            stockAllocations: [],
          ),
        ],
      ));
      expect(state.topContributorOver30d, isNull);
    });
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
