import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/rebalance_insight.dart';
import 'package:robo_mobile/screens/home/insight_detail_page.dart';

void main() {
  testWidgets('shows grouped ticker trades under each asset change',
      (tester) async {
    const insight = RebalanceInsight(
      id: -1,
      rebalanceDate: '2026-04-15',
      allocations: [
        RebalanceInsightAllocation(
          assetCode: 'infra_bond',
          assetName: '인프라 채권',
          color: Color(0xFF98C1D9),
          beforePct: 0.032,
          afterPct: 0.030,
        ),
        RebalanceInsightAllocation(
          assetCode: 'new_growth',
          assetName: '신성장주',
          color: Color(0xFF9B7FCC),
          beforePct: 0.052,
          afterPct: 0.051,
        ),
      ],
      tradeDetails: [
        RebalanceInsightTrade(
          ticker: 'BNDX',
          tickerName: 'Vanguard Total Intl Bond ETF',
          assetCode: 'infra_bond',
          assetName: '인프라 채권',
          direction: 'sell',
          amount: 22113,
        ),
        RebalanceInsightTrade(
          ticker: 'TIP',
          tickerName: 'iShares TIPS Bond ETF',
          assetCode: 'infra_bond',
          assetName: '인프라 채권',
          direction: 'sell',
          amount: 10000,
        ),
        RebalanceInsightTrade(
          ticker: 'ARKK',
          tickerName: 'ARK Innovation ETF',
          assetCode: 'new_growth',
          assetName: '신성장주',
          direction: 'sell',
          amount: 8500,
        ),
      ],
      trigger: 'drift_guard',
      tradeCount: 3,
      cashBefore: 0,
      cashFromSales: 32113,
      cashToBuys: 0,
      cashAfter: 87012,
      netCashChange: 87012,
      explanationText: null,
      isRead: true,
      createdAt: '2026-04-15T09:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: const InsightDetailPage(insight: insight),
      ),
    );

    expect(find.text('인프라 채권'), findsOneWidget);
    expect(find.text('조정된 2개 티커 보기'), findsOneWidget);
    expect(find.text('Vanguard Total Intl Bond ETF'), findsNothing);

    await tester.ensureVisible(find.text('조정된 2개 티커 보기'));
    await tester.tap(find.text('조정된 2개 티커 보기'));
    await tester.pumpAndSettle();

    expect(find.text('Vanguard Total Intl Bond ETF'), findsOneWidget);
    expect(find.text('iShares TIPS Bond ETF'), findsOneWidget);
    expect(find.text('매도 ₩22,113'), findsOneWidget);
  });
}
