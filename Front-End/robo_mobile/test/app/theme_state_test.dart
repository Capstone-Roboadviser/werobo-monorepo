import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme_state.dart';

void main() {
  test('ThemeNotifier defaults to light mode', () {
    final notifier = ThemeNotifier();
    expect(notifier.mode, ThemeMode.light);
  });

  test('toggle flips light → dark → light', () {
    final notifier = ThemeNotifier();
    notifier.toggle();
    expect(notifier.mode, ThemeMode.dark);
    notifier.toggle();
    expect(notifier.mode, ThemeMode.light);
  });
}
