import 'package:flutter/material.dart';

import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'account_page.dart';
import 'settings_page.dart';

/// "전체" tab (formerly 설정). Top-level account / app links. The actual
/// 설정 page (보안, 알림 설정, 다크 모드) lives behind the "설정" row.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('전체', style: WeRoboTypography.heading2.themed(context)),
            const SizedBox(height: 24),
            _MoreItem(
              icon: Icons.person_outline_rounded,
              label: '계정',
              onTap: () => Navigator.of(context).push(
                WeRoboMotion.fadeRoute<void>(const AccountPage()),
              ),
            ),
            _MoreItem(
              icon: Icons.settings_rounded,
              label: '설정',
              onTap: () => Navigator.of(context).push(
                WeRoboMotion.fadeRoute<void>(const SettingsPage()),
              ),
            ),
            _MoreItem(
              icon: Icons.help_outline_rounded,
              label: '도움말',
              onTap: () {},
            ),
            _MoreItem(
              icon: Icons.info_outline_rounded,
              label: '앱 정보',
              onTap: () {},
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

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreItem({
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
