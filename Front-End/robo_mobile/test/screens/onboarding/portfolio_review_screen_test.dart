import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:robo_mobile/screens/onboarding/portfolio_review_screen.dart';

void main() {
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

  testWidgets('confirm investment creates account with 10m from today',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    state.setBacktest(_comparisonBacktest());
    state.debugSetVolatilityHistory(_volatilityHistory());
    final today = DateTime(2026, 5, 12, 14, 30);
    double? createdAmount;
    DateTime? createdStartedAt;

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        routes: {
          '/home': (_) => const SizedBox(key: Key('home-screen')),
        },
        home: PortfolioStateProvider(
          state: state,
          child: PortfolioReviewScreen(
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
    await tester.pumpAndSettle();

    expect(createdAmount, 10000000);
    expect(createdStartedAt, today);
    expect(state.frontierSelection, isNotNull);
    expect(state.accountDashboard?.summary?.investedAmount, 10000000);
    expect(state.accountDashboard?.summary?.startedAt, '2026-05-12');
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  });
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
