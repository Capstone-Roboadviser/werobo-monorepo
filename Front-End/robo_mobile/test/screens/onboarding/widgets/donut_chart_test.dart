import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/donut_chart.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders with explicit segments', (tester) async {
    await tester.pumpWidget(_wrap(const DonutChart(
      segments: [
        DonutSegment(weight: 0.5, color: Color(0xFFFE9337)),
        DonutSegment(weight: 0.5, color: Color(0xFFFFC091)),
      ],
      centerLabel: 'TEST',
    )));
    await tester.pumpAndSettle();
    expect(find.text('TEST'), findsOneWidget);
  });

  testWidgets('compact mode uses smaller diameter', (tester) async {
    await tester.pumpWidget(_wrap(const DonutChart(
      segments: [DonutSegment(weight: 1.0, color: Color(0xFFFE9337))],
      centerLabel: 'X',
      compact: true,
    )));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(DonutChart));
    expect(size.width, 180); // compact diameter per DESIGN.md
  });
}
