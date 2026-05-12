import 'package:flutter/material.dart';

import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';

const Color _gainColor = Color(0xFFE5455F);
const Color _lossColor = Color(0xFF3182F6);

class RangeDigestDetailPage extends StatelessWidget {
  final MobileRangeDigestResponse digest;

  const RangeDigestDetailPage({
    super.key,
    required this.digest,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final hasNews = digest.referenceNews.isNotEmpty;
    final hasContributions =
        digest.drivers.isNotEmpty || digest.detractors.isNotEmpty;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Row(
              children: [
                Pressable(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 22,
                    color: tc.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '구간 분석',
                  style: WeRoboTypography.body.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 22),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              _periodLabel(digest.periodStart, digest.periodEnd),
              style: WeRoboTypography.caption.copyWith(
                color: tc.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _headline(digest.totalReturnPct),
              style: WeRoboTypography.heading1.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _signedWonSentence(digest.totalReturnWon),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            _DetailSection(
              title: '왜 움직였을까?',
              child: Text(
                _narrativeText(digest),
                style: WeRoboTypography.body.copyWith(
                  color: tc.textPrimary,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasContributions) ...[
              const SizedBox(height: 24),
              _DetailSection(
                title: '주요 기여',
                child: Column(
                  children: [
                    for (final driver in digest.drivers)
                      _ContributionRow(driver: driver),
                    for (final driver in digest.detractors)
                      _ContributionRow(driver: driver),
                  ],
                ),
              ),
            ],
            if (hasNews) ...[
              const SizedBox(height: 24),
              _DetailSection(
                title: '참고 뉴스',
                trailing: digest.sourcesUsed.isEmpty
                    ? null
                    : digest.sourcesUsed.take(2).join(' · '),
                child: Column(
                  children: [
                    for (final item in digest.referenceNews)
                      _ReferenceNewsRow(item: item),
                  ],
                ),
              ),
            ],
            if (digest.disclaimer.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                digest.disclaimer,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _headline(double pct) {
    final signedPct = _formatSignedPercent(pct);
    if (pct > 0.1) return '선택 구간 $signedPct 상승';
    if (pct < -0.1) return '선택 구간 $signedPct 하락';
    return '선택 구간 변화 작음';
  }

  static String _narrativeText(MobileRangeDigestResponse digest) {
    final narrative = digest.narrativeKo?.trim();
    if (digest.hasNarrative && narrative != null && narrative.isNotEmpty) {
      return narrative;
    }
    if (digest.drivers.isEmpty && digest.detractors.isEmpty) {
      return '선택한 구간에서 뚜렷한 기여 요인이 확인되지 않았어요.';
    }
    final top = [...digest.drivers, ...digest.detractors]..sort(
        (a, b) => b.contributionWon.abs().compareTo(a.contributionWon.abs()),
      );
    final driver = top.first;
    final name = driver.nameKo.isNotEmpty ? driver.nameKo : driver.ticker;
    return '$name 영향이 가장 크게 잡혔어요.';
  }

  static String _signedWonSentence(double amount) {
    final won = _formatSignedWon(amount);
    return amount >= 0 ? '이 구간에서 $won 움직였어요.' : '이 구간에서 $won 영향을 받았어요.';
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _DetailSection({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: WeRoboTypography.heading3.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(
                trailing!,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final DigestDriver driver;

  const _ContributionRow({required this.driver});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final isGain = driver.contributionWon >= 0;
    final color = isGain ? _gainColor : _lossColor;
    final name = driver.nameKo.isNotEmpty ? driver.nameKo : driver.ticker;
    final explanation = driver.explanationKo?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatSignedWon(driver.contributionWon),
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (explanation != null && explanation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    explanation,
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceNewsRow extends StatelessWidget {
  final RangeDigestNewsItem item;

  const _ReferenceNewsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
            ),
            child: Text(
              item.ticker,
              style: WeRoboTypography.caption.copyWith(
                color: WeRoboColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _periodLabel(String startRaw, String endRaw) {
  final start = DateTime.tryParse(startRaw);
  final end = DateTime.tryParse(endRaw);
  if (start == null || end == null) return '선택 구간';
  return '${start.month}월 ${start.day}일 - ${end.month}월 ${end.day}일';
}

String _formatCurrency(int amount) {
  final str = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

String _formatSignedWon(double amount) {
  final sign = amount >= 0 ? '+' : '-';
  return '$sign₩${_formatCurrency(amount.abs().round())}';
}

String _formatSignedPercent(double percentage) {
  final sign = percentage >= 0 ? '+' : '-';
  return '$sign${percentage.abs().toStringAsFixed(1)}%';
}
