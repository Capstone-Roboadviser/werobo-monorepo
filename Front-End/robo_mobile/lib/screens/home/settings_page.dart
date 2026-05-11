import 'package:flutter/material.dart';

import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../app/theme_state.dart';
import 'notification_settings_page.dart';

/// Top-level 설정 page reached from the 더보기 tab. Hosts 보안, 알림 설정,
/// and the 다크 모드 toggle. Other operational items (프로필, 도움말,
/// 앱 정보, 로그아웃) stay on the 더보기 tab itself.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final themeNotifier = ThemeStateProvider.of(context);
    final isDark = themeNotifier.mode == ThemeMode.dark;

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
                    '설정',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    label: '보안',
                    onTap: () => Navigator.of(context).push(
                      WeRoboMotion.fadeRoute<void>(
                        const _ComingSoonPage(title: '보안'),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    label: '알림 설정',
                    onTap: () => Navigator.of(context).push(
                      WeRoboMotion.fadeRoute<void>(
                        const NotificationSettingsPage(),
                      ),
                    ),
                  ),
                  _DarkModeRow(
                    isDark: isDark,
                    onToggle: () => themeNotifier.toggle(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsRow({
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

class _DarkModeRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _DarkModeRow({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
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
          Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            size: 22,
            color: tc.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '다크 모드',
              style: WeRoboTypography.body
                  .copyWith(color: tc.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeTrackColor: WeRoboColors.primary,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  final String title;
  const _ComingSoonPage({required this.title});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
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
                    title,
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '준비중입니다',
                  style: WeRoboTypography.body
                      .copyWith(color: tc.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
