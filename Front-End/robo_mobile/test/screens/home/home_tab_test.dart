import 'dart:async';

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

  MobileDigestResponse digestFixture({
    required bool available,
    List<DigestDriver> drivers = const [],
    double? triggerSigmaMultiple,
    String periodStart = '2026-04-22',
    String periodEnd = '2026-04-29',
  }) {
    return MobileDigestResponse(
      digestDate: '2026-04-29',
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalReturnPct: available ? 6.0 : 1.5,
      totalReturnWon: available ? 600000 : 150000,
      hasNarrative: false,
      available: available,
      drivers: drivers,
      detractors: const [],
      sourcesUsed: const [],
      disclaimer: '',
      generatedAt: '2026-04-29T00:00:00Z',
      degradationLevel: 0,
      triggerSigmaMultiple: triggerSigmaMultiple,
    );
  }

  MobileRangeDigestResponse rangeDigestFixture() {
    return const MobileRangeDigestResponse(
      periodStart: '2026-04-10',
      periodEnd: '2026-04-18',
      totalReturnPct: 2.4,
      totalReturnWon: 240000,
      narrativeKo: '미국 성장주 반등이 선택 구간 수익을 이끌었어요.',
      hasNarrative: true,
      drivers: [
        DigestDriver(
          ticker: 'QQQ',
          nameKo: '미국 성장주',
          sectorCode: 'us_growth',
          weightPct: 60,
          returnPct: 4,
          contributionWon: 180000,
          explanationKo: '기술주 반등이 기여했어요.',
        ),
      ],
      detractors: [],
      referenceNews: [
        RangeDigestNewsItem(
          ticker: 'QQQ',
          title: 'Tech shares rise on earnings optimism',
        ),
      ],
      sourcesUsed: ['Google News'],
      disclaimer: '이 내용은 투자 조언이 아닙니다.',
      generatedAt: '2026-04-18T00:00:00Z',
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
          sector(code: 'cash_equivalents', name: '현금성자산', weight: 0.6),
          sector(code: 'short_term_bond', name: '단기 채권', weight: 0.4),
        ],
        stockAllocations: [
          stock(
            ticker: 'BIL',
            name: 'State Street SPDR Bloomberg 1-3',
            sectorCode: 'cash_equivalents',
            sectorName: '현금성자산',
            weight: 0.6,
          ),
          stock(
            ticker: 'AGG',
            name: 'iShares Core U.S. Aggregate Bond',
            sectorCode: 'short_term_bond',
            sectorName: '단기 채권',
            weight: 0.4,
          ),
        ],
      ),
      history: const [],
      recentActivity: const [],
    );
  }

  test('earnings history request weights use ticker codes, not sector codes',
      () {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setAccountDashboard(accountDashboard());
    final portfolio = state.selectedPortfolio!;

    expect(
      earningsHistoryWeightsFor(portfolio),
      {'BIL': 0.6, 'AGG': 0.4},
    );
  });

  testWidgets('keeps operational portfolio sections out of home',
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

    expect(find.text('입금 현황'), findsNothing);
    expect(find.text('포트폴리오 구성'), findsNothing);
    expect(find.text('예비 현금'), findsNothing);
    expect(find.text('포트폴리오 구성 비중에는 포함되지 않아요.'), findsNothing);
    expect(find.text('리밸런싱 시 별도로 보관됐다가 자동 사용돼요.'), findsNothing);
  });

  testWidgets('shows WeRobo logo above total profit', (tester) async {
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
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final logo = find.byKey(const Key('home_werobo_logo'));
    final totalProfit = find.text('총손익');

    expect(logo, findsOneWidget);
    expect(totalProfit, findsOneWidget);
    expect(
      tester.getTopLeft(logo).dy,
      lessThan(tester.getTopLeft(totalProfit).dy),
    );
  });

  testWidgets('stacks invested and current values with aligned plain amounts',
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
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final investedLabel = find.text('투자금액');
    final investedAmount = find.text('10,000,000 원');
    final currentLabel = find.text('평가금액');
    final currentAmount = find.text('10,500,000 원');

    expect(investedLabel, findsOneWidget);
    expect(investedAmount, findsOneWidget);
    expect(currentLabel, findsOneWidget);
    expect(currentAmount, findsOneWidget);
    expect(
      tester.getTopLeft(currentLabel).dy,
      greaterThan(tester.getTopLeft(investedLabel).dy),
    );
    expect(
      tester.getCenter(investedAmount).dy,
      moreOrLessEquals(tester.getCenter(investedLabel).dy, epsilon: 1.5),
    );
    expect(
      tester.getCenter(currentAmount).dy,
      moreOrLessEquals(tester.getCenter(currentLabel).dy, epsilon: 1.5),
    );

    final investedLabelStyle = tester.widget<Text>(investedLabel).style!;
    final investedAmountStyle = tester.widget<Text>(investedAmount).style!;
    final currentLabelStyle = tester.widget<Text>(currentLabel).style!;
    final currentAmountStyle = tester.widget<Text>(currentAmount).style!;
    final tc = WeRoboTheme.light.extension<WeRoboThemeColors>()!;

    expect(investedLabelStyle.color, tc.textSecondary);
    expect(currentLabelStyle.color, tc.textSecondary);
    expect(investedAmountStyle.color, tc.textPrimary);
    expect(currentAmountStyle.color, tc.textPrimary);
    expect(investedAmountStyle.fontSize, investedLabelStyle.fontSize);
    expect(currentAmountStyle.fontSize, currentLabelStyle.fontSize);
    expect(investedAmountStyle.fontWeight, FontWeight.w400);
    expect(currentAmountStyle.fontWeight, FontWeight.w400);
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

  testWidgets('uses placeholder digest when live digest is unavailable',
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

    expect(find.text('포트폴리오 주요 이슈 알림'), findsNothing);
    expect(find.text('AI 요약 · 최근 한 달'), findsOneWidget);
    expect(find.text('왜 내려갔을까?'), findsOneWidget);
    expect(find.textContaining('영향을 줬어요'), findsAtLeastNWidgets(1));
    expect(find.textContaining('시장 변동성이 평소보다'), findsNothing);
    expect(find.text('이번 주 다이제스트가 도착했어요'), findsNothing);
  });

  testWidgets('shows placeholder issue feed without live issue data',
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

    expect(find.text('포트폴리오 주요 이슈 알림'), findsNothing);
    expect(find.text('AI 요약 · 최근 한 달'), findsOneWidget);
    expect(find.text('왜 내려갔을까?'), findsOneWidget);
    expect(find.textContaining('영향을 줬어요'), findsAtLeastNWidgets(1));
    expect(find.textContaining('시장 변동성이 평소보다'), findsNothing);
    expect(find.text('더 보기'), findsNothing);
    expect(find.text('구간분석'), findsNothing);
    expect(find.text('이 구간 분석'), findsNothing);
    expect(
      find.byKey(const Key('range_digest_chart_ai_button')),
      findsOneWidget,
    );
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

  testWidgets('shows digest entry in issue timeline when available and unseen',
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

    expect(find.text('주간 다이제스트'), findsNothing);
    expect(find.text('포트폴리오 주요 이슈 알림'), findsNothing);
    expect(find.text('AI 요약 · 최근 7일'), findsOneWidget);
    expect(find.text('왜 올랐을까?'), findsOneWidget);
  });

  testWidgets('labels monthly fallback digest by response period',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    state.setWeeklyDigest(digestFixture(
      available: true,
      periodStart: '2026-03-30',
      periodEnd: '2026-04-29',
    ));
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

    expect(find.text('AI 요약 · 최근 한 달'), findsOneWidget);
  });

  testWidgets('folds unread algorithm signal into issue timeline only',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    state.setWeeklyDigest(digestFixture(available: false));
    await state.refreshInsights(notify: false);
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

    expect(find.text('포트폴리오 주요 이슈 알림'), findsNothing);
    expect(find.text('더 보기'), findsNothing);
    expect(find.textContaining('New ·'), findsNothing);
  });

  testWidgets('shows portfolio issue feed below hero chart for digest signals',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    state.setWeeklyDigest(digestFixture(
      available: true,
      triggerSigmaMultiple: 2.4,
      drivers: const [
        DigestDriver(
          ticker: 'VTV',
          nameKo: '미국 가치주',
          sectorCode: 'us_value',
          weightPct: 60,
          returnPct: 6.0,
          contributionWon: 600000,
        ),
      ],
    ));
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

    expect(find.text('포트폴리오 주요 이슈 알림'), findsNothing);
    expect(find.text('왜 올랐을까?'), findsOneWidget);
    expect(
      find.textContaining('미국 가치주가 +600,000 원 기여했어요'),
      findsOneWidget,
    );
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

    // Hold the gesture so the card stays mounted while we assert.
    // dragFrom() releases on completion which clears _touchIndex and
    // unmounts the card before assertions run.
    final chart = find.byType(CustomPaint).first;
    final center = tester.getCenter(chart);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    // The legend always shows '포트폴리오'. While the gesture is held,
    // a SECOND copy lives inside the drag context card.
    expect(find.text('포트폴리오'), findsNWidgets(2));
    // The card's signed-percent value text uses tabular figures and a
    // U+2212 minus or '+' sign — neither legend nor any other widget on
    // this screen produces a string ending in "%" inside the chart area.
    expect(find.textContaining('%'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('drag_context_asset_divider')), findsOneWidget);

    await gesture.up();
    await tester.pump();

    // After release, _touchIndex resets to null and the card disappears,
    // so only the legend's '포트폴리오' remains.
    expect(find.text('포트폴리오'), findsOneWidget);
  });

  testWidgets('drag context card shows ticker-based contribution rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    final start = DateTime(2026, 3, 1);
    state.setAccountDashboard(
      MobileAccountDashboard(
        hasAccount: true,
        summary: accountDashboard().summary,
        history: List.generate(
          60,
          (i) => MobileAccountHistoryPoint(
            date: start.add(Duration(days: i)),
            portfolioValue: 10000000 + (i * 5000),
            investedAmount: 10000000,
            profitLoss: i * 5000,
            profitLossPct: (i * 5000) / 10000000,
          ),
        ),
        recentActivity: const [],
      ),
    );
    state.setEarningsHistory(
      MobileEarningsHistoryResponse(
        points: [
          for (var i = 0; i < 60; i++)
            MobileEarningsPoint(
              date: start.add(Duration(days: i)),
              totalEarnings: 150000 + (i * 1500),
              totalReturnPct: 0,
              assetEarnings: {
                'BIL': 100000 + (i * 1000),
                'AGG': 50000 + (i * 500),
              },
            ),
        ],
        investmentAmount: 10000000,
        startDate: '2026-03-01',
        endDate: '2026-04-29',
        totalReturnPct: 0,
        totalEarnings: 0,
        assetSummary: const [],
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

    final chart = find.byType(CustomPaint).first;
    final center = tester.getCenter(chart);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    expect(find.byKey(const Key('drag_context_asset_divider')), findsOneWidget);
    expect(find.text('BIL'), findsAtLeastNWidgets(1));
    expect(find.text('AGG'), findsAtLeastNWidgets(1));

    await gesture.up();
  });

  testWidgets('long press does not enter two-point compare mode',
      (tester) async {
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
            date: DateTime(2026, 3, 1).add(Duration(days: i)),
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

    final chart = find.byType(CustomPaint).first;
    final center = tester.getCenter(chart);
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(find.text('→'), findsNothing);

    await gesture.up();
  });

  testWidgets(
      'range analysis mode enters from chart AI button and exits cleanly',
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

    await tester.ensureVisible(
      find.byKey(const Key('range_digest_chart_ai_button')),
    );
    await tester.pump();
    ScrollController homeScrollController() => tester
        .widget<SingleChildScrollView>(
          find.byKey(const Key('home_tab_scroll')),
        )
        .controller!;

    await tester.tap(find.byKey(const Key('range_digest_chart_ai_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(WeRoboMotion.medium);
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);
    expect(find.text('차트에서 궁금한 구간을 드래그해 선택하세요.'), findsOneWidget);
    expect(homeScrollController().offset, moreOrLessEquals(0));

    await tester.ensureVisible(find.byKey(const Key('range_digest_exit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('range_digest_exit')));
    await tester.pump();

    expect(find.text('AI 요약 · 최근 7일'), findsOneWidget);
    expect(find.byIcon(Icons.crop_free_rounded), findsNothing);
  });

  testWidgets('range analysis drag selects persistent interval summary',
      (tester) async {
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

    await tester.ensureVisible(
      find.byKey(const Key('range_digest_chart_ai_button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('range_digest_chart_ai_button')));
    await tester.pump();

    final chart = find.byKey(const Key('home_performance_chart_gesture'));
    await tester.ensureVisible(chart);
    await tester.pump();
    await tester.timedDrag(
      chart,
      const Offset(260, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump();

    expect(
        find.byKey(const Key('range_digest_selection_active')), findsOneWidget);
    final dateLabel = find.byKey(const Key('range_digest_chart_date_label'));
    expect(dateLabel, findsOneWidget);
    final labelText = tester.widget<Text>(dateLabel).data;
    expect(labelText, matches(RegExp(r'\d{1,2}\.\d{2} - \d{1,2}\.\d{2}')));
    expect(find.textContaining('움직였어요'), findsOneWidget);
  });

  testWidgets('range analysis loads AI summary and opens detail page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);
    addTearDown(() => debugSetRangeDigestApiOverride(null));

    await state.setAuthSession(
      MobileAuthSession(
        accessToken: 'token',
        tokenType: 'bearer',
        expiresAt:
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        user: const MobileAuthUser(
          id: 1,
          email: 'test@example.com',
          name: '테스터',
          provider: AuthProviderType.password,
          createdAt: '2026-04-01T00:00:00Z',
        ),
      ),
      notify: false,
    );
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
    state.setWeeklyDigest(digestFixture(available: true));
    await state.markWelcomeBannerSeen();

    final completer = Completer<MobileRangeDigestResponse>();
    debugSetRangeDigestApiOverride(
      ({
        required String accessToken,
        required DateTime startDate,
        required DateTime endDate,
        required double startValue,
        required double endValue,
      }) {
        expect(accessToken, 'token');
        expect(endDate.isAfter(startDate), isTrue);
        expect(endValue, greaterThan(startValue));
        return completer.future;
      },
    );

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

    await tester.ensureVisible(
      find.byKey(const Key('range_digest_chart_ai_button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('range_digest_chart_ai_button')));
    await tester.pump();

    final chart = find.byKey(const Key('home_performance_chart_gesture'));
    await tester.ensureVisible(chart);
    await tester.pump();
    await tester.timedDrag(
      chart,
      const Offset(260, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump();

    expect(find.text('이 구간의 변화를 분석하고 있어요'), findsOneWidget);

    completer.complete(rangeDigestFixture());
    await tester.pump();
    await tester.pump();

    expect(find.text('자세히 보기'), findsOneWidget);
    expect(find.text('미국 성장주 반등이 선택 구간 수익을 이끌었어요.'), findsOneWidget);

    await tester.tap(find.text('자세히 보기'));
    await tester.pumpAndSettle();

    expect(find.text('참고 뉴스'), findsOneWidget);
    expect(find.text('Tech shares rise on earnings optimism'), findsOneWidget);
  });

  testWidgets('range analysis locks selected interval while AI is loading',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);
    addTearDown(() => debugSetRangeDigestApiOverride(null));

    await state.setAuthSession(
      MobileAuthSession(
        accessToken: 'token',
        tokenType: 'bearer',
        expiresAt:
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        user: const MobileAuthUser(
          id: 1,
          email: 'test@example.com',
          name: '테스터',
          provider: AuthProviderType.password,
          createdAt: '2026-04-01T00:00:00Z',
        ),
      ),
      notify: false,
    );
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
    state.setWeeklyDigest(digestFixture(available: true));
    await state.markWelcomeBannerSeen();

    final completer = Completer<MobileRangeDigestResponse>();
    final requests = <({
      DateTime startDate,
      DateTime endDate,
      double startValue,
      double endValue,
    })>[];
    debugSetRangeDigestApiOverride(
      ({
        required String accessToken,
        required DateTime startDate,
        required DateTime endDate,
        required double startValue,
        required double endValue,
      }) {
        requests.add((
          startDate: startDate,
          endDate: endDate,
          startValue: startValue,
          endValue: endValue,
        ));
        return completer.future;
      },
    );

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

    await tester.ensureVisible(
      find.byKey(const Key('range_digest_chart_ai_button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('range_digest_chart_ai_button')));
    await tester.pump();

    final chart = find.byKey(const Key('home_performance_chart_gesture'));
    await tester.ensureVisible(chart);
    await tester.pump();

    await tester.timedDrag(
      chart,
      const Offset(260, 0),
      const Duration(milliseconds: 300),
    );
    expect(requests, hasLength(1));

    final firstRequest = requests.single;
    final expectedLockedLabel =
        '${firstRequest.startDate.month}.${firstRequest.startDate.day.toString().padLeft(2, '0')} - '
        '${firstRequest.endDate.month}.${firstRequest.endDate.day.toString().padLeft(2, '0')}';

    final secondGesture = await tester
        .startGesture(tester.getCenter(chart) + const Offset(120, 0));
    await tester.pump();
    await secondGesture.moveBy(const Offset(-260, 0));
    await tester.pump();
    await secondGesture.up();
    await tester.pump();

    expect(requests, hasLength(1));
    expect(find.text('이 구간의 변화를 분석하고 있어요'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('range_digest_chart_date_label')))
          .data,
      expectedLockedLabel,
    );

    completer.complete(rangeDigestFixture());
    await tester.pump();
    await tester.pump();

    await tester.timedDrag(
      chart,
      const Offset(-260, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump();

    expect(requests, hasLength(1));
    expect(
      tester
          .widget<Text>(find.byKey(const Key('range_digest_chart_date_label')))
          .data,
      expectedLockedLabel,
    );
  });
}
