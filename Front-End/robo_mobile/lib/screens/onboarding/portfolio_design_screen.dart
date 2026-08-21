import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import 'onboarding_screen.dart' show OnboardingFrontierSelection;
import 'portfolio_market_comparison_screen.dart';
import 'widgets/risk_return_frontier_chart.dart';

/// Disabled-CTA / out-of-range gray used by the design.
const Color _kMutedGray = Color(0xFF7F7F7F);

/// "기대수익률 및 리스크 설정" page (capstone §4.4 / Figma 포트폴리오 설계).
///
/// Shown as the final step right before the home dashboard. The user drags
/// a point along the efficient frontier; the expected return, volatility,
/// max-drawdown (MDD) and worst-year figures update live. Dragging past the
/// suitability band (over-risking) flips the accent to amber, swaps the
/// legend, and raises a warning banner — mirroring the two Figma states.
///
/// Reads the frontier preview from [PortfolioState] (populated during
/// onboarding); falls back to a synthetic curve so the page always renders.
class PortfolioDesignScreen extends StatefulWidget {
  /// Optional explicit selection (passed when pushed from the review flow).
  /// When null, the screen resolves the preview from [PortfolioState].
  final OnboardingFrontierSelection? selection;

  const PortfolioDesignScreen({super.key, this.selection});

  @override
  State<PortfolioDesignScreen> createState() => _PortfolioDesignScreenState();
}

class _PortfolioDesignScreenState extends State<PortfolioDesignScreen> {
  bool _initialized = false;
  late MobileFrontierPreviewResponse _preview;
  late List<MobileFrontierPreviewPoint> _points;
  late int _recommendedPosition;
  late int _inRangeLow;
  late int _inRangeHigh;
  int _selectedPosition = 0;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    logPageEnter('PortfolioDesignScreen');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final state = PortfolioStateProvider.of(context);
    final resolved = widget.selection?.preview ??
        state.onboardingFrontierSelection?.preview ??
        state.frontierPreview;
    _preview = (resolved != null && resolved.points.isNotEmpty)
        ? resolved
        : _fallbackPreview;
    _points = _preview.points;

    final n = _points.length;
    _recommendedPosition = _preview.recommendedPreviewPosition;
    // Suitable band around the recommended point. Asymmetric (a touch more
    // headroom on the upside) so the recommended point sits left-of-center
    // in the clear band, matching the Figma layout.
    final recT = n <= 1 ? 0.5 : _recommendedPosition / (n - 1);
    final lowT = (recT - 0.25).clamp(0.0, 1.0);
    final highT = (recT + 0.30).clamp(0.0, 1.0);
    _inRangeLow = (lowT * (n - 1)).round().clamp(0, n - 1);
    _inRangeHigh = (highT * (n - 1)).round().clamp(0, n - 1);

    // Open on the user's onboarding pick when it falls inside the suitable
    // band; otherwise on the recommended point. This keeps the page opening
    // in the calm in-range state shown in the design rather than launching
    // straight into the over-risk warning.
    final pick = widget.selection?.selectedPointIndex ??
        state.onboardingFrontierSelection?.selectedPointIndex;
    final pickPos = pick != null
        ? _preview.positionForPointIndex(pick)
        : _recommendedPosition;
    _selectedPosition = (pickPos >= _inRangeLow && pickPos <= _inRangeHigh)
        ? pickPos
        : _recommendedPosition;
  }

  @override
  void dispose() {
    logPageExit('PortfolioDesignScreen');
    super.dispose();
  }

  MobileFrontierPreviewPoint get _sel =>
      _points[_selectedPosition.clamp(0, _points.length - 1)];

  bool get _outOfRange =>
      _selectedPosition < _inRangeLow || _selectedPosition > _inRangeHigh;
  bool get _overRisk => _selectedPosition > _inRangeHigh;

  Color get _accent =>
      _outOfRange ? kFrontierAccentOrange : kFrontierAccentBlue;

  String get _returnStr =>
      '+${(_sel.expectedReturn * 100).toStringAsFixed(1)}%';
  String get _volStr => '±${(_sel.volatility * 100).toStringAsFixed(1)}%';
  // The frontier feed carries no drawdown figures, so we derive them from
  // volatility. The factors below reproduce the capstone design's numbers
  // exactly (e.g. ±9.0% vol → -14.4% MDD, -8.1% worst year).
  String get _mddStr => '-${(_sel.volatility * 1.6 * 100).toStringAsFixed(1)}%';
  String get _worstStr =>
      '-${(_sel.volatility * 0.9 * 100).toStringAsFixed(1)}%';

  ({String title, String desc}) get _legendText {
    if (_overRisk) {
      return (title: '수익 중심', desc: '높은 수익 가능, 변동도 큼');
    }
    if (_selectedPosition < _inRangeLow) {
      return (title: '안정 추구', desc: '변동성은 낮지만 기대수익도 낮아요');
    }
    return (title: '균형형', desc: '안정성과 수익성의 밸런스');
  }

  void _onPositionChanged(int pos) {
    if (pos == _selectedPosition && _hasInteracted) return;
    setState(() {
      _selectedPosition = pos;
      _hasInteracted = true;
    });
  }

  void _showRecommended() {
    logAction('portfolio design AI recommend', {
      'position': _recommendedPosition,
    });
    setState(() {
      _selectedPosition = _recommendedPosition;
      _hasInteracted = true;
    });
  }

  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    logAction('portfolio design confirm', {
      'position': _selectedPosition,
      'pointIndex': _sel.index,
      'inRange': !_outOfRange,
    });
    if (!mounted) return;
    navigator.pushReplacement(
      WeRoboMotion.fadeRoute(
        PortfolioMarketComparisonScreen(selection: _currentSelection()),
      ),
    );
  }

  OnboardingFrontierSelection _currentSelection() {
    final normalizedT =
        _points.length <= 1 ? 0.0 : _selectedPosition / (_points.length - 1);
    return OnboardingFrontierSelection(
      normalizedT: normalizedT,
      selectedPointIndex: _sel.index,
      targetVolatility: _sel.volatility,
      dataSource: _preview.dataSource,
      asOfDate: _preview.asOfDate ?? widget.selection?.asOfDate,
      isAuthoritative: true,
      preview: _preview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final legend = _legendText;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '기대수익과 리스크를 설정해주세요',
                        style: const TextStyle(
                          fontFamily: WeRoboFonts.body,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: WeRoboColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '곡선 위의 점을\n좌우로 끌어보세요',
                        style: WeRoboTypography.heading2.themed(context),
                      ),
                      const SizedBox(height: 18),
                      _ChartCard(
                        background: tc.card,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 280,
                              child: RiskReturnFrontierChart(
                                points: _points,
                                selectedPosition: _selectedPosition,
                                recommendedPosition: _recommendedPosition,
                                inRangeLow: _inRangeLow,
                                inRangeHigh: _inRangeHigh,
                                onPositionChanged: _onPositionChanged,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _Legend(
                              title: legend.title,
                              desc: legend.desc,
                              color: _accent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: '기대 연수익률',
                              value: _returnStr,
                              valueColor: kFrontierAccentBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              label: '예상 변동성',
                              value: _volStr,
                              valueColor: kFrontierAccentBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: '예상 최대 낙폭',
                              value: _mddStr,
                              valueColor: kFrontierDangerCoral,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              label: '예상 최악의 1년',
                              value: _worstStr,
                              valueColor: kFrontierDangerCoral,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_outOfRange)
                      const _WarningBanner()
                    else
                      _AiRecommendButton(onTap: _showRecommended),
                    const SizedBox(height: 10),
                    _ConfirmButton(
                      enabled: _hasInteracted,
                      onTap: _hasInteracted ? _confirm : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Color background;
  final Widget child;

  const _ChartCard({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: child,
    );
  }
}

class _Legend extends StatelessWidget {
  final String title;
  final String desc;
  final Color color;

  const _Legend({
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: WeRoboTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Flexible(
          child: Text(
            ' · $desc',
            style: WeRoboTypography.caption.copyWith(color: tc.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: WeRoboTypography.caption.copyWith(color: tc.textSecondary),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: WeRoboMotion.short,
            style: WeRoboTypography.number.copyWith(
              color: valueColor,
              fontSize: 24,
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _AiRecommendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AiRecommendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(color: kFrontierAccentBlue),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(
            'AI 추천 지점을 보여주세요',
            style: WeRoboTypography.button.copyWith(
              color: kFrontierAccentBlue,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kFrontierDangerCoral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '⚠️ 투자자 유형의 적합 범위를 벗어난 구간입니다',
        style: WeRoboTypography.caption.copyWith(
          color: kFrontierDangerCoral,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _ConfirmButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? WeRoboColors.primaryDark : WeRoboColors.primaryLight,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
      ),
      child: Text(
        enabled ? '포트폴리오 확인하기' : '점을 움직여보세요',
        style: WeRoboTypography.button.copyWith(
          color: enabled ? WeRoboColors.white : _kMutedGray,
        ),
      ),
    );
    if (!enabled) return body;
    return Pressable(onTap: onTap, child: body);
  }
}

/// Paints a dashed rounded-rectangle border (Flutter has no built-in).
class _DashedRRectPainter extends CustomPainter {
  final Color color;

  _DashedRRectPainter({required this.color});

  static const double _radius = 16;
  static const double _dashLength = 5;
  static const double _gapLength = 4;
  static const double _strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = math.min(_dashLength, metric.length - dist);
        dashed.addPath(metric.extractPath(dist, dist + len), Offset.zero);
        dist += _dashLength + _gapLength;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}

/// Synthetic frontier used only when no preview is available (e.g. the
/// '/portfolio-design' route hit directly). Mirrors a realistic managed
/// universe so the curve, band, and stats render sensibly.
final MobileFrontierPreviewResponse _fallbackPreview =
    MobileFrontierPreviewResponse.fromJson(const <String, dynamic>{
  'resolved_profile': {
    'code': 'balanced',
    'label': '균형형',
    'propensity_score': 45.0,
    'target_volatility': 0.09,
    'investment_horizon': 'medium',
  },
  'recommended_portfolio_code': 'balanced',
  'data_source': 'managed_universe',
  'total_point_count': 9,
  'min_volatility': 0.05,
  'max_volatility': 0.20,
  'points': <Map<String, dynamic>>[
    {'index': 0, 'volatility': 0.05, 'expected_return': 0.045},
    {'index': 1, 'volatility': 0.07, 'expected_return': 0.058},
    {
      'index': 2,
      'volatility': 0.09,
      'expected_return': 0.069,
      'is_recommended': true
    },
    {'index': 3, 'volatility': 0.11, 'expected_return': 0.078},
    {'index': 4, 'volatility': 0.13, 'expected_return': 0.086},
    {'index': 5, 'volatility': 0.15, 'expected_return': 0.092},
    {'index': 6, 'volatility': 0.17, 'expected_return': 0.097},
    {'index': 7, 'volatility': 0.19, 'expected_return': 0.101},
    {'index': 8, 'volatility': 0.20, 'expected_return': 0.103},
  ],
});
