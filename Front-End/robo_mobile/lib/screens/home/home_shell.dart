import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../services/mobile_backend_api.dart';
import 'home_tab.dart';
import 'portfolio_grid_tab.dart';
import 'community_tab.dart';
import 'news_tab.dart';
import 'settings_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Kick off the comparison-backtest fetch ahead of mounting the home
  /// shell. Idempotent and fire-and-forget — call from login/splash
  /// flows so the data lands before the chart paints, letting all four
  /// chart lines animate in together.
  static Future<void> prefetchBacktest(PortfolioState state) async {
    if (state.backtest != null) return;
    final portfolio = state.selectedPortfolio;
    final selection = state.frontierSelection;
    final onboardingPick = state.onboardingFrontierSelection;
    final selectedPointIndex =
        selection?.selectedPointIndex ?? onboardingPick?.selectedPointIndex;
    final targetVolatility = selection?.selectedTargetVolatility ??
        onboardingPick?.targetVolatility;
    final stockWeights = portfolio?.stockWeights;
    if (selectedPointIndex == null &&
        targetVolatility == null &&
        (stockWeights == null || stockWeights.isEmpty)) {
      return;
    }
    try {
      final bt = await MobileBackendApi.instance.fetchComparisonBacktest(
        preferredDataSource: selection?.dataSource ??
            onboardingPick?.dataSource ??
            state.accountSummary?.dataSource,
        investmentHorizon: selection?.resolvedProfile.investmentHorizon ??
            state.accountSummary?.investmentHorizon ??
            'medium',
        selectedPointIndex: selectedPointIndex,
        targetVolatility: targetVolatility,
        stockWeights: stockWeights,
        portfolioCode: portfolio?.code,
        startDate: DateTime.tryParse(state.accountSummary?.startedAt ?? ''),
      );
      state.setBacktest(bt);
    } catch (_) {}
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentTab = 0;
  bool _backtestFetched = false;
  bool _accountFetched = false;
  bool _insightsFetched = false;
  bool _digestFetched = false;

  static const _tabs = [
    HomeTab(),
    PortfolioGridTab(),
    CommunityTab(),
    NewsTab(),
    MoreTab(),
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
    // Defer fetches to a post-frame callback so the synchronous fallback
    // paths in PortfolioState.refresh* (which call notifyListeners without
    // awaiting an API) don't trigger setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
      if (!_digestFetched) {
        _digestFetched = true;
        _fetchWeeklyDigest();
      }
    });
  }

  Future<void> _fetchBacktest() async {
    final state = PortfolioStateProvider.of(context);
    // No-op when login/splash already prefetched — `prefetchBacktest`
    // sets `state.backtest` and exits early on a second call.
    await HomeShell.prefetchBacktest(state);
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

  Future<void> _fetchWeeklyDigest() async {
    final state = PortfolioStateProvider.of(context);
    if (!state.isLoggedIn) {
      return;
    }
    try {
      await state.refreshWeeklyDigest(notify: true);
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
      body: Stack(
        children: [
          IndexedStack(
            index: _currentTab,
            children: _tabs,
          ),
          // Global notification bell (pinned per UIUX 2026-05-20 spec).
          // Shows on every tab; HomeTab also stops drawing its own bell.
          const Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 12, right: 16),
                child: _GlobalNotificationIcon(),
              ),
            ),
          ),
        ],
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
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_rounded,
                    label: '홈',
                    isActive: _currentTab == 0,
                    showAlertDot: PortfolioStateProvider.of(context)
                        .hasUnreadEmergencyAlert,
                    onTap: () {
                      logAction('tab selected', {'tab': 'home'});
                      setState(() => _currentTab = 0);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.pie_chart_rounded,
                    label: '포트폴리오',
                    isActive: _currentTab == 1,
                    onTap: () {
                      logAction('tab selected', {'tab': 'portfolio'});
                      setState(() => _currentTab = 1);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.forum_rounded,
                    label: '커뮤니티',
                    isActive: _currentTab == 2,
                    onTap: () {
                      logAction('tab selected', {'tab': 'community'});
                      setState(() => _currentTab = 2);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.article_rounded,
                    label: '뉴스',
                    isActive: _currentTab == 3,
                    onTap: () {
                      logAction('tab selected', {'tab': 'news'});
                      setState(() => _currentTab = 3);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.menu_rounded,
                    label: '전체',
                    isActive: _currentTab == 4,
                    onTap: () {
                      logAction('tab selected', {'tab': 'more'});
                      setState(() => _currentTab = 4);
                    },
                  ),
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
  final bool showAlertDot;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showAlertDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final color = isActive ? WeRoboColors.primary : tc.textSecondary;

    return Pressable(
      onTap: onTap,
      scale: 0.90,
      duration: const Duration(milliseconds: 100),
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                if (showAlertDot)
                  const Positioned(
                    right: -4,
                    top: -2,
                    child: _AlertDot(),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: WeRoboTypography.caption.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertDot extends StatelessWidget {
  const _AlertDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: WeRoboColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Bell icon overlay rendered above every HomeShell tab so notifications
/// are reachable from any screen (UIUX 2026-05-20 spec). Tapping reuses the
/// same `showNotificationsSheet` entry point as the legacy in-tab bell.
class _GlobalNotificationIcon extends StatelessWidget {
  const _GlobalNotificationIcon();

  @override
  Widget build(BuildContext context) {
    final state = PortfolioStateProvider.of(context);
    final hasUnread = state.unreadInsightCount > 0;
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: () => showNotificationsSheet(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tc.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              hasUnread
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 22,
              color: tc.textPrimary,
            ),
            if (hasUnread)
              const Positioned(
                top: 8,
                right: 10,
                child: _AlertDot(),
              ),
          ],
        ),
      ),
    );
  }
}
