import 'package:flutter/material.dart';
import 'app/portfolio_state.dart';
import 'app/theme.dart';
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

  @override
  void dispose() {
    _portfolioState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortfolioStateProvider(
      state: _portfolioState,
      child: MaterialApp(
        title: 'WeRobo',
        debugShowCheckedModeBanner: false,
        theme: WeRoboTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
