import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import 'widgets/digest_loading.dart';
import 'widgets/driver_card.dart';
import 'widgets/return_bar_chart.dart';

class DigestScreen extends StatefulWidget {
  const DigestScreen({super.key});

  @override
  State<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends State<DigestScreen> {
  MobileDigestResponse? _digest;
  String? _error;
  bool _loading = true;
  bool _fetchStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchStarted) {
      _fetchStarted = true;
      _fetchDigest();
    }
  }

  Future<void> _fetchDigest() async {
    final state = PortfolioStateProvider.of(context);
    final token = state.authSession?.accessToken;
    if (token == null) {
      setState(() {
        _error = '로그인이 필요합니다.';
        _loading = false;
      });
      return;
    }

    final alreadySeen = state.hasSeenCurrentDigest;

    try {
      if (alreadySeen) {
        // Skip loading animation for already-seen digests
        final result =
            await MobileBackendApi.instance.fetchDigest(accessToken: token);
        if (mounted) {
          setState(() {
            _digest = result;
            _loading = false;
          });
        }
      } else {
        // Show full loading animation for new digests
        const minDuration = Duration(milliseconds: 5500);
        final results = await Future.wait([
          MobileBackendApi.instance.fetchDigest(accessToken: token),
          Future<void>.delayed(minDuration),
        ]);
        if (mounted) {
          final result = results[0] as MobileDigestResponse;
          await state.markDigestSeen(result.digestDate);
          setState(() {
            _digest = result;
            _loading = false;
          });
        }
      }
    } on MobileBackendException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.statusCode == 422
              ? '주간 다이제스트를 만들기 위한 최근 데이터가 아직 부족합니다. '
                  '다음 가격 갱신 후 다시 확인해주세요.'
              : e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    logPageEnter('DigestScreen');
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tc.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '주간 다이제스트',
          style: WeRoboTypography.heading3.copyWith(
            color: tc.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const DigestLoading()
          : _error != null
              ? _ErrorState(message: _error!)
              : _digest != null
                  ? _DigestContent(digest: _digest!)
                  : const SizedBox.shrink(),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Center(
      child: Padding(
        padding: WeRoboSpacing.screenH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: tc.textTertiary,
            ),
            const SizedBox(height: WeRoboSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: WeRoboTypography.body.copyWith(
                color: tc.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestContent extends StatelessWidget {
  final MobileDigestResponse digest;
  const _DigestContent({required this.digest});

  @override
  Widget build(BuildContext context) {
    if (!digest.available) {
      return const _ErrorState(
        message: '이번 주에는 표시할 다이제스트가 없습니다.',
      );
    }
    final tc = WeRoboThemeColors.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      children: [
        // Date badge
        _DateBadge(start: digest.periodStart, end: digest.periodEnd),
        const SizedBox(height: WeRoboSpacing.lg),

        // Summary card
        _SummaryCard(digest: digest),
        const SizedBox(height: WeRoboSpacing.xl),

        // Asset return bar chart
        if (digest.drivers.isNotEmpty || digest.detractors.isNotEmpty) ...[
          ReturnBarChart(
            drivers: digest.drivers,
            detractors: digest.detractors,
          ),
          const SizedBox(height: WeRoboSpacing.xxl),
        ],

        // Drivers
        if (digest.drivers.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.arrow_drop_up,
            iconColor: tc.accent,
            title: '상승 기여 종목',
          ),
          const SizedBox(height: WeRoboSpacing.md),
          ...digest.drivers.map(
            (d) => DriverCard(driver: d, isPositive: true),
          ),
          const SizedBox(height: WeRoboSpacing.xl),
        ],

        // Detractors
        if (digest.detractors.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.arrow_drop_down,
            iconColor: WeRoboColors.error,
            title: '하락 기여 종목',
          ),
          const SizedBox(height: WeRoboSpacing.md),
          ...digest.detractors.map(
            (d) => DriverCard(driver: d, isPositive: false),
          ),
          const SizedBox(height: WeRoboSpacing.xl),
        ],

        // Disclaimer
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Text(
            digest.disclaimer,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textTertiary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String start;
  final String end;
  const _DateBadge({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_formatDate(start)} - ${_formatDate(end)}',
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month}월 ${d.day}일';
  }
}

class _SummaryCard extends StatelessWidget {
  final MobileDigestResponse digest;
  const _SummaryCard({required this.digest});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final isNegative = digest.totalReturnWon < 0;
    final returnColor = isNegative ? WeRoboColors.error : tc.accent;
    final sign = isNegative ? '' : '+';
    final wonStr = _formatWon(digest.totalReturnWon);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$sign$wonStr',
                style: WeRoboTypography.number.copyWith(
                  color: returnColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($sign${digest.totalReturnPct.toStringAsFixed(1)}%)',
                style: WeRoboTypography.body.copyWith(
                  color: returnColor,
                ),
              ),
            ],
          ),
          if (_volatilityContextText != null) ...[
            const SizedBox(height: 8),
            Text(
              _volatilityContextText!,
              style: WeRoboTypography.caption.copyWith(
                color: tc.textTertiary,
              ),
            ),
          ],
          if (digest.hasNarrative && digest.narrativeKo != null) ...[
            const SizedBox(height: 12),
            Text.rich(
              _buildNarrativeSpans(digest, tc),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                height: 1.7,
              ),
            ),
          ],
          if (digest.sourcesUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${digest.sourcesUsed.join(", ")} 기반 분석',
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _volatilityContextText {
    final multiple = digest.triggerSigmaMultiple;
    if (multiple == null) return null;
    return '최근 60영업일 기준, 평소보다 ${multiple.toStringAsFixed(1)}배 큰 움직임이에요.';
  }

  TextSpan _buildNarrativeSpans(
    MobileDigestResponse d,
    WeRoboThemeColors tc,
  ) {
    final narrative = _insertBenchmarkSentence(d);

    // Collect asset names to bold (tickers + Korean names)
    final names = <String>{};
    for (final driver in [...d.drivers, ...d.detractors]) {
      names.add(driver.ticker);
      if (driver.nameKo.isNotEmpty) names.add(driver.nameKo);
    }
    if (names.isEmpty) return TextSpan(text: narrative);

    // Build regex matching any asset name
    final escaped = names.map((n) => RegExp.escape(n)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(escaped.join('|'));

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in pattern.allMatches(narrative)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: narrative.substring(lastEnd, match.start),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < narrative.length) {
      spans.add(TextSpan(
        text: narrative.substring(lastEnd),
      ));
    }
    return TextSpan(children: spans);
  }

  String _insertBenchmarkSentence(MobileDigestResponse d) {
    final narrative = d.narrativeKo!;
    if (d.benchmark7assetReturnPct == null) return narrative;

    final asset7 = d.benchmark7assetReturnPct!;
    final excess7 = d.totalReturnPct - asset7;
    final sign7 = excess7 >= 0 ? '+' : '';
    final parts = <String>[
      '시장 대비 $sign7${excess7.toStringAsFixed(1)}%',
    ];
    if (d.benchmarkBondReturnPct != null) {
      final excessBond = d.totalReturnPct - d.benchmarkBondReturnPct!;
      final signBond = excessBond >= 0 ? '+' : '';
      parts.add(
        '채권 대비 $signBond${excessBond.toStringAsFixed(1)}%',
      );
    }
    final verb = excess7 >= 0 ? '초과 수익' : '하회';
    final benchmarkSentence = '${parts.join(", ")} $verb을 기록했습니다.';

    final dotIdx = narrative.indexOf('. ');
    if (dotIdx >= 0) {
      final first = narrative.substring(0, dotIdx + 1);
      final rest = narrative.substring(dotIdx + 1).trimLeft();
      return '$first $benchmarkSentence $rest';
    }
    return '$narrative $benchmarkSentence';
  }

  String _formatWon(double won) {
    final abs = won.abs().round();
    final formatted = abs.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return won < 0 ? '-₩$formatted' : '₩$formatted';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 4),
        Text(
          title,
          style: WeRoboTypography.heading3.copyWith(
            fontSize: 16,
            color: tc.textPrimary,
          ),
        ),
      ],
    );
  }
}
