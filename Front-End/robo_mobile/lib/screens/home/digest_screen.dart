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
    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      appBar: AppBar(
        backgroundColor: WeRoboColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WeRoboColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '주간 다이제스트',
          style: WeRoboTypography.heading3.copyWith(
            color: WeRoboColors.textPrimary,
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
    return Center(
      child: Padding(
        padding: WeRoboSpacing.screenH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: WeRoboColors.textTertiary,
            ),
            const SizedBox(height: WeRoboSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: WeRoboTypography.body.copyWith(
                color: WeRoboColors.textSecondary,
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
            iconColor: WeRoboColors.accent,
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
            iconColor: WeRoboColors.textSecondary,
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
              color: WeRoboColors.textTertiary,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: WeRoboColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_formatDate(start)} - ${_formatDate(end)}',
          style: WeRoboTypography.caption.copyWith(
            color: WeRoboColors.textSecondary,
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
    final isNegative = digest.totalReturnWon < 0;
    final returnColor = WeRoboColors.textSecondary;
    final sign = isNegative ? '' : '+';
    final wonStr = _formatWon(digest.totalReturnWon);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WeRoboColors.surface,
        border: Border.all(color: WeRoboColors.card, width: 1.5),
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
          if (digest.hasNarrative && digest.narrativeKo != null) ...[
            const SizedBox(height: 12),
            Text(
              digest.narrativeKo!,
              style: WeRoboTypography.bodySmall.copyWith(
                color: WeRoboColors.textPrimary,
                height: 1.7,
              ),
            ),
          ],
          if (digest.sourcesUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: WeRoboColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${digest.sourcesUsed.join(", ")} 기반 분석',
                style: WeRoboTypography.caption.copyWith(
                  color: WeRoboColors.textTertiary,
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
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 4),
        Text(
          title,
          style: WeRoboTypography.heading3.copyWith(
            fontSize: 16,
            color: WeRoboColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
