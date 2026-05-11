import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'widgets/alert_frequency_selector.dart';

/// Shared notification-settings page. Reached from both:
///   - The "알림 설정" link at the top of the notification history page
///   - The "알림 설정" entry inside the new 설정 page (under the 더보기 tab)
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);

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
                    '알림 설정',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ListenableBuilder(
                listenable: portfolioState,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        '알림 빈도',
                        style: WeRoboTypography.heading3.themed(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '시장이 흔들릴 때 얼마나 자주 알려드릴지 골라주세요',
                        style: WeRoboTypography.caption.themed(context),
                      ),
                      const SizedBox(height: 12),
                      AlertFrequencySelector(
                        value: portfolioState.alertFrequency,
                        onChanged: (f) => portfolioState.setAlertFrequency(f),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
