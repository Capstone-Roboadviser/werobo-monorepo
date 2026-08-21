import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';

/// One of three drill-down period scopes the user can open from the
/// portfolio 리포트 list.
enum ReportPeriod {
  monthly,
  weekly,
  daily,
}

extension on ReportPeriod {
  String get koLabel => switch (this) {
        ReportPeriod.monthly => '월간 리포트',
        ReportPeriod.weekly => '주간 리포트',
        ReportPeriod.daily => '일간 리포트',
      };

  String get heroSubtitle => switch (this) {
        ReportPeriod.monthly => '내 포트폴리오의 월간 동향을 확인해 보세요.',
        ReportPeriod.weekly => '내 포트폴리오의 주간 동향을 확인해 보세요.',
        ReportPeriod.daily => '내 포트폴리오의 일간 동향을 확인해 보세요.',
      };

  String get periodicityLine => switch (this) {
        ReportPeriod.monthly => 'Monthly Report는 매월 초 제공됩니다.',
        ReportPeriod.weekly => 'Weekly Report는 매주 월요일 제공됩니다.',
        ReportPeriod.daily => 'Daily Report는 매일 장 마감 후 제공됩니다.',
      };

  /// English heading drawn in large bold type, matching the reference image
  /// ("Monthly Report" / "Weekly Report" / "Daily Report").
  String get heroEnglishLabel => switch (this) {
        ReportPeriod.monthly => 'Monthly Report',
        ReportPeriod.weekly => 'Weekly Report',
        ReportPeriod.daily => 'Daily Report',
      };
}

/// Drill-down page for one of 월간/주간/일간 리포트. Hero card shows the
/// current period's return-distribution bar chart with 하락종목/상승종목
/// counts, followed by a list of past periods with a slim distribution bar.
class PortfolioReportDetailPage extends StatelessWidget {
  final ReportPeriod period;

  const PortfolioReportDetailPage({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final now = DateTime.now();
    final reports = _buildReports(state, now, period);
    final featured = reports.isNotEmpty ? reports.first : null;
    final past = reports.length > 1 ? reports.sublist(1) : const <_Report>[];

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(period: period),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  _IntroBlock(period: period),
                  const SizedBox(height: 20),
                  if (featured != null)
                    _FeaturedReportCard(report: featured)
                  else
                    _EmptyFeaturedCard(period: period),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      period.periodicityLine,
                      style: WeRoboTypography.caption.copyWith(
                        color: WeRoboColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '지난 Report',
                      style: WeRoboTypography.heading2.themed(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (past.isEmpty)
                    _NoPastReportsCard(period: period)
                  else
                    for (int i = 0; i < past.length; i++) ...[
                      _PastReportCard(report: past[i]),
                      if (i != past.length - 1) const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ReportPeriod period;

  const _Header({required this.period});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
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
            period.koLabel,
            style: WeRoboTypography.heading2.themed(context),
          ),
        ],
      ),
    );
  }
}

class _IntroBlock extends StatelessWidget {
  final ReportPeriod period;

  const _IntroBlock({required this.period});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period.heroEnglishLabel,
            style: WeRoboTypography.heading1.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            period.heroSubtitle,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Featured card replicates the reference image: dark-navy panel with a
/// `[period] Report` headline, period range, then a centered bar chart
/// showing the distribution of returns within the period split into five
/// loss buckets (blue) and five gain buckets (red).
class _FeaturedReportCard extends StatelessWidget {
  final _Report report;

  const _FeaturedReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2233),
            Color(0xFF0D1422),
          ],
        ),
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.titleLine,
                      style: WeRoboTypography.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.rangeLine,
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const _ConfirmChip(),
            ],
          ),
          const SizedBox(height: 22),
          _DistributionChart(distribution: report.distribution),
          const SizedBox(height: 14),
          _CountsRow(distribution: report.distribution),
          const SizedBox(height: 16),
          Text(
            '※ 산출대상 : 내 포트폴리오 일간 수익률',
            style: WeRoboTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmChip extends StatelessWidget {
  const _ConfirmChip();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '확인하기',
          style: WeRoboTypography.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white,
          size: 18,
        ),
      ],
    );
  }
}

/// Five descending loss buckets on the left (in blue, smallest magnitude
/// closest to the divider), the zero bucket as a 1px spacer, and five
/// ascending gain buckets on the right (in red). Bar heights are normalized
/// to the largest count across both sides; counts annotate the top of each
/// bar.
class _DistributionChart extends StatelessWidget {
  final _ReturnDistribution distribution;

  const _DistributionChart({required this.distribution});

  @override
  Widget build(BuildContext context) {
    const labels = [
      '-10%~',
      '-10~-5%',
      '-5~-3%',
      '-3~-1%',
      '-1~0%',
      '0',
      '0~1%',
      '1~3%',
      '3~5%',
      '5~10%',
      '10%~',
    ];
    final counts = [
      ...distribution.lossBuckets,
      distribution.zeroBucket,
      ...distribution.gainBuckets,
    ];
    final maxCount =
        counts.fold<int>(0, (m, v) => v > m ? v : m).clamp(1, 1 << 30);

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < counts.length; i++)
                    _Bar(
                      width: w / counts.length,
                      count: counts[i],
                      maxCount: maxCount,
                      color: i < 5
                          ? WeRoboColors.lossBlue
                          : i == 5
                              ? Colors.white.withValues(alpha: 0.25)
                              : WeRoboColors.gainRed,
                      isZero: i == 5,
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: Row(
            children: [
              for (int i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: WeRoboTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final int count;
  final int maxCount;
  final Color color;
  final bool isZero;

  const _Bar({
    required this.width,
    required this.count,
    required this.maxCount,
    required this.color,
    required this.isZero,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = count / maxCount;
    final fullHeight = 100.0;
    final h = isZero
        ? 8.0
        : count == 0
            ? 4.0
            : math.max(8.0, ratio * fullHeight);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!isZero)
            Text(
              '$count',
              style: TextStyle(
                fontFamily: WeRoboFonts.number,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            )
          else
            Text(
              '$count',
              style: TextStyle(
                fontFamily: WeRoboFonts.number,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          const SizedBox(height: 2),
          Container(
            width: math.max(4, width - 6),
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountsRow extends StatelessWidget {
  final _ReturnDistribution distribution;

  const _CountsRow({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final lossTotal = distribution.lossBuckets.fold<int>(0, (a, b) => a + b);
    final gainTotal = distribution.gainBuckets.fold<int>(0, (a, b) => a + b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 14,
          color: WeRoboColors.lossBlue,
        ),
        const SizedBox(width: 8),
        Text(
          '하락종목',
          style: WeRoboTypography.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$lossTotal',
          style: TextStyle(
            fontFamily: WeRoboFonts.number,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: WeRoboColors.lossBlue,
          ),
        ),
        const Spacer(),
        Text(
          '$gainTotal',
          style: TextStyle(
            fontFamily: WeRoboFonts.number,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: WeRoboColors.gainRed,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '상승종목',
          style: WeRoboTypography.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 14,
          color: WeRoboColors.gainRed,
        ),
      ],
    );
  }
}

class _EmptyFeaturedCard extends StatelessWidget {
  final ReportPeriod period;

  const _EmptyFeaturedCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2233),
            Color(0xFF0D1422),
          ],
        ),
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period.heroEnglishLabel,
            style: WeRoboTypography.heading2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '집계할 데이터가 아직 충분하지 않아요.',
            style: WeRoboTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastReportCard extends StatelessWidget {
  final _Report report;

  const _PastReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final lossTotal =
        report.distribution.lossBuckets.fold<int>(0, (a, b) => a + b);
    final gainTotal =
        report.distribution.gainBuckets.fold<int>(0, (a, b) => a + b);
    final total = (lossTotal + gainTotal + report.distribution.zeroBucket)
        .clamp(1, 1 << 30);
    final lossPct = lossTotal / total;
    final gainPct = gainTotal / total;
    final neutralPct = 1.0 - lossPct - gainPct;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        border: Border.all(color: tc.border, width: 1),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.titleLine,
            style: WeRoboTypography.heading3.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '집계기간 : ${report.shortRangeLine}',
            style: WeRoboTypography.caption.copyWith(
              color: tc.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '하락',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '종목',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$lossTotal',
                    style: TextStyle(
                      fontFamily: WeRoboFonts.number,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WeRoboColors.lossBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (lossPct * 1000).round(),
                        child: Container(color: WeRoboColors.lossBlue),
                      ),
                      Expanded(
                        flex: (neutralPct * 1000).round().clamp(1, 1000),
                        child: Container(color: tc.border),
                      ),
                      Expanded(
                        flex: (gainPct * 1000).round(),
                        child: Container(color: WeRoboColors.gainRed),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '상승',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '종목',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$gainTotal',
                    style: TextStyle(
                      fontFamily: WeRoboFonts.number,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WeRoboColors.gainRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoPastReportsCard extends StatelessWidget {
  final ReportPeriod period;

  const _NoPastReportsCard({required this.period});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        border: Border.all(color: tc.border, width: 1),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Text(
        '아직 표시할 지난 리포트가 없어요.',
        style: WeRoboTypography.bodySmall.copyWith(
          color: tc.textTertiary,
        ),
      ),
    );
  }
}

// ─── Report computation ────────────────────────────────────────────────────

class _Report {
  final String titleLine;
  final String rangeLine;
  final String shortRangeLine;
  final _ReturnDistribution distribution;

  const _Report({
    required this.titleLine,
    required this.rangeLine,
    required this.shortRangeLine,
    required this.distribution,
  });
}

/// Counts of daily portfolio returns binned into five loss buckets (largest
/// magnitude first), a zero bucket, and five gain buckets (smallest first).
/// Order matches the bar layout in [_DistributionChart].
class _ReturnDistribution {
  /// `[<-10%, -10~-5%, -5~-3%, -3~-1%, -1~0%]`
  final List<int> lossBuckets;
  final int zeroBucket;

  /// `[0~1%, 1~3%, 3~5%, 5~10%, >10%]`
  final List<int> gainBuckets;

  const _ReturnDistribution({
    required this.lossBuckets,
    required this.zeroBucket,
    required this.gainBuckets,
  });

  factory _ReturnDistribution.fromReturns(Iterable<double> returns) {
    final loss = List<int>.filled(5, 0);
    int zero = 0;
    final gain = List<int>.filled(5, 0);
    for (final r in returns) {
      final pct = r * 100;
      if (pct < -10) {
        loss[0]++;
      } else if (pct < -5) {
        loss[1]++;
      } else if (pct < -3) {
        loss[2]++;
      } else if (pct < -1) {
        loss[3]++;
      } else if (pct < 0) {
        loss[4]++;
      } else if (pct == 0) {
        zero++;
      } else if (pct <= 1) {
        gain[0]++;
      } else if (pct <= 3) {
        gain[1]++;
      } else if (pct <= 5) {
        gain[2]++;
      } else if (pct <= 10) {
        gain[3]++;
      } else {
        gain[4]++;
      }
    }
    return _ReturnDistribution(
      lossBuckets: loss,
      zeroBucket: zero,
      gainBuckets: gain,
    );
  }
}

/// Builds the featured + past report list for the requested period. When
/// account history is empty (e.g., onboarding not finished), returns a
/// synthetic fixture sized to look populated — design preview parity with
/// the reference image.
List<_Report> _buildReports(
  PortfolioState state,
  DateTime now,
  ReportPeriod period,
) {
  final history = state.accountHistory;
  if (history.length < 2) {
    return _previewReports(now, period);
  }
  final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
  final dailyReturns = <DateTime, double>{};
  for (int i = 1; i < sorted.length; i++) {
    final prior = sorted[i - 1].portfolioValue;
    final curr = sorted[i].portfolioValue;
    if (prior <= 0) continue;
    final r = (curr / prior) - 1.0;
    dailyReturns[_dateOnly(sorted[i].date)] = r;
  }

  switch (period) {
    case ReportPeriod.monthly:
      return _byMonth(dailyReturns, now);
    case ReportPeriod.weekly:
      return _byWeek(dailyReturns, now);
    case ReportPeriod.daily:
      return _byDay(dailyReturns, now);
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

List<_Report> _byMonth(Map<DateTime, double> returns, DateTime now) {
  final byMonth = <String, List<MapEntry<DateTime, double>>>{};
  returns.forEach((date, r) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    byMonth.putIfAbsent(key, () => []).add(MapEntry(date, r));
  });
  final sortedKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
  return sortedKeys.map((key) {
    final entries = byMonth[key]!;
    entries.sort((a, b) => a.key.compareTo(b.key));
    final first = entries.first.key;
    final last = entries.last.key;
    return _Report(
      titleLine:
          '${first.year}.${first.month.toString().padLeft(2, '0')}월 Report',
      rangeLine: '${_fullDate(first)} ~ ${_fullDate(last)}',
      shortRangeLine: '${_shortDate(first)} ~ ${_shortDate(last)}',
      distribution:
          _ReturnDistribution.fromReturns(entries.map((e) => e.value)),
    );
  }).toList();
}

List<_Report> _byWeek(Map<DateTime, double> returns, DateTime now) {
  // ISO week: Monday-start
  final byWeek = <String, List<MapEntry<DateTime, double>>>{};
  returns.forEach((date, r) {
    final monday = _mondayOf(date);
    final key = '${monday.year}-${monday.month.toString().padLeft(2, '0')}'
        '-${monday.day.toString().padLeft(2, '0')}';
    byWeek.putIfAbsent(key, () => []).add(MapEntry(date, r));
  });
  final sortedKeys = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
  return sortedKeys.map((key) {
    final entries = byWeek[key]!;
    entries.sort((a, b) => a.key.compareTo(b.key));
    final first = entries.first.key;
    final last = entries.last.key;
    return _Report(
      titleLine: '${first.year}.${first.month.toString().padLeft(2, '0')}.'
          '${first.day.toString().padLeft(2, '0')} Report',
      rangeLine: '${_fullDate(first)} ~ ${_fullDate(last)}',
      shortRangeLine: '${_shortDate(first)} ~ ${_shortDate(last)}',
      distribution:
          _ReturnDistribution.fromReturns(entries.map((e) => e.value)),
    );
  }).toList();
}

List<_Report> _byDay(Map<DateTime, double> returns, DateTime now) {
  final sortedEntries = returns.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return sortedEntries.map((entry) {
    final d = entry.key;
    // For a single day, bucket the day's return into one of the eleven
    // buckets so the chart still draws something meaningful at the daily
    // grain. The single observation lands in exactly one bar.
    return _Report(
      titleLine: '${d.year}.${d.month.toString().padLeft(2, '0')}.'
          '${d.day.toString().padLeft(2, '0')} Report',
      rangeLine: _fullDate(d),
      shortRangeLine: _shortDate(d),
      distribution: _ReturnDistribution.fromReturns([entry.value]),
    );
  }).toList();
}

DateTime _mondayOf(DateTime d) {
  final delta = d.weekday - DateTime.monday;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: delta));
}

String _fullDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

String _shortDate(DateTime d) => '${(d.year % 100).toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.'
    '${d.day.toString().padLeft(2, '0')}';

/// Synthetic preview data so the page never renders as a blank shell in
/// debug builds or during onboarding. Matches the shape of the reference
/// image (large center bar, mixed positive distribution).
List<_Report> _previewReports(DateTime now, ReportPeriod period) {
  _Report mk(
    String title,
    DateTime start,
    DateTime end,
    List<int> loss,
    int zero,
    List<int> gain,
  ) =>
      _Report(
        titleLine: title,
        rangeLine: '${_fullDate(start)} ~ ${_fullDate(end)}',
        shortRangeLine: '${_shortDate(start)} ~ ${_shortDate(end)}',
        distribution: _ReturnDistribution(
          lossBuckets: loss,
          zeroBucket: zero,
          gainBuckets: gain,
        ),
      );

  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);
  final prevMonthStart = DateTime(now.year, now.month - 1, 1);
  final prevMonthEnd = DateTime(now.year, now.month, 0);
  final twoMonthsAgoStart = DateTime(now.year, now.month - 2, 1);
  final twoMonthsAgoEnd = DateTime(now.year, now.month - 1, 0);

  switch (period) {
    case ReportPeriod.monthly:
      return [
        mk(
          '${now.year}.${now.month.toString().padLeft(2, '0')}월 Report',
          monthStart,
          monthEnd,
          [50, 90, 116, 220, 132],
          5,
          [156, 121, 117, 209, 108],
        ),
        mk(
          '${prevMonthStart.year}.'
          '${prevMonthStart.month.toString().padLeft(2, '0')}월 Report',
          prevMonthStart,
          prevMonthEnd,
          [42, 84, 109, 198, 179],
          6,
          [148, 130, 122, 191, 119],
        ),
        mk(
          '${twoMonthsAgoStart.year}.'
          '${twoMonthsAgoStart.month.toString().padLeft(2, '0')}월 Report',
          twoMonthsAgoStart,
          twoMonthsAgoEnd,
          [36, 78, 114, 175, 192],
          7,
          [142, 138, 121, 184, 124],
        ),
      ];
    case ReportPeriod.weekly:
      final thisMonday = _mondayOf(now);
      final lastMonday = thisMonday.subtract(const Duration(days: 7));
      final twoMondayAgo = thisMonday.subtract(const Duration(days: 14));
      final thisSunday = thisMonday.add(const Duration(days: 6));
      final lastSunday = lastMonday.add(const Duration(days: 6));
      final twoSundayAgo = twoMondayAgo.add(const Duration(days: 6));
      return [
        mk(
          '${thisMonday.year}.'
          '${thisMonday.month.toString().padLeft(2, '0')}.'
          '${thisMonday.day.toString().padLeft(2, '0')} Report',
          thisMonday,
          thisSunday,
          [8, 18, 28, 52, 31],
          2,
          [38, 28, 26, 50, 24],
        ),
        mk(
          '${lastMonday.year}.'
          '${lastMonday.month.toString().padLeft(2, '0')}.'
          '${lastMonday.day.toString().padLeft(2, '0')} Report',
          lastMonday,
          lastSunday,
          [6, 14, 24, 48, 35],
          3,
          [34, 31, 22, 46, 26],
        ),
        mk(
          '${twoMondayAgo.year}.'
          '${twoMondayAgo.month.toString().padLeft(2, '0')}.'
          '${twoMondayAgo.day.toString().padLeft(2, '0')} Report',
          twoMondayAgo,
          twoSundayAgo,
          [5, 12, 22, 44, 39],
          2,
          [30, 29, 23, 43, 28],
        ),
      ];
    case ReportPeriod.daily:
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      return [
        mk(
          '${today.year}.${today.month.toString().padLeft(2, '0')}.'
          '${today.day.toString().padLeft(2, '0')} Report',
          today,
          today,
          [2, 3, 6, 9, 8],
          1,
          [11, 9, 7, 6, 4],
        ),
        mk(
          '${yesterday.year}.${yesterday.month.toString().padLeft(2, '0')}.'
          '${yesterday.day.toString().padLeft(2, '0')} Report',
          yesterday,
          yesterday,
          [1, 4, 7, 11, 7],
          1,
          [9, 11, 8, 5, 3],
        ),
        mk(
          '${twoDaysAgo.year}.${twoDaysAgo.month.toString().padLeft(2, '0')}.'
          '${twoDaysAgo.day.toString().padLeft(2, '0')} Report',
          twoDaysAgo,
          twoDaysAgo,
          [2, 4, 5, 10, 9],
          1,
          [10, 8, 7, 6, 4],
        ),
        mk(
          '${threeDaysAgo.year}.${threeDaysAgo.month.toString().padLeft(2, '0')}.'
          '${threeDaysAgo.day.toString().padLeft(2, '0')} Report',
          threeDaysAgo,
          threeDaysAgo,
          [3, 5, 6, 8, 6],
          1,
          [9, 9, 8, 7, 5],
        ),
      ];
  }
}
