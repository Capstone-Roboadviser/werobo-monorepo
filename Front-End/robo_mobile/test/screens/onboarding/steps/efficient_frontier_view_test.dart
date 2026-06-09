import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/steps/efficient_frontier_view.dart';

void main() {
  // Mirrors how the orchestrator sizes the body: a bounded box (the scaffold's
  // Expanded region) under the themed surface, with a supplied entrance value.
  Widget wrap(Animation<double> entrance) {
    return MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 420,
            child: OnboardingFrontierView(entrance: entrance),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the frontier visual with a CustomPaint', (tester) async {
    await tester.pumpWidget(wrap(const AlwaysStoppedAnimation<double>(1.0)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(OnboardingFrontierView), findsOneWidget);
    // The illustration is painted, not composed from child widgets.
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('exposes axis + recommendation labels via semantics',
      (tester) async {
    await tester.pumpWidget(wrap(const AlwaysStoppedAnimation<double>(1.0)));
    await tester.pump();

    // The painter draws the text on the canvas, so we surface the key copy
    // (Y axis, X axis, recommendation tooltip) through a Semantics label the
    // test can assert on.
    final handle = tester.ensureSemantics();
    final label = '${OnboardingFrontierView.yAxisLabel} · '
        '${OnboardingFrontierView.xAxisLabel} · '
        '${OnboardingFrontierView.tooltipLabel}';
    expect(find.bySemanticsLabel(label), findsOneWidget);
    handle.dispose();
  });

  testWidgets('pins the expected Korean copy constants', (tester) async {
    // Guards against accidental copy drift in the spec'd labels.
    expect(OnboardingFrontierView.yAxisLabel, '기대 수익');
    expect(OnboardingFrontierView.xAxisLabel, '위험 (변동성)');
    expect(OnboardingFrontierView.highLabel, '높음');
    expect(OnboardingFrontierView.lowLabel, '낮음');
    expect(OnboardingFrontierView.tooltipLabel, '추천 포트폴리오');
  });

  testWidgets('drives its reveal off entrance (fades from 0 to full opacity)',
      (tester) async {
    // At entrance 0 the whole visual is fully transparent; at 1 it is opaque.
    // Scope to the Opacity the view itself inserts (its AnimatedBuilder
    // wrapper) so the assert isn't coupled to framework-internal Opacity.
    Opacity viewOpacity(WidgetTester t) {
      final finder = find.descendant(
        of: find.byType(OnboardingFrontierView),
        matching: find.byType(Opacity),
      );
      return t.widget<Opacity>(finder.first);
    }

    await tester.pumpWidget(wrap(const AlwaysStoppedAnimation<double>(0.0)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(viewOpacity(tester).opacity, 0.0);

    await tester.pumpWidget(wrap(const AlwaysStoppedAnimation<double>(1.0)));
    await tester.pump();
    expect(viewOpacity(tester).opacity, 1.0);
  });

  testWidgets('paints cleanly at a mid-entrance value', (tester) async {
    // A partial draw exercises the interval gating (scatter/curve/dot) and the
    // arrowhead/tooltip clamping without throwing.
    await tester.pumpWidget(wrap(const AlwaysStoppedAnimation<double>(0.5)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
