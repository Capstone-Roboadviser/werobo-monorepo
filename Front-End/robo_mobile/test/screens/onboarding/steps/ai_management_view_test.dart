import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/steps/ai_management_view.dart';

void main() {
  // The widget runs an internal looping AnimationController, so the tree never
  // settles — drive it with explicit `pump()`s and never `pumpAndSettle()`.
  Future<void> pumpView(
    WidgetTester tester, {
    required Animation<double> entrance,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: Scaffold(
          // Bound the Expanded-style body the scaffold normally provides.
          body: Center(
            child: SizedBox(
              width: 320,
              height: 360,
              child: AiManagementView(entrance: entrance),
            ),
          ),
        ),
      ),
    );
    // One frame past mount; avoid pumpAndSettle (the loop repeats forever).
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('renders the AI chip label and four satellite icons',
      (tester) async {
    await pumpView(
      tester,
      entrance: const AlwaysStoppedAnimation<double>(1),
    );

    // Central chip label.
    expect(find.text('AI'), findsOneWidget);

    // The four satellite glyphs from the spec.
    expect(find.byIcon(Icons.shield), findsOneWidget);
    expect(find.byIcon(Icons.oil_barrel), findsOneWidget);
    expect(find.byIcon(Icons.directions_boat_filled), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
  });

  testWidgets('paints the radial connectors/chip via CustomPaint',
      (tester) async {
    await pumpView(
      tester,
      entrance: const AlwaysStoppedAnimation<double>(1),
    );

    // The connectors + glowing chip are drawn with a CustomPaint; ensure at
    // least one is present (there may be other framework CustomPaints).
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('honors the exact const constructor contract', (tester) async {
    // Mirrors the orchestrator's call site:
    //   AiManagementView(entrance: entrance)
    const widget = AiManagementView(
      entrance: AlwaysStoppedAnimation<double>(1),
    );
    expect(widget.entrance.value, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 300, height: 300, child: widget),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(AiManagementView), findsOneWidget);
  });

  testWidgets('stays mounted while the entrance animation is mid-flight',
      (tester) async {
    // A partial entrance value must not throw (Opacity clamps, satellites
    // stagger). Use a controller-backed animation at t=0.4.
    final controller = AnimationController(
      vsync: tester,
      duration: WeRoboMotion.long,
    );
    final entrance = CurvedAnimation(
      parent: controller,
      curve: WeRoboMotion.enter,
    );
    controller.value = 0.4;

    await pumpView(tester, entrance: entrance);
    expect(tester.takeException(), isNull);
    expect(find.text('AI'), findsOneWidget);

    entrance.dispose();
    controller.dispose();
  });

  testWidgets('disposes its internal loop controller cleanly',
      (tester) async {
    await pumpView(
      tester,
      entrance: const AlwaysStoppedAnimation<double>(1),
    );

    // Replacing the tree tears down the State; a leaked controller would throw
    // during teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
