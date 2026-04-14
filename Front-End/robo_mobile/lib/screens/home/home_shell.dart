import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../services/mobile_backend_api.dart';
import 'home_tab.dart';
import 'portfolio_tab.dart';
import 'community_tab.dart';
import 'settings_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentTab = 0;
  bool _backtestFetched = false;
  bool _accountFetched = false;
  bool _insightsFetched = false;

  static const _tabs = [
    HomeTab(),
    PortfolioTab(),
    CommunityTab(),
    SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    logPageEnter('HomeShell');
    logAction('tab selected', {
      'tab': 'home',
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_backtestFetched) {
      _backtestFetched = true;
      _fetchBacktest();
    }
    if (!_accountFetched) {
      _accountFetched = true;
      _fetchAccountDashboard();
    }
    if (!_insightsFetched) {
      _insightsFetched = true;
      _fetchInsights();
    }
  }

  Future<void> _fetchBacktest() async {
    try {
      final state = PortfolioStateProvider.of(context);
      final portfolio = state.selectedPortfolio;
      final bt = await MobileBackendApi.instance.fetchComparisonBacktest(
        preferredDataSource: state.frontierSelection?.dataSource ??
            state.accountSummary?.dataSource,
        stockWeights: portfolio?.stockWeights,
        portfolioCode: portfolio?.code,
      );
      if (!mounted) return;
      PortfolioStateProvider.of(context).setBacktest(bt);
    } catch (_) {}
  }

  Future<void> _fetchAccountDashboard() async {
    final state = PortfolioStateProvider.of(context);
    if (!state.isLoggedIn) {
      return;
    }
    try {
      await state.refreshAccountDashboard(notify: true);
    } catch (_) {}
  }

  Future<void> _fetchInsights() async {
    final state = PortfolioStateProvider.of(context);
    try {
      await state.refreshInsights(notify: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    logPageExit('HomeShell');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      body: IndexedStack(
        index: _currentTab,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        color: tc.background,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '홈',
                  isActive: _currentTab == 0,
                  onTap: () {
                    logAction('tab selected', {'tab': 'home'});
                    setState(() => _currentTab = 0);
                  },
                ),
                _NavItem(
                  icon: Icons.pie_chart_rounded,
                  label: '포트폴리오',
                  isActive: _currentTab == 1,
                  onTap: () {
                    logAction('tab selected', {'tab': 'portfolio'});
                    setState(() => _currentTab = 1);
                  },
                ),
                _NavItem(
                  icon: Icons.forum_rounded,
                  label: '커뮤니티',
                  isActive: _currentTab == 2,
                  onTap: () {
                    logAction('tab selected', {'tab': 'community'});
                    setState(() => _currentTab = 2);
                  },
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: '설정',
                  isActive: _currentTab == 3,
                  onTap: () {
                    logAction('tab selected', {'tab': 'settings'});
                    setState(() => _currentTab = 3);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final color = isActive ? Colors.white : tc.textSecondary;

    return Pressable(
      onTap: onTap,
      scale: 0.90,
      duration: const Duration(milliseconds: 100),
      child: SizedBox(
        width: 64,
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
}
