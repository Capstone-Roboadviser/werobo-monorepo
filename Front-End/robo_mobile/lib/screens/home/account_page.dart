import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../onboarding/splash_screen.dart';

/// Account page reached from the 계정 entry in the 전체 tab.
/// Shows the signed-in user and hosts the 로그아웃 action.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _handleLogout(
    BuildContext context,
    PortfolioState portfolioState,
  ) async {
    logAction('tap logout');
    await portfolioState.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final user = portfolioState.currentUser;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '계정',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: WeRoboTypography.heading3.themed(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: tc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (portfolioState.isLoggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _AccountRow(
                  icon: Icons.logout_rounded,
                  label: '로그아웃',
                  onTap: () => _handleLogout(context, portfolioState),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: tc.border.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tc.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: WeRoboTypography.body
                    .copyWith(color: tc.textPrimary),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tc.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
