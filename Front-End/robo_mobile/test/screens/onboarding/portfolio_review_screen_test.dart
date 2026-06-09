import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:robo_mobile/screens/onboarding/portfolio_design_screen.dart';
import 'package:robo_mobile/screens/onboarding/portfolio_market_comparison_screen.dart';
import 'package:robo_mobile/screens/onboarding/portfolio_review_screen.dart';
import 'package:robo_mobile/screens/onboarding/survey_result_screen.dart';
import 'package:robo_mobile/models/investor_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('allocation screen renders donut chart', (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: PortfolioAllocationScreen(
            selection: _selection(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('포트폴리오 비중'), findsWidgets);
    expect(find.text('다음'), findsOneWidget);
  });

  testWidgets('allocation screen 다음 button pushes review screen',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());
    state.debugSetVolatilityHistory(_volatilityHistory());

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: PortfolioAllocationScreen(
            selection: _selection(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.byType(PortfolioReviewScreen), findsOneWidget);
  });

  testWidgets('comparison tab renders loaded backtest data', (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: PortfolioReviewScreen(
            selection: _selection(),
            fetchVolatilityHistory: _failingVolatilityHistoryFetch,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('비교 데이터가 없어요'), findsNothing);
    expect(find.text('시장'), findsOneWidget);
  });

  testWidgets('volatility tab reuses loaded backtest data', (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: PortfolioReviewScreen(
            selection: _selection(),
            fetchVolatilityHistory: _failingVolatilityHistoryFetch,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('변동성'));
    await tester.pumpAndSettle();

    expect(find.text('비교 데이터가 없어요'), findsNothing);
    expect(find.text('포트폴리오'), findsWidgets);
    expect(find.text('시장'), findsOneWidget);
  });

  testWidgets('volatility tab falls back to selected target volatility',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_flatComparisonBacktest());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: PortfolioReviewScreen(
            selection: _selection(),
            fetchVolatilityHistory: _failingVolatilityHistoryFetch,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('변동성'));
    await tester.pumpAndSettle();

    expect(find.text('비교 데이터가 없어요'), findsNothing);
    expect(find.text('포트폴리오'), findsWidgets);
    expect(find.text('시장'), findsOneWidget);
  });

  testWidgets('volatility tab uses loaded volatility history', (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_flatComparisonBacktest());
    state.debugSetVolatilityHistory(_volatilityHistory());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: PortfolioReviewScreen(selection: _zeroVolatilitySelection()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('변동성'));
    await tester.pumpAndSettle();

    expect(find.text('비교 데이터가 없어요'), findsNothing);
    expect(find.text('포트폴리오'), findsWidgets);
    expect(find.text('시장'), findsOneWidget);
  });

  testWidgets('confirm investment creates account with 10m from March 1',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());
    state.debugSetVolatilityHistory(_volatilityHistory());
    final today = DateTime(2026, 5, 12, 14, 30);
    double? createdAmount;
    DateTime? createdStartedAt;

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          routes: {
            '/home': (_) => const SizedBox(key: Key('home-screen')),
          },
          home: PortfolioReviewScreen(
            selection: _selection(),
            now: () => today,
            resolveFrontierSelection: ({
              required PortfolioState state,
              required OnboardingFrontierSelection selection,
            }) async =>
                _frontierSelectionResponse(asOfDate: selection.asOfDate),
            createInitialAccount: ({
              required PortfolioState state,
              required MobileFrontierSelectionResponse selection,
              required double initialCashAmount,
              required DateTime startedAt,
            }) async {
              createdAmount = initialCashAmount;
              createdStartedAt = startedAt;
              return _accountDashboard(startedAt: startedAt);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('투자 확정'));
    // Confirm now advances to the 포트폴리오 설계 screen (inserted right before
    // home). Its chart runs a perpetual pulse animation, so pump in bounded
    // steps rather than pumpAndSettle (which would never settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(createdAmount, 10000000);
    expect(createdStartedAt, DateTime(2026, 3, 1));
    expect(state.frontierSelection, isNotNull);
    expect(state.accountDashboard?.summary?.investedAmount, 10000000);
    expect(state.accountDashboard?.summary?.startedAt, '2026-03-01');
    expect(find.byType(PortfolioDesignScreen), findsOneWidget);
  });

  testWidgets('survey result starts directly on portfolio design screen',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: SurveyResultScreen(
            profile: _investorProfile(),
            fetchFrontierPreview: ({
              required double propensityScore,
              required int samplePoints,
            }) async =>
                _selection().preview!,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('내 포트폴리오 설계 시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(PortfolioDesignScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('portfolio design confirm opens market comparison summary',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: PortfolioDesignScreen(selection: _selection()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('AI 추천 지점을 보여주세요'));
    await tester.pump();
    await tester.tap(find.text('포트폴리오 확인하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(PortfolioMarketComparisonScreen), findsOneWidget);
    expect(find.textContaining('시장과 비교해 보세요'), findsOneWidget);
  });

  testWidgets('market comparison next creates account and enters home',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());
    final today = DateTime(2026, 5, 12, 14, 30);
    double? createdAmount;
    DateTime? createdStartedAt;

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          routes: {
            '/home': (_) => const SizedBox(key: Key('home-screen')),
          },
          home: PortfolioMarketComparisonScreen(
            selection: _selection(),
            now: () => today,
            resolveFrontierSelection: ({
              required PortfolioState state,
              required OnboardingFrontierSelection selection,
            }) async =>
                _frontierSelectionResponse(asOfDate: selection.asOfDate),
            createInitialAccount: ({
              required PortfolioState state,
              required MobileFrontierSelectionResponse selection,
              required double initialCashAmount,
              required DateTime startedAt,
            }) async {
              createdAmount = initialCashAmount;
              createdStartedAt = startedAt;
              return _accountDashboard(startedAt: startedAt);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('누적 수익률'), findsOneWidget);
    expect(find.text('변동성'), findsOneWidget);
    expect(find.text('MDD'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(createdAmount, 10000000);
    expect(createdStartedAt, DateTime(2026, 3, 1));
    expect(state.frontierSelection, isNotNull);
    expect(state.accountDashboard?.summary?.investedAmount, 10000000);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  });

  testWidgets('market comparison renders without waiting for backtest',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    final neverCompletes = Completer<MobileComparisonBacktestResponse>();

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: PortfolioMarketComparisonScreen(
            selection: _selection(),
            fetchComparisonBacktest: ({
              required PortfolioState state,
              required OnboardingFrontierSelection selection,
            }) =>
                neverCompletes.future,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('누적 수익률을 비교'), findsOneWidget);
    expect(find.text('비교 데이터를 불러오는 중이에요'), findsNothing);
    expect(find.textContaining('기간:'), findsOneWidget);
  });

  testWidgets('market comparison next does not wait for home prefetch',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    final today = DateTime(2026, 5, 12, 14, 30);
    final neverCompletes = Completer<void>();

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          routes: {
            '/home': (_) => const SizedBox(key: Key('home-screen')),
          },
          home: PortfolioMarketComparisonScreen(
            selection: _selection(),
            now: () => today,
            resolveFrontierSelection: ({
              required PortfolioState state,
              required OnboardingFrontierSelection selection,
            }) async =>
                _frontierSelectionResponse(asOfDate: selection.asOfDate),
            createInitialAccount: ({
              required PortfolioState state,
              required MobileFrontierSelectionResponse selection,
              required double initialCashAmount,
              required DateTime startedAt,
            }) async =>
                _accountDashboard(startedAt: startedAt),
            prefetchHomeBacktest: (_) => neverCompletes.future,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  });
}

InvestorProfile _investorProfile() {
  return const InvestorProfile(
    level: RiskLevel.stableGrowth,
    rawScore: 16,
    propensityScore: 50,
    expectedReturnMin: 0.04,
    expectedReturnMax: 0.10,
    maxRisk: 0.14,
    answers: {},
  );
}

OnboardingFrontierSelection _selection() {
  final preview = MobileFrontierPreviewResponse(
    resolvedProfile: const MobileResolvedProfile(
      code: 'balanced',
      label: '균형형',
      propensityScore: 45,
      targetVolatility: 0.12,
      investmentHorizon: 'medium',
    ),
    recommendedPortfolioCode: 'balanced',
    dataSource: 'managed_universe',
    asOfDate: DateTime(2026, 3, 1),
    totalPointCount: 1,
    minVolatility: 0.12,
    maxVolatility: 0.12,
    points: const [
      MobileFrontierPreviewPoint(
        index: 40,
        volatility: 0.12,
        expectedReturn: 0.08,
        isRecommended: true,
        representativeCode: 'balanced',
        representativeLabel: '균형형',
        sectorAllocations: [
          MobileSectorAllocation(
            assetCode: 'us_value',
            assetName: '미국 가치주',
            weight: 0.6,
            riskContribution: 0.6,
          ),
          MobileSectorAllocation(
            assetCode: 'gold',
            assetName: '금',
            weight: 0.4,
            riskContribution: 0.4,
          ),
        ],
      ),
    ],
  );
  return OnboardingFrontierSelection(
    normalizedT: 0,
    selectedPointIndex: 40,
    targetVolatility: 0.12,
    dataSource: 'managed_universe',
    asOfDate: DateTime(2026, 3, 1),
    isAuthoritative: true,
    preview: preview,
  );
}

OnboardingFrontierSelection _zeroVolatilitySelection() {
  final base = _selection();
  return OnboardingFrontierSelection(
    normalizedT: base.normalizedT,
    selectedPointIndex: base.selectedPointIndex,
    targetVolatility: 0,
    dataSource: base.dataSource,
    asOfDate: base.asOfDate,
    isAuthoritative: base.isAuthoritative,
  );
}

MobileComparisonBacktestResponse _comparisonBacktest() {
  final dates = [
    DateTime(2026, 3, 1),
    DateTime(2026, 3, 2),
    DateTime(2026, 3, 3),
    DateTime(2026, 3, 4),
    DateTime(2026, 3, 5),
  ];
  return MobileComparisonBacktestResponse(
    trainStartDate: DateTime(2025, 1, 1),
    trainEndDate: DateTime(2025, 12, 31),
    testStartDate: DateTime(2026, 1, 1),
    startDate: dates.first,
    endDate: dates.last,
    splitRatio: 0.8,
    rebalanceDates: dates,
    rebalancePolicy: null,
    lines: [
      MobileComparisonLine(
        key: 'selected',
        label: '포트폴리오',
        color: '#FE9337',
        style: 'solid',
        points: [
          MobileComparisonLinePoint(date: dates[0], returnPct: 0.01),
          MobileComparisonLinePoint(date: dates[1], returnPct: 0.03),
          MobileComparisonLinePoint(date: dates[2], returnPct: 0.05),
          MobileComparisonLinePoint(date: dates[3], returnPct: 0.04),
          MobileComparisonLinePoint(date: dates[4], returnPct: 0.07),
        ],
      ),
      MobileComparisonLine(
        key: 'market',
        label: '시장',
        color: '#64748B',
        style: 'solid',
        points: [
          MobileComparisonLinePoint(date: dates[0], returnPct: 0.00),
          MobileComparisonLinePoint(date: dates[1], returnPct: 0.02),
          MobileComparisonLinePoint(date: dates[2], returnPct: 0.04),
          MobileComparisonLinePoint(date: dates[3], returnPct: 0.03),
          MobileComparisonLinePoint(date: dates[4], returnPct: 0.05),
        ],
      ),
    ],
  );
}

MobileComparisonBacktestResponse _flatComparisonBacktest() {
  final dates = [
    DateTime(2026, 3, 1),
    DateTime(2026, 3, 2),
  ];
  return MobileComparisonBacktestResponse(
    trainStartDate: DateTime(2025, 1, 1),
    trainEndDate: DateTime(2025, 12, 31),
    testStartDate: DateTime(2026, 1, 1),
    startDate: dates.first,
    endDate: dates.last,
    splitRatio: 0.8,
    rebalanceDates: dates,
    rebalancePolicy: null,
    lines: [
      MobileComparisonLine(
        key: 'selected',
        label: '포트폴리오',
        color: '#FE9337',
        style: 'solid',
        points: [
          MobileComparisonLinePoint(date: dates[0], returnPct: 0.0),
          MobileComparisonLinePoint(date: dates[1], returnPct: 0.01),
        ],
      ),
      MobileComparisonLine(
        key: 'market',
        label: '시장',
        color: '#64748B',
        style: 'solid',
        points: [
          MobileComparisonLinePoint(date: dates[0], returnPct: 0.0),
          MobileComparisonLinePoint(date: dates[1], returnPct: 0.01),
        ],
      ),
    ],
  );
}

MobileVolatilityHistoryResponse _volatilityHistory() {
  final dates = [
    DateTime(2026, 3, 1),
    DateTime(2026, 3, 2),
    DateTime(2026, 3, 3),
  ];
  return MobileVolatilityHistoryResponse(
    portfolioCode: 'selected',
    portfolioLabel: '선택 포트폴리오',
    rollingWindow: 20,
    earliestDataDate: dates.first,
    latestDataDate: dates.last,
    points: [
      MobileVolatilityPoint(date: dates[0], volatility: 0.11),
      MobileVolatilityPoint(date: dates[1], volatility: 0.12),
      MobileVolatilityPoint(date: dates[2], volatility: 0.13),
    ],
    benchmarkPoints: [
      MobileVolatilityPoint(date: dates[0], volatility: 0.10),
      MobileVolatilityPoint(date: dates[1], volatility: 0.105),
      MobileVolatilityPoint(date: dates[2], volatility: 0.115),
    ],
  );
}

Future<MobileVolatilityHistoryResponse> _failingVolatilityHistoryFetch({
  required PortfolioState state,
  required OnboardingFrontierSelection selection,
}) {
  throw StateError('volatility history unavailable in this test');
}

MobileFrontierSelectionResponse _frontierSelectionResponse({
  DateTime? asOfDate,
}) {
  return MobileFrontierSelectionResponse(
    resolvedProfile: const MobileResolvedProfile(
      code: 'balanced',
      label: '균형형',
      propensityScore: 45,
      targetVolatility: 0.12,
      investmentHorizon: 'medium',
    ),
    dataSource: 'managed_universe',
    asOfDate: asOfDate,
    requestedTargetVolatility: 0.12,
    selectedTargetVolatility: 0.12,
    selectedPointIndex: 40,
    totalPointCount: 61,
    representativeCode: 'balanced',
    representativeLabel: '균형형',
    portfolio: const MobilePortfolioRecommendation(
      code: 'balanced',
      label: '균형형',
      portfolioId: 'balanced-40',
      targetVolatility: 0.12,
      expectedReturn: 0.08,
      volatility: 0.11,
      sharpeRatio: 0.7,
      sectorAllocations: [],
      stockAllocations: [],
    ),
  );
}

MobileAccountDashboard _accountDashboard({
  required DateTime startedAt,
}) {
  final startedAtText =
      '${startedAt.year.toString().padLeft(4, '0')}-${startedAt.month.toString().padLeft(2, '0')}-${startedAt.day.toString().padLeft(2, '0')}';
  return MobileAccountDashboard(
    hasAccount: true,
    summary: MobileAccountSummary(
      portfolioCode: 'balanced',
      portfolioLabel: '균형형',
      portfolioId: 'balanced-40',
      dataSource: 'managed_universe',
      investmentHorizon: 'medium',
      targetVolatility: 0.12,
      expectedReturn: 0.08,
      volatility: 0.11,
      sharpeRatio: 0.7,
      startedAt: startedAtText,
      lastSnapshotDate: startedAtText,
      currentValue: 10000000,
      investedAmount: 10000000,
      profitLoss: 0,
      cashBalance: 0,
      profitLossPct: 0,
      sectorAllocations: const [],
      stockAllocations: const [],
    ),
    history: [
      MobileAccountHistoryPoint(
        date: startedAt,
        portfolioValue: 10000000,
        investedAmount: 10000000,
        profitLoss: 0,
        profitLossPct: 0,
      ),
    ],
    recentActivity: const [],
  );
}
