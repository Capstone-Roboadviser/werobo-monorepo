import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import 'portfolio_report_detail_page.dart';

/// 리포트 sub-screen — three drill-down sections (월간/주간/일간) summarising
/// portfolio activity. Tapping a section opens the matching detail page
/// with return-distribution chart and past-period archive.
class PortfolioReportPage extends StatelessWidget {
  const PortfolioReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final monthReturn = state.trailingMonthReturn;
    final dailyReturn = state.dailyReturn;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '리포트',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _ReportSection(
                    label: '월간 리포트',
                    returnPct: monthReturn,
                    onTap: () => _openDetail(context, ReportPeriod.monthly),
                  ),
                  const SizedBox(height: 12),
                  _ReportSection(
                    label: '주간 리포트',
                    returnPct: null,
                    onTap: () => _openDetail(context, ReportPeriod.weekly),
                  ),
                  const SizedBox(height: 12),
                  _ReportSection(
                    label: '일간 리포트',
                    returnPct: dailyReturn,
                    onTap: () => _openDetail(context, ReportPeriod.daily),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, ReportPeriod period) {
    Navigator.push(
      context,
      WeRoboMotion.fadeRoute<void>(
        PortfolioReportDetailPage(period: period),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String label;
  final double? returnPct;
  final VoidCallback onTap;

  const _ReportSection({
    required this.label,
    required this.returnPct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final pct = returnPct;
    final hasPct = pct != null;
    final isGain = hasPct && pct >= 0;
    final color = isGain ? WeRoboColors.gainRed : WeRoboColors.lossBlue;
    final text = hasPct
        ? '${isGain ? '+' : '-'}${(pct.abs() * 100).toStringAsFixed(2)}%'
        : '—';
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
          border: Border.all(color: tc.border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: WeRoboTypography.heading3.copyWith(
                  color: tc.textPrimary,
                ),
              ),
            ),
            Text(
              text,
              style: WeRoboTypography.body.copyWith(
                color: hasPct ? color : tc.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
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
