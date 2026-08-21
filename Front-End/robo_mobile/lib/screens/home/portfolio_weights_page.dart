import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'portfolio_tab.dart';

/// 비중 sub-screen — wraps the original PortfolioTab body. Header reads "내
/// 포트폴리오 비중"; a one-line strategy message above the stats card calls
/// out the current portfolio's risk level (per UIUX 2026-05-20 spec).
class PortfolioWeightsPage extends StatelessWidget {
  const PortfolioWeightsPage({super.key});

  // Returns the strategy-pill message + dot color for the current portfolio.
  // Korean grammar: 낮은/높은 are already adjective forms ("리스크가 낮은
  // 전략"), but 중간 is a noun and needs the 인 copula ("리스크가 중간인 전략").
  ({String message, Color dotColor}) _riskTier(PortfolioState state) {
    final label = state.selectedPortfolio?.label ?? '';
    if (label.contains('안전') || label.contains('보수')) {
      return (
        message: '리스크가 낮은 전략을 적극적으로 활용 중',
        dotColor: WeRoboColors.accent,
      );
    }
    if (label.contains('성장') || label.contains('공격')) {
      return (
        message: '리스크가 높은 전략을 적극적으로 활용 중',
        dotColor: WeRoboColors.dangerRed,
      );
    }
    return (
      message: '리스크가 중간인 전략을 적극적으로 활용 중',
      dotColor: WeRoboColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final tier = _riskTier(state);

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                  const SizedBox(width: 12),
                  Text(
                    '내 포트폴리오 비중',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            // 한줄 전략 메시지 — risk-level card with a colored dot. Passed
            // into PortfolioTab so it scrolls with the rest of the content.
            // Corner radius matches the other cards on this page.
            Expanded(
              child: PortfolioTab(
                leading: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: tc.surface,
                    borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
                    border: Border.all(color: tc.border, width: 1),
                    boxShadow: WeRoboElevation.card(context),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: tier.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tier.message,
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: tc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
