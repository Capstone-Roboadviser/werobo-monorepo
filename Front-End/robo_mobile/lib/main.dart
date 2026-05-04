import 'package:flutter/material.dart';
import 'app/debug_page_logger.dart';
import 'app/portfolio_state.dart';
import 'app/theme.dart';
import 'app/theme_state.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logAction('app boot');
  final portfolioState = PortfolioState();
  await portfolioState.restorePersistedState();
  runApp(WeRoboApp(portfolioState: portfolioState));
}

class WeRoboApp extends StatefulWidget {
  final PortfolioState portfolioState;

  const WeRoboApp({
    super.key,
    required this.portfolioState,
  });

  @override
  State<WeRoboApp> createState() => _WeRoboAppState();
}

class _WeRoboAppState extends State<WeRoboApp> {
  final _themeNotifier = ThemeNotifier();

  @override
  void dispose() {
    widget.portfolioState.dispose();
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortfolioStateProvider(
      state: widget.portfolioState,
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
            initialRoute: '/',
            routes: {
              '/': (_) => const SplashScreen(),
              '/home': (_) => const HomeShell(),
            },
          ),
        ),
      ),
    );
  }
}
