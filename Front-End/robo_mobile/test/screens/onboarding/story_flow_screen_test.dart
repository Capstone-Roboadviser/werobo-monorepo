import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/login_screen.dart';
import 'package:robo_mobile/screens/onboarding/story_flow_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // PortfolioStateProvider must sit ABOVE MaterialApp so that pushed routes
  // (LoginScreen accesses PortfolioStateProvider in build) can find it.
  Future<PortfolioState> pumpStoryFlow(WidgetTester tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: const StoryFlowScreen(),
        ),
      ),
    );
    await tester.pump();
    return state;
  }

  testWidgets('renders the first page headline', (tester) async {
    await pumpStoryFlow(tester);
    expect(find.text('시장에는 수많은 자산들이 있습니다.'), findsOneWidget);
  });

  testWidgets('Skip button is visible', (tester) async {
    await pumpStoryFlow(tester);
    expect(find.text('건너뛰기'), findsOneWidget);
  });

  testWidgets('Skip marks story seen and navigates to LoginScreen',
      (tester) async {
    final state = await pumpStoryFlow(tester);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(state.hasSeenStory, true);
  });

  testWidgets('shows 7 page dots', (tester) async {
    await pumpStoryFlow(tester);
    // Page dots are simple Container widgets in a Row; first and last
    // are sufficient to confirm the dot row spans all 7 pages.
    expect(find.byKey(const ValueKey('story_page_dot_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('story_page_dot_6')), findsOneWidget);
  });

  testWidgets('CTA on page 7 also marks story seen and navigates',
      (tester) async {
    final state = await pumpStoryFlow(tester);

    // Jump the PageView directly to page index 6 (spec page 7, CTA page).
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(6);
    await tester.pumpAndSettle();

    // At progress 6.0, storyCtaOpacity == 1.0, so IgnorePointer is off
    // and the button is tappable.
    await tester.tap(find.text('투자 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(state.hasSeenStory, true);
  });
}
