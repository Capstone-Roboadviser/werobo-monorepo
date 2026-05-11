import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/activity_hub_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the filter pill and removes legacy sections',
      (tester) async {
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

    // Filter pill defaults to 전체.
    expect(find.text('전체'), findsOneWidget);

    // Old sections must be gone.
    expect(find.text('알림 & 리포트'), findsNothing);
    expect(find.text('리밸런싱 히스토리'), findsNothing);
    expect(find.text('최근 활동'), findsNothing);

    // Empty state copy renders when there are no insights or derived data.
    expect(find.text('아직 지난 알림이 없어요'), findsOneWidget);
  });
}
