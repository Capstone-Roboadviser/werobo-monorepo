import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import 'widgets/digest_loading.dart';
import 'widgets/driver_card.dart';

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
        final result = await MobileBackendApi.instance
            .fetchDigest(accessToken: token);
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
          MobileBackendApi.instance
              .fetchDigest(accessToken: token),
          Future<void>.delayed(minDuration),
        ]);
        if (mounted) {
          final result =
              results[0] as MobileDigestResponse;
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
          _error = e.message;
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
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
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
          color: tc.card,
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
    final returnColor =
        isNegative ? WeRoboColors.error : tc.accent;
    final sign = isNegative ? '' : '+';
    final wonStr = _formatWon(digest.totalReturnWon);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.card,
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
          if (digest.drivers.isNotEmpty ||
              digest.detractors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ContributionBar(
              drivers: digest.drivers,
              detractors: digest.detractors,
            ),
          ],
          if (digest.hasNarrative && digest.narrativeKo != null) ...[
            const SizedBox(height: 12),
            Text(
              digest.narrativeKo!,
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                height: 1.7,
              ),
            ),
          ],
          if (digest.sourcesUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tc.background,
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

  String _formatWon(double won) {
    final abs = won.abs().round();
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return won < 0 ? '-₩$formatted' : '₩$formatted';
  }
}

class _ContributionBar extends StatelessWidget {
  final List<DigestDriver> drivers;
  final List<DigestDriver> detractors;
  const _ContributionBar({
    required this.drivers,
    required this.detractors,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final posSum = drivers.fold<double>(
        0, (s, d) => s + d.contributionWon.abs());
    final negSum = detractors.fold<double>(
        0, (s, d) => s + d.contributionWon.abs());
    final total = posSum + negSum;
    if (total == 0) return const SizedBox.shrink();
    final posFrac = posSum / total;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Flexible(
                  flex: (posFrac * 1000).round(),
                  child: Container(color: tc.accent),
                ),
                if (posFrac < 1) const SizedBox(width: 2),
                Flexible(
                  flex: ((1 - posFrac) * 1000).round(),
                  child:
                      Container(color: WeRoboColors.error),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '상승 ${drivers.length}종목',
              style: WeRoboTypography.caption.copyWith(
                color: tc.accent,
              ),
            ),
            Text(
              '하락 ${detractors.length}종목',
              style: WeRoboTypography.caption.copyWith(
                color: WeRoboColors.error,
              ),
            ),
          ],
        ),
      ],
    );
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
