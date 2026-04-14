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
      PortfolioStateProvider.of(context).markInsightAsRead(widget.insight.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final insight = widget.insight;
    final allocationChanges = insight.visibleAllocationChanges;
    final fallbackTradeDetails = allocationChanges.isEmpty
        ? insight.visibleTradeDetails
        : const <RebalanceInsightTrade>[];

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
                        WeRoboMotion.fadeRoute<void>(
                            const InsightHistoryPage()),
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
                    if (insight.allocations.isEmpty)
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: tc.card,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sync_alt_rounded,
                            color: WeRoboColors.primary,
                            size: 48,
                          ),
                        ),
                      )
                    else
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
                    if (insight.hasCashActivity) ...[
                      const SizedBox(height: 24),
                      Text(
                        '현금 흐름',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CashFlowRow(
                        label: '매도로 확보',
                        value: insight.cashFromSales,
                      ),
                      _CashFlowRow(
                        label: '매수에 사용',
                        value: insight.cashToBuys,
                      ),
                      _CashFlowRow(
                        label: '예비현금',
                        value: insight.cashAfter,
                        highlight: true,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Allocation changes list (skip 0% delta)
                    if (allocationChanges.isNotEmpty)
                      ...allocationChanges.map(
                        (alloc) => _AllocationChangeRow(allocation: alloc),
                      )
                    else if (fallbackTradeDetails.isNotEmpty) ...[
                      Text(
                        '실제 조정 내역',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...fallbackTradeDetails.map(
                        (trade) => _TradeDetailRow(trade: trade),
                      ),
                    ],
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

class _CashFlowRow extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _CashFlowRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            _formatWon(value),
            style: WeRoboTypography.bodySmall.copyWith(
              color: highlight ? WeRoboColors.primary : tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final deltaColor = delta > 0 ? tc.accent : const Color(0xFFE57373);

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

class _TradeDetailRow extends StatelessWidget {
  final RebalanceInsightTrade trade;

  const _TradeDetailRow({required this.trade});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final sideColor = trade.isBuy ? tc.accent : const Color(0xFFE57373);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: sideColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade.displayLabel,
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trade.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      trade.subtitle,
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${trade.displayDirectionLabel} ${_formatWon(trade.amount)}',
            style: WeRoboTypography.bodySmall.copyWith(
              color: sideColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatWon(double amount) {
  final value = amount.round().abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(value[i]);
  }
  return '₩$buffer';
}
