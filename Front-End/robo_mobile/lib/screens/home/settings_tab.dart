import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../app/theme_state.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final themeNotifier = ThemeStateProvider.of(context);
    final isDark = themeNotifier.mode == ThemeMode.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('설정',
                style: WeRoboTypography.heading2.themed(context)),
            const SizedBox(height: 24),

            // Dark mode toggle
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 16),
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
                  Icon(isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                      size: 22, color: tc.textSecondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('다크 모드',
                        style: WeRoboTypography.body.copyWith(
                            color: tc.textPrimary)),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    activeTrackColor: WeRoboColors.primary,
                    onChanged: (_) => themeNotifier.toggle(),
                  ),
                ],
              ),
            ),

            // Auto-rebalancing toggle
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 16),
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
                  Icon(Icons.sync_rounded,
                      size: 22, color: tc.textSecondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('자동 리밸런싱',
                            style: WeRoboTypography.body
                                .copyWith(
                                    color: tc.textPrimary)),
                        Text('분기별 자동 포트폴리오 조정',
                            style: WeRoboTypography.caption
                                .themed(context)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: true,
                    activeTrackColor: WeRoboColors.primary,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),

            _SettingsItem(
              icon: Icons.person_outline_rounded,
              label: '프로필',
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

class _SettingsItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
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
            Icon(widget.icon, size: 22, color: tc.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label,
                  style: WeRoboTypography.body.copyWith(
                      color: tc.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: tc.textTertiary),
          ],
        ),
      ),
      ),
    );
  }
}
