import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/activity_hub_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('does not show digest card in activity hub', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const ActivityHubPage(),
        ),
      ),
    );

    expect(find.text('알림 & 리포트'), findsOneWidget);
    expect(find.text('리밸런싱 히스토리'), findsOneWidget);
    expect(find.text('최근 활동'), findsOneWidget);
    expect(find.text('주간 다이제스트'), findsNothing);
    expect(find.textContaining('포트폴리오 리포트'), findsNothing);
  });
}
