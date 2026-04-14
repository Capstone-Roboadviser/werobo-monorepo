import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../app/theme_state.dart';
import '../onboarding/splash_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _handleLogout(
    BuildContext context,
    PortfolioState portfolioState,
  ) async {
    logAction('tap logout');
    await portfolioState.logout();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final themeNotifier = ThemeStateProvider.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final isDark = themeNotifier.mode == ThemeMode.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('설정', style: WeRoboTypography.heading2.themed(context)),
            const SizedBox(height: 24),

            // Dark mode toggle
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                  Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 22,
                      color: tc.textSecondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('다크 모드',
                        style: WeRoboTypography.body
                            .copyWith(color: tc.textPrimary)),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    activeTrackColor: WeRoboColors.primary,
                    onChanged: (_) => themeNotifier.toggle(),
                  ),
                ],
              ),
            ),

            _SettingsItem(
              icon: Icons.person_outline_rounded,
              label: portfolioState.currentUser == null
                  ? '프로필'
                  : '${portfolioState.currentUser!.name} (${portfolioState.currentUser!.email})',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.notifications_none_rounded,
              label: '알림 설정',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.shield_outlined,
              label: '보안',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.help_outline_rounded,
              label: '도움말',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.info_outline_rounded,
              label: '앱 정보',
              onTap: () {},
            ),
            if (portfolioState.isLoggedIn)
              _SettingsItem(
                icon: Icons.logout_rounded,
                label: '로그아웃',
                onTap: () {
                  _handleLogout(context, portfolioState);
                },
              ),
            const Spacer(),
            Center(
              child: Text(
                'WeRobo v1.0.0',
                style: WeRoboTypography.caption.themed(context),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({
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
              child: Text(label,
                  style:
                      WeRoboTypography.body.copyWith(color: tc.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: tc.textTertiary),
          ],
        ),
      ),
    );
  }
}
