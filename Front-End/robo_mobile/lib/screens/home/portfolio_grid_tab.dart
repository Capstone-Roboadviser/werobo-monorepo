import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'portfolio_comparison_page.dart';
import 'portfolio_report_page.dart';
import 'portfolio_weights_page.dart';

/// Portfolio tab root (UIUX 2026-05-20 spec). Top: weekly/daily digest with
/// asset-class icons. Below: 3-tile grid that drills into 리포트, 비중, 비교.
class PortfolioGridTab extends StatelessWidget {
  const PortfolioGridTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final weekly = state.topContributorOver30d;
    final daily = state.topContributorsOverDay(1).isEmpty
        ? null
        : state.topContributorsOverDay(1).first;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Text(
                '포트폴리오',
                style: WeRoboTypography.heading2.themed(context),
              ),
            ),
            const SizedBox(height: 16),
            _DigestSummaryCard(
              label: '주간 요약',
              entry: weekly,
              base: state.accountSummary?.currentValue,
            ),
            const SizedBox(height: 12),
            _DigestSummaryCard(
              label: '일간 요약',
              entry: daily,
              base: state.accountSummary?.currentValue,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _PortfolioTile(
                    label: '리포트',
                    icon: Icons.description_rounded,
                    color: tc.surface,
                    onTap: () => Navigator.push(
                      context,
                      WeRoboMotion.fadeRoute<void>(const PortfolioReportPage()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PortfolioTile(
                    label: '비중',
                    icon: Icons.pie_chart_rounded,
                    color: tc.surface,
                    onTap: () => Navigator.push(
                      context,
                      WeRoboMotion.fadeRoute<void>(const PortfolioWeightsPage()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PortfolioTile(
                    label: '비교',
                    icon: Icons.compare_arrows_rounded,
                    color: tc.surface,
                    onTap: () => Navigator.push(
                      context,
                      WeRoboMotion.fadeRoute<void>(
                          const PortfolioComparisonPage()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestSummaryCard extends StatelessWidget {
  final String label;
  final ContributionEntry? entry;
  final double? base;

  const _DigestSummaryCard({
    required this.label,
    required this.entry,
    required this.base,
  });

  String? get _iconAsset {
    final cls = entry?.cls;
    if (cls == null) return null;
    return switch (cls) {
      AssetClass.cash => 'assets/icons/asset_class/cash.png',
      AssetClass.shortBond => 'assets/icons/asset_class/short_bond.png',
      AssetClass.infraBond => 'assets/icons/asset_class/infra_bond.png',
      AssetClass.gold => 'assets/icons/asset_class/gold.png',
      AssetClass.usValue => 'assets/icons/asset_class/us_value.png',
      AssetClass.usGrowth => 'assets/icons/asset_class/us_growth.png',
      AssetClass.newGrowth => 'assets/icons/asset_class/new_growth.png',
    };
  }

  String _formatWon(int amount) {
    final abs = amount.abs();
    final formatted = abs.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final sign = amount >= 0 ? '+' : '-';
    return '$sign$formatted 원';
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final entry = this.entry;
    final base = this.base;
    final iconAsset = _iconAsset;
    final krwAmount = (entry != null && base != null)
        ? (entry.krwImpact * base).round()
        : null;
    final isGain = (krwAmount ?? 0) >= 0;
    final pillColor = isGain
        ? WeRoboColors.gainRed
        : WeRoboColors.lossBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          if (iconAsset != null)
            Image.asset(iconAsset, width: 24, height: 24)
          else
            const SizedBox(width: 24, height: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry?.label ?? '데이터 없음',
              style: WeRoboTypography.body.copyWith(
                color: entry == null ? tc.textTertiary : tc.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (krwAmount != null)
            Text(
              _formatWon(krwAmount),
              style: WeRoboTypography.body.copyWith(
                color: pillColor,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              '—',
              style: WeRoboTypography.body.copyWith(
                color: tc.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PortfolioTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
            border: Border.all(color: tc.border, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: WeRoboColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
