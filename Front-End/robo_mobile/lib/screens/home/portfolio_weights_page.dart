import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'portfolio_tab.dart';

/// 비중 sub-screen — wraps the original PortfolioTab body and adds a one-line
/// strategy message at the top per the UIUX 2026-05-20 spec.
class PortfolioWeightsPage extends StatelessWidget {
  const PortfolioWeightsPage({super.key});

  String _strategyMessage(PortfolioState state) {
    final label = state.selectedPortfolio?.label;
    if (label == null) return '시장에 맞게 균형 잡힌 자산 배분을 적용했어요.';
    // MVP message variants keyed off the portfolio label; expand per
    // strategy as designs land.
    if (label.contains('안전') || label.contains('보수')) {
      return '시장 변동을 최소화하는 방어형 비중으로 운영해요.';
    }
    if (label.contains('공격') || label.contains('성장')) {
      return '성장 가능성이 높은 자산에 비중을 더 두고 있어요.';
    }
    return '시장에 맞게 균형 잡힌 자산 배분을 적용했어요.';
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);

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
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tc.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '비중',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            // Strategy message — one line, primary-tinted card, just above
            // the existing allocation view.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: WeRoboColors.primaryLight,
                  borderRadius:
                      BorderRadius.circular(WeRoboColors.radiusM),
                ),
                child: Text(
                  _strategyMessage(state),
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: WeRoboColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Expanded(child: PortfolioTab()),
          ],
        ),
      ),
    );
  }
}
