import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/pressable.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/app/theme_state.dart';
import 'package:robo_mobile/screens/home/home_shell.dart';

void main() {
  Widget buildSubject() {
    final state = PortfolioState();
    final themeNotifier = ThemeNotifier();
    addTearDown(state.dispose);
    addTearDown(themeNotifier.dispose);
    return PortfolioStateProvider(
      state: state,
      child: ThemeStateProvider(
        notifier: themeNotifier,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: const HomeShell(),
        ),
      ),
    );
  }

  testWidgets('bottom navigation shows icon labels for all tabs',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    for (final label in ['홈', '포트폴리오', '커뮤니티', '뉴스', '더보기']) {
      expect(find.widgetWithText(Pressable, label), findsOneWidget);
    }
  });

  testWidgets('news navigation item opens the news tab', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '뉴스'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const Key('news_tab')), findsOneWidget);
  });
}
