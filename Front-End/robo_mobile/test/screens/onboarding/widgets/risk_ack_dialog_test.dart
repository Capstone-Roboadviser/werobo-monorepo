import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/risk_ack_dialog.dart';

void main() {
  group('RiskAckDialog', () {
    testWidgets(
      '확인 후 유지 is disabled until checkbox is ticked, '
      'then resolves to true',
      (tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: WeRoboTheme.light,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      showRiskAckDialog(
                        context: ctx,
                        marketVolPct: 10.0,
                        userVolPct: 45.0,
                      ).then((v) => dialogResult = v);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open the dialog.
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Confirm button should be disabled initially.
        final confirmButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '확인 후 유지'),
        );
        expect(confirmButton.onPressed, isNull);

        // Tick the checkbox.
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Confirm button should now be enabled.
        final enabledButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '확인 후 유지'),
        );
        expect(enabledButton.onPressed, isNotNull);

        // Tap confirm.
        await tester.tap(find.widgetWithText(ElevatedButton, '확인 후 유지'));
        await tester.pumpAndSettle();

        expect(dialogResult, isTrue);
      },
    );
  });
}
