import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'portfolio_comparison_page.dart';
import 'portfolio_report_page.dart';
import 'portfolio_weights_page.dart';

/// Portfolio tab root (UIUX 2026-05-20 spec). One prominent 리포트 card on
/// top with weekly/daily summary buttons inside, plus a row of 비중 + 비교
/// tiles below.
class PortfolioGridTab extends StatelessWidget {
  const PortfolioGridTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final weekly = state.topContributorOver30d;
    final dailyList = state.topContributorsOverDay(1);
    final daily = dailyList.isEmpty ? null : dailyList.first;
    final base = state.accountSummary?.currentValue;

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
            _ReportCard(
              weekly: weekly,
              daily: daily,
              base: base,
              onOpen: () => Navigator.push(
                context,
                WeRoboMotion.fadeRoute<void>(const PortfolioReportPage()),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PortfolioTile(
                    label: '비중',
                    icon: Icons.pie_chart_rounded,
                    color: tc.surface,
                    onTap: () => Navigator.push(
                      context,
                      WeRoboMotion.fadeRoute<void>(
                          const PortfolioWeightsPage()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PortfolioTile(
                    label: '비교',
                    icon: Icons.balance_rounded,
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

/// Primary-colored card on top of the portfolio grid. Holds the 리포트 entry
/// point plus 주간 요약 / 일간 요약 pills that show the top contributor's
/// icon + signed amount for each timeframe.
class _ReportCard extends StatelessWidget {
  final ContributionEntry? weekly;
  final ContributionEntry? daily;
  final double? base;
  final VoidCallback onOpen;

  const _ReportCard({
    required this.weekly,
    required this.daily,
    required this.base,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final pillColor = Colors.white.withValues(alpha: 0.18);
    return Pressable(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: WeRoboColors.primary,
          borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
          boxShadow: WeRoboElevation.raised(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.description_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '포트폴리오 리포트',
                    style: WeRoboTypography.heading3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReportPill(
                    label: '주간 요약',
                    entry: weekly,
                    base: base,
                    color: pillColor,
                    onTap: onOpen,
                  ),
                  const SizedBox(height: 8),
                  _ReportPill(
                    label: '일간 요약',
                    entry: daily,
                    base: base,
                    color: pillColor,
                    onTap: onOpen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPill extends StatelessWidget {
  final String label;
  final ContributionEntry? entry;
  final double? base;
  final Color color;
  final VoidCallback onTap;
  const _ReportPill({
    required this.label,
    required this.entry,
    required this.base,
    required this.color,
    required this.onTap,
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

  String? _amountText() {
    final entry = this.entry;
    final base = this.base;
    if (entry == null || base == null) return null;
    final amount = (entry.krwImpact * base).round();
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
    final iconAsset = _iconAsset;
    final amount = _amountText();
    final cls = entry?.cls;
    final circleColor = cls == null
        ? Colors.white.withValues(alpha: 0.25)
        : WeRoboColors.assetColor(cls);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: WeRoboTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: iconAsset != null
                  ? Image.asset(iconAsset, width: 18, height: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              amount ?? '—',
              style: WeRoboTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
            boxShadow: WeRoboElevation.card(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: WeRoboColors.primary),
              const SizedBox(height: 10),
              Text(
                label,
                style: WeRoboTypography.body.copyWith(
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
