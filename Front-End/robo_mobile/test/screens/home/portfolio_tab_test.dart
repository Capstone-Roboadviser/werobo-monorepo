import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/chart_data.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/models/portfolio_data.dart';
import 'package:robo_mobile/screens/home/portfolio_tab.dart';
import 'package:robo_mobile/screens/onboarding/widgets/portfolio_charts.dart';

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
          color: _hexFromColor(WeRoboColors.assetColor(AssetClass.usValue)),
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

  testWidgets('shows home allocation rows and cash sections in portfolio tab',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setAccountDashboard(accountDashboard());
    state.setBacktest(comparisonBacktest());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: PortfolioTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('포트폴리오 구성'), findsOneWidget);
    expect(find.text('미국 가치주'), findsWidgets);
    expect(find.text('VTV'), findsOneWidget);
    expect(find.text('60.00%'), findsOneWidget);
    expect(find.text('금'), findsWidgets);
    expect(find.text('GLD'), findsOneWidget);
    expect(find.text('40.00%'), findsOneWidget);

    expect(find.text('입금 현황'), findsOneWidget);
    expect(find.text('예비 현금'), findsOneWidget);
    expect(find.text('포트폴리오 구성 비중에는 포함되지 않아요.'), findsOneWidget);
    expect(find.text('25,000 원'), findsOneWidget);
  });

  group('volatility view market benchmark', () {
    List<ChartPoint> makePoints(int count) {
      return List.generate(
        count,
        (i) => ChartPoint(
          date: DateTime(2025, 1, 1).add(Duration(days: i * 7)),
          value: 0.10 + i * 0.001,
        ),
      );
    }

    testWidgets(
        'renders market benchmark legend label when market data is present',
        (tester) async {
      final portfolioPoints = makePoints(10);
      final marketPoints = makePoints(10);

      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PortfolioCharts(
                type: InvestmentType.balanced,
                volatilityPoints: portfolioPoints,
                marketVolatilityPoints: marketPoints,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('시장 변동성'), findsOneWidget);
      expect(find.text('내 포트폴리오 변동성'), findsOneWidget);
    });

    testWidgets(
        'does not render market benchmark legend when market data is absent',
        (tester) async {
      final portfolioPoints = makePoints(10);

      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PortfolioCharts(
                type: InvestmentType.balanced,
                volatilityPoints: portfolioPoints,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('시장 변동성'), findsNothing);
    });

    testWidgets(
        'renders without crashing when market series has different length',
        (tester) async {
      final portfolioPoints = makePoints(20);
      final marketPoints = makePoints(8);

      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PortfolioCharts(
                type: InvestmentType.balanced,
                volatilityPoints: portfolioPoints,
                marketVolatilityPoints: marketPoints,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('시장 변동성'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

String _hexFromColor(Color color) {
  // ignore: deprecated_member_use
  final argb = color.value & 0xFFFFFF;
  return '#${argb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
