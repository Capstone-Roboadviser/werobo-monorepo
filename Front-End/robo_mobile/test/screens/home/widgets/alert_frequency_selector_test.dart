import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/widgets/alert_frequency_selector.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );

void main() {
  testWidgets('renders three labels', (tester) async {
    await tester.pumpWidget(_wrap(AlertFrequencySelector(
      value: AlertFrequency.normal,
      onChanged: (_) {},
    )));
    expect(find.text('자주 받기'), findsOneWidget);
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('중요할 때만'), findsOneWidget);
  });

  testWidgets('tap fires onChanged with correct value', (tester) async {
    AlertFrequency? selected;
    await tester.pumpWidget(_wrap(AlertFrequencySelector(
      value: AlertFrequency.normal,
      onChanged: (f) => selected = f,
    )));
    await tester.tap(find.text('중요할 때만'));
    expect(selected, AlertFrequency.important);
  });
}
