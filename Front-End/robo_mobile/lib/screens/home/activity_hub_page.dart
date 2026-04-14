import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/rebalance_insight.dart';
import 'digest_screen.dart';
import 'insight_detail_page.dart';
import 'widgets/glowing_border.dart';
import 'widgets/insight_transition_chart.dart';

class ActivityHubPage extends StatelessWidget {
  const ActivityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final insights = state.insights;

    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
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
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '알림 & 리포트',
                    style:
                        WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                children: [
                  // Digest card
                  _DigestCard(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder<void>(
                        pageBuilder: (_, __, ___) =>
                            const DigestScreen(),
                        transitionsBuilder:
                            (_, anim, __, child) =>
                                FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Insights section
                  Text(
                    '리밸런싱 히스토리',
                    style: WeRoboTypography.heading3
                        .themed(context),
                  ),
                  const SizedBox(height: 12),

                  if (insights.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          '아직 리밸런싱 인사이트가 없습니다.',
                          style:
                              WeRoboTypography.body.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...insights.map(
                      (i) => _InsightCard(insight: i),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DigestCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GlowingBorder(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WeRoboColors.primary
                      .withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: WeRoboColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주간 다이제스트',
                      style: WeRoboTypography.bodySmall
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI가 분석한 이번 주 포트폴리오 리포트',
                      style:
                          WeRoboTypography.caption.copyWith(
                        color: tc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: tc.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final RebalanceInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final text = insight.explanationText != null &&
            insight.explanationText!.length > 60
        ? '${insight.explanationText!.substring(0, 60)}...'
        : insight.explanationText ?? '';

    return Pressable(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) =>
              InsightDetailPage(insight: insight),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            InsightDonutThumbnail(
              allocations: insight.allocations,
              size: 48,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!insight.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin:
                              const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: WeRoboColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        insight.rebalanceDate,
                        style: WeRoboTypography.caption
                            .copyWith(
                          color: WeRoboColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style:
                        WeRoboTypography.bodySmall.copyWith(
                      color: tc.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
