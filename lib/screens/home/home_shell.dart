import 'package:flutter/material.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
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

  static const _tabs = [
    HomeTab(),
    PortfolioTab(),
    CommunityTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: IndexedStack(
        index: _currentTab,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WeRoboColors.surface,
          border: Border(
            top: BorderSide(
              color: WeRoboColors.lightGray.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '홈',
                  isActive: _currentTab == 0,
                  onTap: () => setState(() => _currentTab = 0),
                ),
                _NavItem(
                  icon: Icons.pie_chart_rounded,
                  label: '포트폴리오',
                  isActive: _currentTab == 1,
                  onTap: () => setState(() => _currentTab = 1),
                ),
                _NavItem(
                  icon: Icons.forum_rounded,
                  label: '커뮤니티',
                  isActive: _currentTab == 2,
                  onTap: () => setState(() => _currentTab = 2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: '설정',
                  isActive: _currentTab == 3,
                  onTap: () => setState(() => _currentTab = 3),
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
    final color =
        isActive ? WeRoboColors.primary : WeRoboColors.textTertiary;

    return Pressable(
      onTap: onTap,
      scale: 0.90,
      duration: const Duration(milliseconds: 100),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive
                    ? WeRoboColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
