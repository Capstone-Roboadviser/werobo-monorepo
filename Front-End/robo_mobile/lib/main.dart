import 'package:flutter/material.dart';
import 'app/portfolio_state.dart';
import 'app/theme.dart';
import 'app/theme_state.dart';
import 'screens/onboarding/splash_screen.dart';

void main() {
  runApp(const WeRoboApp());
}

class WeRoboApp extends StatefulWidget {
  const WeRoboApp({super.key});

  @override
  State<WeRoboApp> createState() => _WeRoboAppState();
}

class _WeRoboAppState extends State<WeRoboApp> {
  final _portfolioState = PortfolioState();
  final _themeNotifier = ThemeNotifier();

  @override
  void dispose() {
    _portfolioState.dispose();
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortfolioStateProvider(
      state: _portfolioState,
      child: ThemeStateProvider(
        notifier: _themeNotifier,
        child: ListenableBuilder(
          listenable: _themeNotifier,
          builder: (context, _) => MaterialApp(
            title: 'WeRobo',
            debugShowCheckedModeBanner: false,
            theme: WeRoboTheme.light,
            darkTheme: WeRoboTheme.dark,
            themeMode: _themeNotifier.mode,
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
