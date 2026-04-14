import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/rebalance_insight.dart';
import 'insight_detail_page.dart';
import 'widgets/insight_transition_chart.dart';

class InsightHistoryPage extends StatelessWidget {
  const InsightHistoryPage({super.key});

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
                    onTap: () => Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    ),
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
                    '리밸런싱 히스토리',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: insights.isEmpty
                  ? Center(
                      child: Text(
                        '아직 리밸런싱 인사이트가 없습니다.',
                        style: WeRoboTypography.body.copyWith(
                          color: tc.textTertiary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      itemCount: insights.length,
                      itemBuilder: (context, index) {
                        return _InsightHistoryCard(
                          insight: insights[index],
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

class _InsightHistoryCard extends StatelessWidget {
  final RebalanceInsight insight;

  const _InsightHistoryCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final explanation = insight.generatedExplanation;
    final truncatedText = explanation.length > 60
        ? '${explanation.substring(0, 60)}...'
        : explanation;

    return Pressable(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) =>
                InsightDetailPage(insight: insight),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Donut thumbnail
            InsightDonutThumbnail(
              allocations: insight.allocations,
              size: 48,
            ),
            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!insight.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: WeRoboColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        insight.rebalanceDate,
                        style: WeRoboTypography.caption.copyWith(
                          color: WeRoboColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    truncatedText,
                    style: WeRoboTypography.bodySmall.copyWith(
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
