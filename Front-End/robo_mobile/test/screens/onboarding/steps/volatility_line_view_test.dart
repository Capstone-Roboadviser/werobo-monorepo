import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/steps/volatility_line_view.dart';

/// Wraps the step body in a themed scaffold with a bounded box, mirroring the
/// `Expanded` region the orchestrator hands each step.
Widget _wrap(Animation<double> entrance) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 360,
            child: VolatilityLineView(entrance: entrance),
          ),
        ),
      ),
    );

/// Finds the `CustomPaint` whose painter is the view's volatility painter.
/// The painter is private to the view, so we match on its runtime type name.
Finder _volatilityPaint() => find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_VolatilityLinePainter',
    );

void main() {
  testWidgets(
    'renders the volatility line painter inside the available box',
    (tester) async {
      // Always-complete entrance (fully revealed).
      await tester.pumpWidget(_wrap(const AlwaysStoppedAnimation<double>(1)));
      await tester.pumpAndSettle();

      expect(find.byType(VolatilityLineView), findsOneWidget);
      expect(_volatilityPaint(), findsOneWidget);
      // The step body is purely the painted visual. It owns no headline or
      // caption text (the scaffold renders those).
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paints without error at the start of the entrance (nothing drawn yet)',
    (tester) async {
      // A 0-value entrance means nothing is visible yet; the painter
      // early-returns (drawFraction <= 0) but must still mount cleanly.
      await tester.pumpWidget(_wrap(const AlwaysStoppedAnimation<double>(0)));
      await tester.pump();

      expect(_volatilityPaint(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advancing the entrance repaints with a new draw fraction',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: WeRoboMotion.long,
      );

      await tester.pumpWidget(_wrap(controller));

      controller.value = 0.5;
      await tester.pump();
      final midPainter =
          (tester.widget<CustomPaint>(_volatilityPaint())).painter;

      controller.value = 1.0;
      await tester.pump();
      final endPainter =
          (tester.widget<CustomPaint>(_volatilityPaint())).painter;

      // AnimatedBuilder rebuilds the CustomPaint with a fresh painter as the
      // entrance value changes, so the two instances differ.
      expect(midPainter, isNot(same(endPainter)));
      expect(tester.takeException(), isNull);

      controller.dispose();
    },
  );

  testWidgets(
    'drives a real forward entrance from 0 to 1 without error',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: WeRoboMotion.long,
      );
      final entrance = CurvedAnimation(
        parent: controller,
        curve: WeRoboMotion.enter,
      );

      await tester.pumpWidget(_wrap(entrance));
      controller.forward();
      // First frame registers the ticker's t=0; the next frame advances the
      // clock through the full 400ms entrance plus a frame of slack.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.value, 1.0);
      expect(_volatilityPaint(), findsOneWidget);
      expect(tester.takeException(), isNull);

      controller.dispose();
    },
  );
}
