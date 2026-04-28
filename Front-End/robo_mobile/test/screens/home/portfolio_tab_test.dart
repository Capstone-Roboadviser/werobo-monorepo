import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/portfolio_tab.dart';

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

  MobileAccountDashboard accountDashboard() {
    return MobileAccountDashboard(
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
    );
  }

  MobileComparisonBacktestResponse comparisonBacktest() {
    return MobileComparisonBacktestResponse(
      trainStartDate: DateTime(2025, 1, 1),
      trainEndDate: DateTime(2025, 12, 31),
      testStartDate: DateTime(2026, 1, 1),
      startDate: DateTime(2026, 2, 28),
      endDate: DateTime(2026, 3, 2),
      splitRatio: 0.8,
      rebalanceDates: [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      ],
      rebalancePolicy: null,
      lines: [
        MobileComparisonLine(
          key: 'balanced',
          label: '균형형',
          color: '#20A7DB',
          style: 'solid',
          points: [
            MobileComparisonLinePoint(
              date: DateTime(2026, 2, 28),
              returnPct: 0.02,
            ),
            MobileComparisonLinePoint(
              date: DateTime(2026, 3, 1),
              returnPct: 0.07,
            ),
            MobileComparisonLinePoint(
              date: DateTime(2026, 3, 2),
              returnPct: 0.09,
            ),
          ],
        ),
      ],
    );
  }

  group('home portfolio comparison inputs', () {
    late PortfolioState state;

    setUp(() {
      state = PortfolioState();
      state.setAccountDashboard(accountDashboard());
      state.setBacktest(comparisonBacktest());
    });

    tearDown(() {
      state.dispose();
    });

    test('filters comparison lines from the account start date', () {
      final lines = buildHomePortfolioComparisonLines(state);
      final portfolioLine = lines.singleWhere((line) => line.key == 'balanced');

      expect(portfolioLine.points, hasLength(2));
      expect(portfolioLine.points.first.date, DateTime(2026, 3, 1));
      expect(portfolioLine.points.first.value, 0.0);
      expect(portfolioLine.points.last.value, closeTo(0.0186915888, 1e-9));
    });

    test('still filters rebalance dates from the account start date', () {
      final rebalanceDates = buildHomePortfolioRebalanceDates(state);

      expect(rebalanceDates, hasLength(2));
      expect(rebalanceDates.first, DateTime(2026, 3, 1));
      expect(rebalanceDates.last, DateTime(2026, 3, 2));
    });
  });
}
