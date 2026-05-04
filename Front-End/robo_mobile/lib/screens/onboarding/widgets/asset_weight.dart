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
/// No percentage labels — bar segments communicate proportion visually.
/// Asset order follows AssetClass enum (defensive → aggressive: cash on
/// the left, 신성장주 on the right) so the visual gradient maps to risk.
class AssetWeightBar extends StatelessWidget {
  final List<AssetWeight> assets;
  final double height;

  const AssetWeightBar({
    super.key,
    required this.assets,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by AssetClass enum order, NOT by weight, so the leftmost
    // segment is always the most defensive class (cash).
    final ordered = [...assets]
      ..sort((a, b) => a.cls.index.compareTo(b.cls.index));
    final total = ordered.fold<double>(0, (s, a) => s + a.weight);
    if (total <= 0) {
      return SizedBox(height: height);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
      child: AnimatedSize(
        duration: WeRoboMotion.short,
        curve: WeRoboMotion.move,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final a in ordered)
                Expanded(
                  flex: ((a.weight / total) * 1000).round().clamp(1, 1000000),
                  child: AnimatedContainer(
                    duration: WeRoboMotion.short,
                    decoration: BoxDecoration(
                      color: WeRoboColors.assetColor(a.cls),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
