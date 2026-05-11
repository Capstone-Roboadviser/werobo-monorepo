import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/models/rebalance_insight.dart';
import 'package:robo_mobile/screens/home/home_tab.dart' show showNotificationsSheet;

MobileAccountDashboard _dashboardWith(List<MobileAccountHistoryPoint> history) {
  return MobileAccountDashboard(
    hasAccount: true,
    summary: null,
    history: history,
    recentActivity: const [],
  );
}

Widget _wrap(PortfolioState state) => MaterialApp(
      theme: WeRoboTheme.light,
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('monthly summary row shows trailing-30d percent', (tester) async {
    final state = PortfolioState();
    final now = DateTime.now();
    final history = [
      for (int i = 30; i >= 0; i--)
        MobileAccountHistoryPoint(
          date: now.subtract(Duration(days: i)),
          portfolioValue: 100.0 + (30 - i) * 0.5,
          investedAmount: 100,
          profitLoss: 0,
          profitLossPct: 0,
        ),
    ];
    state.debugSetAccountDashboard(_dashboardWith(history));

    await tester.pumpWidget(_wrap(state));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('지난 30일'), findsOneWidget);
    // Tolerance: time-of-day affects the cutoff so direction matters more than
    // the exact decimal. Accept anything starting with "+1" (i.e. 10-19%).
    expect(find.textContaining(RegExp(r'\+1[0-9]\.')), findsWidgets);
  });

  testWidgets('monthly summary row hidden when insufficient history',
      (tester) async {
    final state = PortfolioState();
    state.debugSetAccountDashboard(_dashboardWith(const []));

    await tester.pumpWidget(_wrap(state));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('월간 요약'), findsNothing);
  });

  testWidgets('algorithm signal row shows today\'s insight trigger',
      (tester) async {
    final state = PortfolioState();
    final today = DateTime.now();
    final todayIso = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    state.debugSetInsights([
      RebalanceInsight(
        id: 1,
        rebalanceDate: todayIso,
        allocations: const [],
        tradeDetails: const [],
        trigger: 'drift_guard',
        tradeCount: 1,
        cashBefore: 0,
        cashFromSales: 0,
        cashToBuys: 0,
        cashAfter: 0,
        netCashChange: 0,
        explanationText: 'test',
        isRead: false,
        createdAt: today.toIso8601String(),
      ),
    ]);

    await tester.pumpWidget(_wrap(state));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('알고리즘 시그널'), findsOneWidget);
    expect(find.textContaining('드리프트 가드가 작동했어요'), findsOneWidget);
  });

  testWidgets('algorithm signal row hides yesterday\'s insight',
      (tester) async {
    final state = PortfolioState();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayIso = '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
    state.debugSetInsights([
      RebalanceInsight(
        id: 1,
        rebalanceDate: yesterdayIso,
        allocations: const [],
        tradeDetails: const [],
        trigger: 'drift_guard',
        tradeCount: 1,
        cashBefore: 0,
        cashFromSales: 0,
        cashToBuys: 0,
        cashAfter: 0,
        netCashChange: 0,
        explanationText: 'test',
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ]);

    await tester.pumpWidget(_wrap(state));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('드리프트 가드'), findsNothing);
  });
}
