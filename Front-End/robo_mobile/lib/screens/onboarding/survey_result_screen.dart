import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/investor_profile.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import 'portfolio_design_screen.dart';
import 'survey_flow_screen.dart';
import 'widgets/risk_level_scale.dart';

String _pct(double f) => (f * 100).round().toString();

/// 투자 적합성 판정 결과. Shows the computed [InvestorProfile], persists it on
/// confirm, fetches the profile-tailored efficient frontier, then routes
/// straight to [PortfolioDesignScreen]: the single chart step before home.
class SurveyResultScreen extends StatefulWidget {
  final InvestorProfile profile;
  final Future<MobileFrontierPreviewResponse> Function({
    required double propensityScore,
    required int samplePoints,
  })? fetchFrontierPreview;

  const SurveyResultScreen({
    super.key,
    required this.profile,
    this.fetchFrontierPreview,
  });

  @override
  State<SurveyResultScreen> createState() => _SurveyResultScreenState();
}

class _SurveyResultScreenState extends State<SurveyResultScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    logPageEnter('SurveyResultScreen');
  }

  @override
  void dispose() {
    logPageExit('SurveyResultScreen');
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    logAction('survey result confirm', {'level': widget.profile.level.name});
    final state = PortfolioStateProvider.of(context);
    final navigator = Navigator.of(context);
    setState(() => _starting = true);
    await state.setInvestorProfile(widget.profile);
    // Fetch the profile-tailored efficient frontier so the design screen
    // opens on real data instead of its synthetic fallback curve.
    try {
      final fetcher = widget.fetchFrontierPreview ??
          ({
            required double propensityScore,
            required int samplePoints,
          }) =>
              MobileBackendApi.instance.fetchFrontierPreview(
                propensityScore: propensityScore,
                samplePoints: samplePoints,
              );
      final preview = await fetcher(
        propensityScore: widget.profile.propensityScore,
        samplePoints: 301,
      );
      state.setFrontierPreview(preview);
    } catch (_) {
      // Network/parse failure: PortfolioDesignScreen renders its fallback.
    }
    if (!mounted) return;
    navigator.pushReplacement(
      WeRoboMotion.fadeRoute(const PortfolioDesignScreen()),
    );
  }

  void _retake() {
    logAction('survey retake');
    Navigator.of(context).pushReplacement(
      WeRoboMotion.fadeRoute(const SurveyFlowScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final p = widget.profile;
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  WeRoboSpacing.xxl,
                  WeRoboSpacing.xxxl,
                  WeRoboSpacing.xxl,
                  WeRoboSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '투자자 적합성 판정 결과',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: WeRoboColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: WeRoboSpacing.sm),
                    Text(
                      '고객님은\n${p.level.label}형 투자자예요',
                      style: WeRoboTypography.heading1.themed(context),
                    ),
                    const SizedBox(height: WeRoboSpacing.md),
                    Text(
                      '분석 결과에 따라 추천 포트폴리오 범위를 정했어요.',
                      style: WeRoboTypography.body.themed(context),
                    ),
                    const SizedBox(height: WeRoboSpacing.xxl),
                    _LevelCard(profile: p),
                    const SizedBox(height: WeRoboSpacing.lg),
                    _RangeCard(profile: p),
                    const SizedBox(height: WeRoboSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: _retake,
                        child: Text(
                          '이 결과가 마음에 들지 않아요',
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: tc.textTertiary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: WeRoboSpacing.bottomButton,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _starting ? null : _start,
                  child: _starting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: WeRoboColors.white,
                          ),
                        )
                      : const Text('내 포트폴리오 설계 시작하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final InvestorProfile profile;
  const _LevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final level = profile.level;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WeRoboSpacing.xl),
      decoration: BoxDecoration(
        color: WeRoboColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WeRoboColors.white,
                  borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
                ),
                child: const Text('🌱', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: WeRoboSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '레벨 ${level.number} / 5',
                    style: WeRoboTypography.caption
                        .copyWith(color: tc.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(level.label,
                      style: WeRoboTypography.heading3.themed(context)),
                ],
              ),
            ],
          ),
          const SizedBox(height: WeRoboSpacing.lg),
          RiskLevelScale(active: level),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  final InvestorProfile profile;
  const _RangeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final p = profile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WeRoboSpacing.xl),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추천 투자 범위',
            style: WeRoboTypography.bodySmall
                .copyWith(color: tc.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: WeRoboSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기대 연수익률',
                      style: WeRoboTypography.caption
                          .copyWith(color: tc.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${_pct(p.expectedReturnMin)}% ~ ${_pct(p.expectedReturnMax)}%',
                    style: WeRoboTypography.number
                        .copyWith(color: WeRoboColors.primary, fontSize: 22),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('최대 리스크',
                      style: WeRoboTypography.caption
                          .copyWith(color: tc.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '±${_pct(p.maxRisk)}%',
                    style: WeRoboTypography.number
                        .copyWith(color: tc.textPrimary, fontSize: 22),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: WeRoboSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(WeRoboSpacing.md),
            decoration: BoxDecoration(
              color: tc.background,
              borderRadius: BorderRadius.circular(WeRoboColors.radiusM),
            ),
            child: Text(
              '이 범위 안에서 AI가 최적의 포트폴리오를 제안합니다.\n물론, 더 좁히거나 직접 조정할 수 있어요.',
              style: WeRoboTypography.caption.copyWith(color: tc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
