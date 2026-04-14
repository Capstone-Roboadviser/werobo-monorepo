import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

class ReturnBarChart extends StatelessWidget {
  final List<DigestDriver> drivers;
  final List<DigestDriver> detractors;

  const ReturnBarChart({
    super.key,
    required this.drivers,
    required this.detractors,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildSortedItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final tc = WeRoboThemeColors.of(context);
    final maxAbs = items
        .map((e) => e.returnPct.abs())
        .reduce(math.max);
    if (maxAbs == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const maxBarWidth = 48.0;
        final barWidth = math.min(
          maxBarWidth,
          (constraints.maxWidth - (items.length - 1) * gap) /
              items.length,
        );

        return Column(
          children: [
            _BarArea(
              items: items,
              maxAbs: maxAbs,
              barWidth: barWidth,
              gap: gap,
              tc: tc,
            ),
            const SizedBox(height: 6),
            _TickerLabels(
              items: items,
              barWidth: barWidth,
              gap: gap,
              tc: tc,
            ),
          ],
        );
      },
    );
  }

  List<DigestDriver> _buildSortedItems() {
    final pos = List<DigestDriver>.from(drivers)
      ..sort((a, b) => b.returnPct.compareTo(a.returnPct));
    final neg = List<DigestDriver>.from(detractors)
      ..sort((a, b) => b.returnPct.compareTo(a.returnPct));
    return [...pos, ...neg];
  }
}

class _BarArea extends StatelessWidget {
  final List<DigestDriver> items;
  final double maxAbs;
  final double barWidth;
  final double gap;
  final WeRoboThemeColors tc;

  const _BarArea({
    required this.items,
    required this.maxAbs,
    required this.barWidth,
    required this.gap,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 80.0;
    const labelHeight = 18.0;
    final posItems = items.where((d) => d.returnPct > 0);
    final negItems = items.where((d) => d.returnPct < 0);
    final hasPos = posItems.isNotEmpty;
    final hasNeg = negItems.isNotEmpty;

    // Scale each zone to its own max, not the global max
    final maxPos = hasPos
        ? posItems.map((d) => d.returnPct).reduce(math.max)
        : 0.0;
    final maxNeg = hasNeg
        ? negItems.map((d) => d.returnPct.abs()).reduce(math.max)
        : 0.0;
    final posZoneHeight = hasPos
        ? (maxPos / maxAbs) * maxBarHeight + labelHeight
        : 0.0;
    final negZoneHeight = hasNeg
        ? (maxNeg / maxAbs) * maxBarHeight + labelHeight
        : 0.0;

    return SizedBox(
      height: posZoneHeight + 1 + negZoneHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            _SingleBar(
              driver: items[i],
              maxAbs: maxAbs,
              barWidth: barWidth,
              maxBarHeight: maxBarHeight,
              labelHeight: labelHeight,
              posZoneHeight: posZoneHeight,
              negZoneHeight: negZoneHeight,
              tc: tc,
            ),
          ],
        ],
      ),
    );
  }
}

class _SingleBar extends StatelessWidget {
  final DigestDriver driver;
  final double maxAbs;
  final double barWidth;
  final double maxBarHeight;
  final double labelHeight;
  final double posZoneHeight;
  final double negZoneHeight;
  final WeRoboThemeColors tc;

  const _SingleBar({
    required this.driver,
    required this.maxAbs,
    required this.barWidth,
    required this.maxBarHeight,
    required this.labelHeight,
    required this.posZoneHeight,
    required this.negZoneHeight,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = driver.returnPct >= 0;
    final barColor =
        isPositive ? tc.accent : WeRoboColors.error;
    final ratio = driver.returnPct.abs() / maxAbs;
    final barHeight = math.max(4.0, ratio * maxBarHeight);
    final sign = isPositive ? '+' : '';
    final label = '$sign${driver.returnPct.toStringAsFixed(1)}%';

    final labelWidget = SizedBox(
      height: labelHeight,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: WeRoboFonts.number,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: barColor,
          ),
        ),
      ),
    );

    final barWidget = Container(
      width: barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: isPositive
            ? const BorderRadius.vertical(
                top: Radius.circular(4))
            : const BorderRadius.vertical(
                bottom: Radius.circular(4)),
      ),
    );

    return SizedBox(
      width: barWidth,
      height: posZoneHeight + 1 + negZoneHeight,
      child: Column(
        children: [
          // Positive zone
          if (posZoneHeight > 0)
            SizedBox(
              height: posZoneHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: isPositive
                    ? [labelWidget, barWidget]
                    : [const Spacer()],
              ),
            ),
          // Baseline
          Container(
            height: 1,
            width: barWidth,
            color: tc.border.withValues(alpha: 0.3),
          ),
          // Negative zone
          if (negZoneHeight > 0)
            SizedBox(
              height: negZoneHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: !isPositive
                    ? [barWidget, labelWidget]
                    : [const Spacer()],
              ),
            ),
        ],
      ),
    );
  }
}

class _TickerLabels extends StatelessWidget {
  final List<DigestDriver> items;
  final double barWidth;
  final double gap;
  final WeRoboThemeColors tc;

  const _TickerLabels({
    required this.items,
    required this.barWidth,
    required this.gap,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          SizedBox(
            width: barWidth,
            child: Text(
              items[i].nameKo.length > 4
                  ? items[i].ticker
                  : items[i].nameKo,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WeRoboTypography.caption.copyWith(
                color: tc.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
