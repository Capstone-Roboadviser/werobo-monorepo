import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/rebalance_insight.dart';
import 'insight_history_page.dart';
import 'widgets/insight_transition_chart.dart';

class InsightDetailPage extends StatefulWidget {
  final RebalanceInsight insight;

  const InsightDetailPage({super.key, required this.insight});

  @override
  State<InsightDetailPage> createState() => _InsightDetailPageState();
}

class _InsightDetailPageState extends State<InsightDetailPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.insight.isRead) {
      PortfolioStateProvider.of(context)
          .markInsightAsRead(widget.insight.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final insight = widget.insight;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: close + menu
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        Icons.close_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder<void>(
                          pageBuilder: (_, __, ___) =>
                              const InsightHistoryPage(),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tc.card,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.menu_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),

                    // Animated transition chart
                    Center(
                      child: InsightTransitionChart(
                        allocations: insight.allocations,
                        size: 220,
                        ringWidth: 28,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date
                    Text(
                      insight.rebalanceDate,
                      style: WeRoboTypography.caption.copyWith(
                        color: WeRoboColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      '포트폴리오 비중을 조정했어요.',
                      style: WeRoboTypography.heading3
                          .themed(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),

                    // Explanation text (generated from allocation
                    // data so it always matches visible rows)
                    Text(
                      insight.generatedExplanation,
                      style: WeRoboTypography.body.copyWith(
                        color: tc.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Allocation changes list (skip 0% delta)
                    ...insight.allocations
                        .where((a) => a.hasChanged)
                        .map(
                          (alloc) =>
                              _AllocationChangeRow(allocation: alloc),
                        ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationChangeRow extends StatelessWidget {
  final RebalanceInsightAllocation allocation;

  const _AllocationChangeRow({required this.allocation});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final delta = allocation.displayDelta;
    final deltaText = delta >= 0
        ? '(+${delta.toStringAsFixed(1)}%)'
        : '(${delta.toStringAsFixed(1)}%)';
    final deltaColor = delta > 0
        ? tc.accent
        : const Color(0xFFE57373);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: allocation.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              allocation.displayName,
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
              ),
            ),
          ),
          Text(
            '${allocation.beforeDisplay.toStringAsFixed(1)}%',
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textTertiary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: tc.textTertiary,
            ),
          ),
          Text(
            '${allocation.afterDisplay.toStringAsFixed(1)}%',
            style: WeRoboTypography.bodySmall.copyWith(
              color: deltaColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deltaText,
            style: WeRoboTypography.bodySmall.copyWith(
              color: deltaColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
