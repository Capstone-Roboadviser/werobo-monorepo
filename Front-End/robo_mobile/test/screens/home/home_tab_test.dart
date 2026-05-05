import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/home_tab.dart';
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

  MobileDigestResponse digestFixture({required bool available}) {
    return MobileDigestResponse(
      digestDate: '2026-04-29',
      periodStart: '2026-04-22',
      periodEnd: '2026-04-29',
      totalReturnPct: available ? 6.0 : 1.5,
      totalReturnWon: available ? 600000 : 150000,
      hasNarrative: false,
      available: available,
      drivers: const [],
      detractors: const [],
      sourcesUsed: const [],
      disclaimer: '',
      generatedAt: '2026-04-29T00:00:00Z',
      degradationLevel: 0,
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

  testWidgets('shows reserve cash as separate from portfolio allocation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();
    await state.markDigestSeen('2026-04-16');

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(
            body: HomeTab(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('포트폴리오 구성'), findsOneWidget);
    expect(find.text('예비 현금'), findsOneWidget);
    expect(find.text('포트폴리오 구성 비중에는 포함되지 않아요.'), findsOneWidget);
    expect(find.text('리밸런싱 시 별도로 보관됐다가 자동 사용돼요.'), findsOneWidget);
    expect(find.text('₩25,000'), findsOneWidget);
  });

  testWidgets('digest banner hidden when digest is unavailable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    state.setWeeklyDigest(digestFixture(available: false));
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('주간 다이제스트'), findsNothing);
  });

  testWidgets('digest banner hidden when already seen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    state.setWeeklyDigest(digestFixture(available: true));
    await state.markWelcomeBannerSeen();
    await state.markDigestSeen('2026-04-29');

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('주간 다이제스트'), findsNothing);
  });

  testWidgets('digest banner shown when available and unseen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    state.setWeeklyDigest(digestFixture(available: true));
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('주간 다이제스트'), findsOneWidget);
  });

  testWidgets('hero chart no longer shows the deposit total text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    // The cost-basis "deposit" line and its label are removed in this change.
    expect(find.textContaining('총 입금'), findsNothing);
  });

  testWidgets('chart legend renders all four static labels unconditionally',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    // Even with no backtest wired, the legend shows the four labels
    // (lines themselves render only when data exists).
    expect(find.text('포트폴리오'), findsOneWidget);
    expect(find.text('시장'), findsOneWidget);
    expect(find.text('연 기대수익률'), findsOneWidget);
    expect(find.text('채권'), findsOneWidget);
  });

  testWidgets('falls back to mock earnings history when API fails',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    // Use the standard dashboard fixture (startedAt non-empty, portfolio
    // non-null) so the code takes the try/catch path and hits the real
    // network. In the widget-test environment the calls return 400 almost
    // immediately, and the catch block populates state with mock data.
    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();
    await state.markDigestSeen('2026-04-16');

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    // Flush the first frame (didChangeDependencies fires, fetch kicks off).
    await tester.pump(const Duration(milliseconds: 800));
    // The API calls fail quickly (400 from Railway in test env); one more
    // pump lets the catch block run and notifyListeners propagate.
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.earningsHistory, isNotNull);
    expect(state.earningsHistory!.points, isNotEmpty);
  });

  testWidgets('drag at index >= 1 reveals context card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(
      MobileAccountDashboard(
        hasAccount: true,
        summary: accountDashboard().summary,
        history: List.generate(
          60,
          (i) => MobileAccountHistoryPoint(
            date: DateTime.now().subtract(Duration(days: 60 - i)),
            portfolioValue: 10000000 + (i * 5000),
            investedAmount: 10000000,
            profitLoss: i * 5000,
            profitLossPct: (i * 5000) / 10000000,
          ),
        ),
        recentActivity: const [],
      ),
    );
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));

    // Drag onto the chart at a non-zero index.
    final chart = find.byType(CustomPaint).first;
    final center = tester.getCenter(chart);
    await tester.dragFrom(center, const Offset(20, 0));
    await tester.pump();

    // Card should show a date label like "X월 Y일" and the 포트폴리오 row.
    expect(find.textContaining('월'), findsWidgets);
    expect(find.text('포트폴리오'), findsAtLeastNWidgets(1));
  });
}
