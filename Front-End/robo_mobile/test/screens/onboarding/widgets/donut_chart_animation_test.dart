import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/donut_chart.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

// Three-segment chart: cash 50%, shortBond 30%, gold 20%.
// Segments must have labels so the legend rows render.
const _testSegments = [
  DonutSegment(
    weight: 0.5,
    color: Color(0xFFFFC091),
    label: '현금성자산',
  ),
  DonutSegment(
    weight: 0.3,
    color: Color(0xFFFFB57D),
    label: '단기채권',
  ),
  DonutSegment(
    weight: 0.2,
    color: Color(0xFFFFAA69),
    label: '금',
  ),
];

const _chart = DonutChart(
  segments: _testSegments,
  centerLabel: '포트폴리오\n비중',
);

void main() {
  testWidgets(
    'all percentage labels show final values after animation completes',
    (tester) async {
      await tester.pumpWidget(_wrap(_chart));
      // Advance past the full 2-second budget.
      await tester.pump(const Duration(milliseconds: 2100));

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    },
  );

  testWidgets(
    'first segment is mid-animation at 100ms, final value not yet shown',
    (tester) async {
      await tester.pumpWidget(_wrap(_chart));

      await tester.pump(const Duration(milliseconds: 100));

      // At 100ms, segment 0 is mid-interval (interval is [0, 666ms]) and the
      // WeRoboMotion.enter curve is strongly front-loaded, so the count-up
      // reads ~32%, well below the "50%" rounding threshold (which it hits
      // around 413ms).
      expect(find.text('50%'), findsNothing);

      // "30%" and "20%" (second and third final values) must not be visible.
      expect(find.text('30%'), findsNothing);
      expect(find.text('20%'), findsNothing);
    },
  );

  testWidgets(
    'pumpAndSettle shows all final percentages',
    (tester) async {
      await tester.pumpWidget(_wrap(_chart));
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    },
  );
}
