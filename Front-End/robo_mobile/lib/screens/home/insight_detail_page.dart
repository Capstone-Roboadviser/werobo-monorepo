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
  final Set<String> _expandedTradeGroups = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.insight.isRead) {
      PortfolioStateProvider.of(context).markInsightAsRead(widget.insight.id);
    }
  }

  void _toggleTradeGroup(String assetCode) {
    setState(() {
      if (_expandedTradeGroups.contains(assetCode)) {
        _expandedTradeGroups.remove(assetCode);
      } else {
        _expandedTradeGroups.add(assetCode);
      }
    });
  }

  List<_InsightTradeGroup> _buildTradeGroups(
    List<RebalanceInsightTrade> trades,
    List<RebalanceInsightAllocation> allocations,
  ) {
    final allocationByCode = <String, RebalanceInsightAllocation>{
      for (final allocation in allocations) allocation.assetCode: allocation,
    };
    final allocationOrder = <String, int>{
      for (int i = 0; i < allocations.length; i++) allocations[i].assetCode: i,
    };
    final grouped = <String, List<RebalanceInsightTrade>>{};

    for (final trade in trades) {
      final key = trade.assetCode.isNotEmpty
          ? trade.assetCode
          : (trade.assetName.isNotEmpty ? trade.assetName : trade.ticker);
      grouped.putIfAbsent(key, () => <RebalanceInsightTrade>[]).add(trade);
    }

    final groups = grouped.entries.map((entry) {
      final groupTrades = entry.value.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      final firstTrade = groupTrades.first;
      final allocation = allocationByCode[entry.key];

      return _InsightTradeGroup(
        assetCode: entry.key,
        assetName: firstTrade.assetName.isNotEmpty
            ? firstTrade.assetName
            : (allocation?.displayName ?? entry.key),
        color: allocation?.color ?? WeRoboColors.silver,
        trades: groupTrades,
      );
    }).toList();

    groups.sort((a, b) {
      final orderA = allocationOrder[a.assetCode] ?? 1 << 20;
      final orderB = allocationOrder[b.assetCode] ?? 1 << 20;
      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      return b.totalAmount.compareTo(a.totalAmount);
    });

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final insight = widget.insight;
    final allocationChanges = insight.visibleAllocationChanges;
    final tradeGroups = _buildTradeGroups(
      insight.visibleTradeDetails,
      insight.allocations,
    );
    final tradeGroupByCode = <String, _InsightTradeGroup>{
      for (final group in tradeGroups) group.assetCode: group,
    };
    final remainingTradeGroups = <_InsightTradeGroup>[];
    for (final group in tradeGroups) {
      final hasVisibleAllocation = allocationChanges.any(
        (allocation) => allocation.assetCode == group.assetCode,
      );
      if (!hasVisibleAllocation) {
        remainingTradeGroups.add(group);
      }
    }

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
                        (alloc) {
                          final tradeGroup = tradeGroupByCode[alloc.assetCode];
                          return _AllocationChangeRow(
                            allocation: alloc,
                            tradeGroup: tradeGroup,
                            expanded: tradeGroup != null &&
                                _expandedTradeGroups.contains(
                                  tradeGroup.assetCode,
                                ),
                            onToggle: tradeGroup == null
                                ? null
                                : () => _toggleTradeGroup(tradeGroup.assetCode),
                          );
                        },
                      )
                    else if (tradeGroups.isNotEmpty) ...[
                      Text(
                        '실제 조정 티커',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...tradeGroups.map(
                        (group) => _TradeDetailGroupRow(
                          group: group,
                          expanded: _expandedTradeGroups.contains(
                            group.assetCode,
                          ),
                          onToggle: () => _toggleTradeGroup(group.assetCode),
                        ),
                      ),
                    ],
                    if (remainingTradeGroups.isNotEmpty &&
                        allocationChanges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '같은 자산군 안에서 조정된 티커',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...remainingTradeGroups.map(
                        (group) => _TradeDetailGroupRow(
                          group: group,
                          expanded: _expandedTradeGroups.contains(
                            group.assetCode,
                          ),
                          onToggle: () => _toggleTradeGroup(group.assetCode),
                        ),
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
  final _InsightTradeGroup? tradeGroup;
  final bool expanded;
  final VoidCallback? onToggle;

  const _AllocationChangeRow({
    required this.allocation,
    this.tradeGroup,
    this.expanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final delta = allocation.displayDelta;
    final deltaText = delta >= 0
        ? '(+${delta.toStringAsFixed(1)}%)'
        : '(${delta.toStringAsFixed(1)}%)';
    final deltaColor = delta > 0 ? tc.accent : WeRoboColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (tradeGroup != null && onToggle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Pressable(
                onTap: onToggle,
                child: Row(
                  children: [
                    Text(
                      expanded
                          ? '조정된 ${tradeGroup!.tradeCount}개 티커 숨기기'
                          : '조정된 ${tradeGroup!.tradeCount}개 티커 보기',
                      style: WeRoboTypography.caption.copyWith(
                        color: WeRoboColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: WeRoboColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (tradeGroup != null && expanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                children: tradeGroup!.trades
                    .map((trade) => _TradeDetailRow(trade: trade))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TradeDetailGroupRow extends StatelessWidget {
  final _InsightTradeGroup group;
  final bool expanded;
  final VoidCallback onToggle;

  const _TradeDetailGroupRow({
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: onToggle,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: group.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.assetName,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${group.tradeCount}개 티커',
                  style: WeRoboTypography.caption.copyWith(
                    color: tc.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: tc.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                children: group.trades
                    .map((trade) => _TradeDetailRow(trade: trade))
                    .toList(),
              ),
            ),
          ],
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
    final sideColor = trade.isBuy ? tc.accent : WeRoboColors.error;

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

class _InsightTradeGroup {
  final String assetCode;
  final String assetName;
  final Color color;
  final List<RebalanceInsightTrade> trades;

  const _InsightTradeGroup({
    required this.assetCode,
    required this.assetName,
    required this.color,
    required this.trades,
  });

  int get tradeCount => trades.length;
  double get totalAmount =>
      trades.fold(0.0, (sum, trade) => sum + trade.amount);
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
