import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/widgets/digest_sheet.dart';

void main() {
  group('DigestSheetShell', () {
    testWidgets('renders drag handle and X close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: const Scaffold(
            body: DigestSheetShell(
              child: Center(child: Text('body')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('digest_sheet_drag_handle')), findsOneWidget);
      expect(find.byKey(const Key('digest_sheet_close_button')), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('tapping X pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const DigestSheetShell(
                      child: SizedBox(height: 200, child: Text('body')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);

      await tester.tap(find.byKey(const Key('digest_sheet_close_button')));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
    });
  });
}
