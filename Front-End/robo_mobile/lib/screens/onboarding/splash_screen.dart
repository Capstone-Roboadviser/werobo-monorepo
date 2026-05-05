import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;
  Timer? _navigationTimer;
  bool _didScheduleNavigation = false;

  @override
  void initState() {
    super.initState();
    logPageEnter('SplashScreen');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: WeRoboMotion.enter),
      ),
    );

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: WeRoboMotion.emphasize),
      ),
    );

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleNavigation) {
      return;
    }
    _didScheduleNavigation = true;
    _scheduleNavigation();
  }

  @override
  void dispose() {
    logPageExit('SplashScreen');
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scheduleNavigation() async {
    final state = PortfolioStateProvider.of(context);
    await state.validateAuthSession();
    // Auto-enter path: prime the backtest fetch in parallel with the
    // 2-second splash timer so the home chart's draw animation kicks
    // off immediately on arrival instead of waiting for data.
    if (state.canAutoEnterHome) {
      unawaited(HomeShell.prefetchBacktest(state));
    }
    _navigationTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) {
        return;
      }
      final destination =
          state.canAutoEnterHome ? const HomeShell() : const LoginScreen();
      logAction('route from splash', {
        'target': state.canAutoEnterHome ? 'home' : 'login',
        'loggedIn': state.isLoggedIn,
        'hasPortfolio': state.hasCompletedPortfolioSetup,
      });
      Navigator.of(context).pushReplacement(
        WeRoboMotion.fadeRoute(destination),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeRoboColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Text(
              'WeRobo',
              style: WeRoboTypography.logo,
            ),
          ),
        ),
      ),
    );
  }
}
