import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/login_screen.dart';
import 'package:robo_mobile/screens/onboarding/onboarding_flow_screen.dart';
import 'package:robo_mobile/screens/onboarding/steps/ai_management_view.dart';
import 'package:robo_mobile/screens/onboarding/steps/asset_scatter_view.dart';
import 'package:robo_mobile/screens/onboarding/steps/diversification_view.dart';
import 'package:robo_mobile/screens/onboarding/steps/efficient_frontier_view.dart';
import 'package:robo_mobile/screens/onboarding/steps/optimal_ratio_donut_view.dart';
import 'package:robo_mobile/screens/onboarding/steps/summary_view.dart';
import 'package:robo_mobile/screens/onboarding/steps/volatility_line_view.dart';

void main() {
  setUp(() {
    // markStorySeen() persists to SharedPreferences; give it a clean store.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // Wraps the orchestrator in its provider + theme. A large surface keeps the
  // step bodies (esp. step 3's chip row) from overflowing in the test viewport.
  Future<PortfolioState> pumpFlow(WidgetTester tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: const OnboardingFlowScreen(),
        ),
      ),
    );
    // Let the first-page entrance post-frame callback fire and settle.
    await tester.pumpAndSettle();
    return state;
  }

  // The orchestrator's primary CTA is the lone ElevatedButton in the footer.
  ElevatedButton primaryButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  // Settles a transition/entrance with bounded pumps. Step 6's AI view loops
  // forever (a pulsing glow), so `pumpAndSettle` would hang — pump a fixed
  // window that clears the 220ms page transition + 400ms entrance + slack.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  // Advances to the next page via the CTA and settles the page transition.
  Future<void> tapPrimary(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    await settle(tester);
  }

  // Adds the first asset chip on the interactive step (opens the gate).
  Future<void> addFirstAsset(WidgetTester tester) async {
    await tester.tap(find.text('채권'));
    await settle(tester);
  }

  group('OnboardingFlowScreen chrome', () {
    testWidgets('uses a pure white page background', (tester) async {
      await pumpFlow(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.white);
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).canvasColor,
          Colors.white);
    });

    testWidgets('starts on step 1 with the 1/7 counter and first headline',
        (tester) async {
      await pumpFlow(tester);

      expect(find.byType(AssetScatterView), findsOneWidget);
      expect(find.text('1/7'), findsOneWidget);
      expect(find.text('시장에는 수많은 자산들이 있습니다.'), findsOneWidget);
    });

    testWidgets('primary button advances pages and increments the counter',
        (tester) async {
      await pumpFlow(tester);

      expect(find.text('1/7'), findsOneWidget);
      expect(find.byType(AssetScatterView), findsOneWidget);

      await tapPrimary(tester);

      expect(find.text('2/7'), findsOneWidget);
      expect(find.byType(VolatilityLineView), findsOneWidget);
      expect(find.text('주식 몰빵 투자 정말 괜찮을까요?'), findsOneWidget);
    });

    testWidgets('advancing settles fully on the next page — the interactive '
        'step does not freeze mid-transition', (tester) async {
      await pumpFlow(tester);
      await tapPrimary(tester); // → 2
      await tapPrimary(tester); // → 3 (interactive: forward-locks on arrival)

      // The page must land exactly on step 3, not stall mid-swipe. The forward
      // lock pins at the page boundary, so the inbound nextPage still settles.
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller!.page, closeTo(2.0, 0.02));
      expect(find.text('3/7'), findsOneWidget);
      expect(find.byType(DiversificationView), findsOneWidget);
    });

    testWidgets('walks through all seven step widgets in order',
        (tester) async {
      await pumpFlow(tester);

      // 1 — asset scatter.
      expect(find.byType(AssetScatterView), findsOneWidget);
      expect(find.text('1/7'), findsOneWidget);

      // 2 — volatility line.
      await tapPrimary(tester);
      expect(find.byType(VolatilityLineView), findsOneWidget);
      expect(find.text('2/7'), findsOneWidget);

      // 3 — diversification (interactive). Add an asset so the gate opens.
      await tapPrimary(tester);
      expect(find.byType(DiversificationView), findsOneWidget);
      expect(find.text('3/7'), findsOneWidget);
      await addFirstAsset(tester);

      // 4 — optimal-ratio donut.
      await tapPrimary(tester);
      expect(find.byType(OptimalRatioDonutView), findsOneWidget);
      expect(find.text('4/7'), findsOneWidget);

      // 5 — efficient frontier (display-only).
      await tapPrimary(tester);
      expect(find.byType(OnboardingFrontierView), findsOneWidget);
      expect(find.text('5/7'), findsOneWidget);

      // 6 — AI management.
      await tapPrimary(tester);
      expect(find.byType(AiManagementView), findsOneWidget);
      expect(find.text('6/7'), findsOneWidget);

      // 7 — summary (no skip).
      await tapPrimary(tester);
      expect(find.byType(OnboardingSummaryView), findsOneWidget);
      expect(find.text('7/7'), findsOneWidget);
    });

    testWidgets('skip is shown on step 1 and hidden on step 7',
        (tester) async {
      await pumpFlow(tester);

      expect(find.text('건너뛰기'), findsOneWidget);

      // Advance to the last step (adding an asset on step 3 to pass the gate).
      await tapPrimary(tester); // 2
      await tapPrimary(tester); // 3
      await addFirstAsset(tester);
      await tapPrimary(tester); // 4
      await tapPrimary(tester); // 5
      await tapPrimary(tester); // 6
      await tapPrimary(tester); // 7

      expect(find.byType(OnboardingSummaryView), findsOneWidget);
      expect(find.text('건너뛰기'), findsNothing);
    });
  });

  group('exit routing', () {
    testWidgets('skip calls markStorySeen and routes to LoginScreen',
        (tester) async {
      final state = await pumpFlow(tester);
      expect(state.hasSeenStory, isFalse);

      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();

      expect(state.hasSeenStory, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingFlowScreen), findsNothing);
    });

    testWidgets('final CTA calls markStorySeen and routes to LoginScreen',
        (tester) async {
      final state = await pumpFlow(tester);

      await tapPrimary(tester); // 2
      await tapPrimary(tester); // 3
      await addFirstAsset(tester);
      await tapPrimary(tester); // 4
      await tapPrimary(tester); // 5
      await tapPrimary(tester); // 6
      await tapPrimary(tester); // 7
      expect(find.byType(OnboardingSummaryView), findsOneWidget);
      expect(state.hasSeenStory, isFalse);

      // 투자 시작하기 — the final CTA.
      await tapPrimary(tester);

      expect(state.hasSeenStory, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingFlowScreen), findsNothing);
    });
  });

  group('step 3 readiness gate', () {
    // Advances to step 3 from a freshly pumped flow.
    Future<void> goToStep3(WidgetTester tester) async {
      await tapPrimary(tester); // → 2
      await tapPrimary(tester); // → 3
      expect(find.byType(DiversificationView), findsOneWidget);
      expect(find.text('3/7'), findsOneWidget);
    }

    testWidgets(
        'button is disabled with the pending label until an asset is added',
        (tester) async {
      await pumpFlow(tester);
      await goToStep3(tester);

      // Before any add: disabled, showing the pending label.
      expect(primaryButton(tester).onPressed, isNull);
      expect(find.widgetWithText(ElevatedButton, '자산을 추가해주세요'),
          findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '계속하기'), findsNothing);

      // Add an asset → gate opens.
      await tester.tap(find.text('채권'));
      await tester.pumpAndSettle();

      expect(primaryButton(tester).onPressed, isNotNull);
      expect(find.widgetWithText(ElevatedButton, '계속하기'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '자산을 추가해주세요'),
          findsNothing);
    });

    testWidgets('the disabled button cannot advance the flow', (tester) async {
      await pumpFlow(tester);
      await goToStep3(tester);

      // Tapping the disabled CTA must not advance past step 3.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('3/7'), findsOneWidget);
      expect(find.byType(DiversificationView), findsOneWidget);
    });

    testWidgets('forward swipe is locked until ready, backward stays free',
        (tester) async {
      await pumpFlow(tester);
      await goToStep3(tester);

      // Forward swipe (drag left) is blocked while not ready.
      await tester.drag(
        find.byType(DiversificationView),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('3/7'), findsOneWidget);
      expect(find.byType(DiversificationView), findsOneWidget);

      // Backward swipe (drag right) is always allowed → back to step 2.
      await tester.drag(
        find.byType(DiversificationView),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/7'), findsOneWidget);
      expect(find.byType(VolatilityLineView), findsOneWidget);
    });

    testWidgets('forward swipe unlocks once an asset is added',
        (tester) async {
      await pumpFlow(tester);
      await goToStep3(tester);

      await tester.tap(find.text('채권'));
      await tester.pumpAndSettle();

      // With the gate open, a forward swipe advances to step 4.
      await tester.drag(
        find.byType(DiversificationView),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('4/7'), findsOneWidget);
      expect(find.byType(OptimalRatioDonutView), findsOneWidget);
    });
  });
}
