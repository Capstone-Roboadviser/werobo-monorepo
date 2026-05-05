import 'dart:async';

import 'package:flutter/material.dart';
import '../../../app/theme.dart';

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
    this.height = 28,
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
    // Sort by AssetClass enum order, NOT by weight, so the leftmost
    // segment is always the most defensive class (cash).
    final ordered = [...widget.assets]
      ..sort((a, b) => a.cls.index.compareTo(b.cls.index));
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
                  // Center tooltip over the active segment.
                  double leftEdge = 0;
                  for (var i = 0; i < activeIndex!; i++) {
                    leftEdge += (ordered[i].weight / total) * width;
                  }
                  final segmentWidth =
                      (activeAsset.weight / total) * width;
                  final tooltipCenter = leftEdge + segmentWidth / 2;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: tooltipCenter,
                        top: 0,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WeRoboColors.primaryLight,
                              borderRadius: BorderRadius.circular(
                                  WeRoboColors.radiusS),
                            ),
                            child: Text(
                              '${activeAsset.label} $pct%',
                              style: WeRoboTypography.caption.copyWith(
                                color: tc.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tooltipRow,
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
