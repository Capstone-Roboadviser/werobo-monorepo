import 'package:flutter/material.dart';

/// App-wide theme mode notifier.
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  void toggle() {
    _mode =
        _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}

/// Provides [ThemeNotifier] down the widget tree.
class ThemeStateProvider extends InheritedNotifier<ThemeNotifier> {
  const ThemeStateProvider({
    super.key,
    required ThemeNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeNotifier of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeStateProvider>()!
        .notifier!;
  }
}
