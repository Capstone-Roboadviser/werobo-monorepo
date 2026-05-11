import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';

// Test target: import the public showNotificationsSheet helper which the home
// tab will call. The sheet itself stays private inside home_tab.dart, but the
// helper is package-public so widget tests can drive it.
import 'package:robo_mobile/screens/home/home_tab.dart' show showNotificationsSheet;

void main() {
  testWidgets('sheet is top-anchored and shows the title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: PortfolioState(),
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showNotificationsSheet(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 알림'), findsOneWidget);

    // Sheet content sits in the top half of the screen.
    final titleBox = tester.getRect(find.text('오늘의 알림'));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(titleBox.top < screenHeight / 2, isTrue,
        reason: 'expected sheet to be anchored at the top half');
  });
}
