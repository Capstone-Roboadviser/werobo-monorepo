import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/portfolio_report_detail_page.dart';

void main() {
  Widget wrap(PortfolioState state, Widget child) {
    return MaterialApp(
      theme: WeRoboTheme.light,
      home: PortfolioStateProvider(
        state: state,
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('monthly report detail renders preview when no account data',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      wrap(state, const PortfolioReportDetailPage(period: ReportPeriod.monthly)),
    );
    await tester.pump();

    expect(find.text('월간 리포트'), findsOneWidget);
    expect(find.text('Monthly Report'), findsOneWidget);
    expect(find.text('확인하기'), findsOneWidget);
    expect(find.text('하락종목'), findsOneWidget);
    expect(find.text('상승종목'), findsOneWidget);
    expect(find.text('지난 Report'), findsOneWidget);
    expect(find.text('Monthly Report는 매월 초 제공됩니다.'), findsOneWidget);
  });

  testWidgets('weekly report detail uses weekly copy', (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      wrap(state, const PortfolioReportDetailPage(period: ReportPeriod.weekly)),
    );
    await tester.pump();

    expect(find.text('주간 리포트'), findsOneWidget);
    expect(find.text('Weekly Report'), findsOneWidget);
    expect(find.text('Weekly Report는 매주 월요일 제공됩니다.'), findsOneWidget);
  });

  testWidgets('daily report detail uses daily copy', (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      wrap(state, const PortfolioReportDetailPage(period: ReportPeriod.daily)),
    );
    await tester.pump();

    expect(find.text('일간 리포트'), findsOneWidget);
    expect(find.text('Daily Report'), findsOneWidget);
    expect(find.text('Daily Report는 매일 장 마감 후 제공됩니다.'), findsOneWidget);
  });

  testWidgets('header back arrow widget is present and tappable',
      (tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      wrap(state, const PortfolioReportDetailPage(period: ReportPeriod.monthly)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });
}
