import 'dart:async';

import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Left-to-right order the asset weight bar follows. Matches the capstone
/// 2026-05-12 palette image (purple → blue → yellow → green → cyan →
/// pink → red), which puts gold before infraBond — different from the
/// AssetClass enum's defensive→aggressive ordering.
int _assetBarDisplayIndex(AssetClass cls) => switch (cls) {
      AssetClass.cash => 0,
      AssetClass.shortBond => 1,
      AssetClass.gold => 2,
      AssetClass.infraBond => 3,
      AssetClass.usValue => 4,
      AssetClass.usGrowth => 5,
      AssetClass.newGrowth => 6,
    };

/// One asset class with its current weight in a portfolio.
class AssetWeight {
  final AssetClass cls;
  final String label;       // e.g. "단기채권"
  final List<String> tickers; // e.g. ["BND", "AGG", "LQD"]
  final double weight;       // 0.0–1.0

  const AssetWeight({
    required this.cls,
    required this.label,
    required this.tickers,
    required this.weight,
  });
}

/// Stacked horizontal bar showing asset proportions.
/// Used by the efficient frontier (segments resize live as user drags).
/// Renders as a thin band (14px tall by default) with 저위험 / 고위험
/// labels above so the bar reads as a risk dimension.
/// Tapping or long-pressing a segment shows a small tooltip just above
/// the bar with the asset label + percentage; the tooltip auto-dismisses
/// after ~1.5s. Asset order follows AssetClass enum (defensive →
/// aggressive: cash on the left, 신성장주 on the right) so the visual
/// gradient maps to risk.
class AssetWeightBar extends StatefulWidget {
  final List<AssetWeight> assets;
  final double height;

  const AssetWeightBar({
    super.key,
    required this.assets,
    this.height = 14,
  });

  @override
  State<AssetWeightBar> createState() => _AssetWeightBarState();
}

class _AssetWeightBarState extends State<AssetWeightBar> {
  /// Index into the *ordered* segment list (cash → newGrowth).
  /// `null` hides the tooltip.
  int? _activeSegmentIndex;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _activate(int index) {
    _dismissTimer?.cancel();
    setState(() => _activeSegmentIndex = index);
    _dismissTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _activeSegmentIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Visual order from capstone 2026-05-12 palette: cash → shortBond →
    // gold → infraBond → usValue → usGrowth → newGrowth. Note this
    // diverges from AssetClass enum order (which keeps infraBond before
    // gold) by design.
    final ordered = [...widget.assets]
      ..sort((a, b) =>
          _assetBarDisplayIndex(a.cls).compareTo(_assetBarDisplayIndex(b.cls)));
    final total = ordered.fold<double>(0, (s, a) => s + a.weight);
    if (total <= 0) {
      return SizedBox(height: widget.height);
    }

    final tc = WeRoboThemeColors.of(context);
    final activeIndex = _activeSegmentIndex;
    final activeAsset = (activeIndex != null &&
            activeIndex >= 0 &&
            activeIndex < ordered.length)
        ? ordered[activeIndex]
        : null;

    // Tooltip rendered above the bar in the same widget so it
    // participates in layout cleanly (no Overlay needed).
    final tooltipRow = SizedBox(
      height: 22,
      child: AnimatedSwitcher(
        duration: WeRoboMotion.short,
        switchInCurve: WeRoboMotion.move,
        switchOutCurve: WeRoboMotion.move,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: activeAsset == null
            ? const SizedBox.shrink()
            : LayoutBuilder(
                key: ValueKey(activeAsset.cls),
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final pct =
                      (activeAsset.weight * 100).toStringAsFixed(2);
                  final text = '${activeAsset.label} $pct%';
                  final textStyle = WeRoboTypography.caption.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w500,
                  );
                  // Measure rendered text width so the tooltip can be
                  // clamped within the bar at both edges. Without this,
                  // a tooltip over a right-end segment runs past the
                  // right edge of the screen.
                  const horizontalPadding = 6.0;
                  final textPainter = TextPainter(
                    text: TextSpan(text: text, style: textStyle),
                    textDirection: TextDirection.ltr,
                  )..layout();
                  final tooltipWidth =
                      textPainter.width + horizontalPadding * 2;
                  double leftEdge = 0;
                  for (var i = 0; i < activeIndex!; i++) {
                    leftEdge += (ordered[i].weight / total) * width;
                  }
                  final segmentWidth =
                      (activeAsset.weight / total) * width;
                  final tooltipCenter = leftEdge + segmentWidth / 2;
                  final maxLeft = (width - tooltipWidth)
                      .clamp(0.0, double.infinity);
                  final clampedLeft = (tooltipCenter - tooltipWidth / 2)
                      .clamp(0.0, maxLeft);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: clampedLeft,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tc.surface,
                            borderRadius: BorderRadius.circular(
                                WeRoboColors.radiusS),
                            border: Border.all(
                                color: tc.border, width: 0.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(text, style: textStyle),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );

    final endLabelStyle = WeRoboTypography.caption.copyWith(
      color: tc.textSecondary,
    );
    final endLabels = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('저위험', style: endLabelStyle),
        Text('고위험', style: endLabelStyle),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tooltipRow,
        endLabels,
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
          child: AnimatedSize(
            duration: WeRoboMotion.short,
            curve: WeRoboMotion.move,
            child: SizedBox(
              height: widget.height,
              child: Row(
                children: [
                  for (var i = 0; i < ordered.length; i++)
                    Expanded(
                      flex: ((ordered[i].weight / total) * 1000)
                          .round()
                          .clamp(1, 1000000),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _activate(i),
                        onLongPressStart: (_) => _activate(i),
                        child: AnimatedContainer(
                          duration: WeRoboMotion.short,
                          decoration: BoxDecoration(
                            color: WeRoboColors.assetColor(ordered[i].cls),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical list view (name + tickers + animated %) — used by the
/// portfolio review screen, not the frontier. Defined here to share the
/// AssetWeight model and asset color lookup.
class AssetWeightList extends StatelessWidget {
  final List<AssetWeight> assets;
  final bool compact;

  const AssetWeightList({
    super.key,
    required this.assets,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final sorted = [...assets]..sort((a, b) => b.weight.compareTo(a.weight));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in sorted) _AssetRow(asset: a, tc: tc, compact: compact),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  final AssetWeight asset;
  final WeRoboThemeColors tc;
  final bool compact;

  const _AssetRow({required this.asset, required this.tc, required this.compact});

  @override
  Widget build(BuildContext context) {
    final color = WeRoboColors.assetColor(asset.cls);
    final pct = (asset.weight * 100).toStringAsFixed(2);
    final padding = compact
        ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8)
        : const EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.label, style: WeRoboTypography.bodySmall.themed(context)
                    .copyWith(color: tc.textPrimary, fontWeight: FontWeight.w600)),
                if (asset.tickers.isNotEmpty)
                  Text(
                    asset.tickers.join(', '),
                    style: WeRoboTypography.caption.themed(context),
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: WeRoboMotion.short,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              '$pct%',
              key: ValueKey(pct),
              style: WeRoboTypography.bodySmall.copyWith(
                fontFamily: WeRoboFonts.number,
                fontWeight: FontWeight.w500,
                color: tc.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
