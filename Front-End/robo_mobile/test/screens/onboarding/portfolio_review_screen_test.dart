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
          child: PortfolioReviewScreen(selection: _selection()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('비교 데이터가 없어요'), findsNothing);
    expect(find.text('시장'), findsOneWidget);
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

MobileComparisonBacktestResponse _comparisonBacktest() {
  final dates = [
    DateTime(2026, 3, 1),
    DateTime(2026, 3, 2),
    DateTime(2026, 3, 3),
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
        ],
      ),
    ],
  );
}
