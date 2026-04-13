import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../services/mobile_backend_api.dart';
import 'confirmation_screen.dart';

class ComparisonScreen extends StatefulWidget {
  final MobileRecommendationResponse recommendation;
  final String selectedPortfolioCode;
  final MobileFrontierSelectionResponse? frontierSelection;

  const ComparisonScreen({
    super.key,
    required this.recommendation,
    required this.selectedPortfolioCode,
    this.frontierSelection,
  });

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Slider state
  double _sliderValue = 0.5;
  String _snappedCode = 'balanced';
  MobileFrontierSelectionResponse? _currentSelection;
  int _requestSeqNo = 0;
  Timer? _debounceTimer;

  // Frontier preview data (cached from onboarding)
  MobileFrontierPreviewResponse? _frontierPreview;
  late double _minVol;
  late double _maxVol;
  late List<_SnapPoint> _snapPoints;

  @override
  void initState() {
    super.initState();
    _snappedCode = widget.selectedPortfolioCode;

    // Read frontier preview from provider
    _frontierPreview =
        PortfolioStateProvider.of(context).frontierPreview;
    _initSliderRange();

    logPageEnter('ComparisonScreen', {'selected': _snappedCode});
    logAction('comparison initial selected', {
      'portfolio': _snappedCode,
    });

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();

    // Fire initial API call for the selected portfolio
    _fetchSelection(_sliderToVolatility(_sliderValue));
  }

  void _initSliderRange() {
    final portfolios = widget.recommendation.portfolios;
    final sorted = [...portfolios]
      ..sort((a, b) => a.volatility.compareTo(b.volatility));

    if (_frontierPreview != null) {
      _minVol = _frontierPreview!.minVolatility;
      _maxVol = _frontierPreview!.maxVolatility;
    } else {
      _minVol = sorted.first.volatility;
      _maxVol = sorted.last.volatility;
    }

    final range = _maxVol - _minVol;
    _snapPoints = sorted.map((p) {
      final pos = range > 0 ? (p.volatility - _minVol) / range : 0.5;
      return _SnapPoint(code: p.code, label: p.label, position: pos);
    }).toList();

    // Set initial slider position to match selected portfolio
    final initial = _snapPoints
        .where((s) => s.code == widget.selectedPortfolioCode)
        .firstOrNull;
    _sliderValue = initial?.position ?? 0.5;
  }

  @override
  void dispose() {
    logPageExit('ComparisonScreen');
    _debounceTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  double _sliderToVolatility(double t) =>
      _minVol + t * (_maxVol - _minVol);

  MobileFrontierPreviewPoint? _nearestPreviewPoint(double t) {
    final points = _frontierPreview?.points;
    if (points == null || points.isEmpty) return null;
    final targetVol = _sliderToVolatility(t);
    MobileFrontierPreviewPoint closest = points.first;
    double minDist = (closest.volatility - targetVol).abs();
    for (final p in points) {
      final dist = (p.volatility - targetVol).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = p;
      }
    }
    return closest;
  }

  void _onSliderChanged(double value) {
    setState(() => _sliderValue = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSelection(_sliderToVolatility(value));
    });
  }

  Future<void> _fetchSelection(double targetVol) async {
    final mySeq = ++_requestSeqNo;
    // No loading indicator — previous data stays visible during fetch
    try {
      final profile = widget.recommendation.resolvedProfile;
      final result =
          await MobileBackendApi.instance.fetchFrontierSelection(
        propensityScore: profile.propensityScore ?? 50,
        targetVolatility: targetVol,
        investmentHorizon: profile.investmentHorizon,
        preferredDataSource: widget.recommendation.dataSource,
      );
      if (!mounted || mySeq != _requestSeqNo) return;
      setState(() {
        _currentSelection = result;
        _snappedCode =
            result.representativeCode ?? _snappedCode;
      });
      logAction('slider selection loaded', {
        'code': _snappedCode,
        'volatility': targetVol.toStringAsFixed(4),
      });
    } on Exception catch (e) {
      if (!mounted || mySeq != _requestSeqNo) return;
      logAction('slider selection error', {
        'error': e.toString(),
      });
      // Error handled silently — previous data stays visible
    }
  }

  String _portfolioSummary(String code) {
    switch (code) {
      case 'conservative':
        return '채권 중심으로 변동이 적어요.\n'
            '은행 예금보다 높은 수익을 기대할 수 있어요.';
      case 'growth':
        return '주식 비중이 높아 수익 가능성이 커요.\n'
            '단기적으로 변동이 클 수 있지만 장기 성장을 추구해요.';
      case 'balanced':
      default:
        return '주식과 채권을 균형 있게 배분해요.\n'
            '적당한 수익과 안정성을 동시에 추구해요.';
    }
  }

  MobilePortfolioRecommendation _portfolioForCode(String code) {
    final frontierSelection = widget.frontierSelection;
    if (frontierSelection != null &&
        frontierSelection.representativeCode == code) {
      return frontierSelection.portfolio;
    }
    return widget.recommendation.portfolioByCodeOrRecommended(code);
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);

    // Instant stats from preview point
    final previewPoint = _nearestPreviewPoint(_sliderValue);
    final instantReturn = previewPoint != null
        ? formatRatioPercent(previewPoint.expectedReturn)
        : _portfolioForCode(_snappedCode).expectedReturnLabel;

    // Market-relative risk (instant from preview volatility)
    final avg = widget.recommendation.averageVolatility;
    final previewVol = previewPoint?.volatility ??
        _portfolioForCode(_snappedCode).volatility;
    final riskDiff = avg > 0 ? (previewVol - avg) / avg : 0.0;
    final riskPct = (riskDiff.abs() * 100).round();
    final isRiskier = riskDiff >= 0;
    final riskText = riskPct == 0
        ? '0%'
        : isRiskier
            ? '+$riskPct%'
            : '-$riskPct%';
    final riskColor = riskPct == 0
        ? tc.textPrimary
        : isRiskier
            ? WeRoboColors.warning
            : tc.accent;

    // Donut/sector data from API response or fallback
    final displayPortfolio = _currentSelection?.portfolio ??
        _portfolioForCode(_snappedCode);
    final categories = displayPortfolio.toCategories();
    final donutLabel = _currentSelection?.representativeLabel ??
        displayPortfolio.label;

    final divisions = _frontierPreview != null
        ? _frontierPreview!.points.length - 1
        : 60;

    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          size: 20, color: tc.textPrimary),
                    ),
                    Expanded(
                      child: Text('포트폴리오 비교',
                          style:
                              WeRoboTypography.heading2.themed(context),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.recommendation.resolvedProfile.label}'
                ' 성향과 비교해 보세요',
                style: WeRoboTypography.bodySmall.themed(context),
              ),
              const SizedBox(height: 20),

              // Slider with portfolio labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: WeRoboColors.primary,
                        inactiveTrackColor: tc.border,
                        thumbColor: WeRoboColors.primary,
                        overlayColor: WeRoboColors.primary
                            .withValues(alpha: 0.12),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: _sliderValue,
                        divisions: divisions,
                        onChanged: _onSliderChanged,
                        semanticFormatterCallback: (value) {
                          final vol = _sliderToVolatility(value);
                          return '변동성 ${(vol * 100).toStringAsFixed(1)}%';
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          for (int i = 0; i < _snapPoints.length; i++)
                            ...[
                              if (i == 0) const SizedBox.shrink(),
                              if (i > 0) const Spacer(),
                              Text(
                                _snapPoints[i].label,
                                style:
                                    WeRoboTypography.caption.copyWith(
                                  color: tc.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats: 연 수익률 (left) + 시장 대비 위험도 (right)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _AnimatedStatChip(
                        label: '연 수익률',
                        value: instantReturn,
                        labelColor: tc.textPrimary,
                        valueColor: WeRoboColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnimatedStatChip(
                        label: '시장 대비 위험도',
                        value: riskText,
                        labelColor: tc.textPrimary,
                        valueColor: riskColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Plain-language summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WeRoboColors.primary
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _portfolioSummary(_snappedCode),
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Animated donut chart
              _AnimatedDonut(
                categories: categories,
                label: donutLabel,
              ),
              const SizedBox(height: 20),

              // Sector list with fade
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _SectorList(
                    key: ValueKey(
                        '${_snappedCode}_${_currentSelection?.selectedPointIndex}'),
                    categories: categories,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      logAction('tap confirm portfolio', {
                        'selected': _snappedCode,
                      });
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              ConfirmationScreen(
                            recommendation: widget.recommendation,
                            selectedPortfolioCode: _snappedCode,
                            frontierSelection:
                                _currentSelection?.representativeCode ==
                                        _snappedCode
                                    ? _currentSelection
                                    : null,
                          ),
                          transitionsBuilder:
                              (_, anim, __, child) =>
                                  FadeTransition(
                                      opacity: anim, child: child),
                          transitionDuration:
                              const Duration(milliseconds: 400),
                        ),
                      );
                    },
                    child: const Text('투자 성향 확정하기'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapPoint {
  final String code;
  final String label;
  final double position;

  const _SnapPoint({
    required this.code,
    required this.label,
    required this.position,
  });
}

/// Rolling number stat chip with smooth old→new animation
class _AnimatedStatChip extends StatefulWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _AnimatedStatChip({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  State<_AnimatedStatChip> createState() => _AnimatedStatChipState();
}

class _AnimatedStatChipState extends State<_AnimatedStatChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _previousValue = 0;
  double _currentValue = 0;

  static double _parseValue(String v) {
    return double.tryParse(v.replaceAll(RegExp(r'[%+]'), '')) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _currentValue = _parseValue(widget.value);
    _previousValue = _currentValue;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedStatChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _currentValue;
      _currentValue = _parseValue(widget.value);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Column(
        children: [
          Text(widget.label,
              style: WeRoboTypography.caption
                  .copyWith(color: widget.labelColor)),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              final val = _previousValue + (_currentValue - _previousValue) * t;
              return Text(
                '${val.toStringAsFixed(1)}%',
                style: WeRoboTypography.number.copyWith(
                  color: widget.valueColor,
                  fontFamily: WeRoboFonts.english,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Donut chart that animates sector sizes smoothly
class _AnimatedDonut extends StatefulWidget {
  final List<PortfolioCategory> categories;
  final String label;

  const _AnimatedDonut({
    required this.categories,
    required this.label,
  });

  @override
  State<_AnimatedDonut> createState() => _AnimatedDonutState();
}

class _AnimatedDonutState extends State<_AnimatedDonut>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> _oldPercentages = [];
  List<double> _newPercentages = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _newPercentages = widget.categories.map((c) => c.percentage).toList();
    _oldPercentages = List.from(_newPercentages);
  }

  @override
  void didUpdateWidget(covariant _AnimatedDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _oldPercentages = List.from(_newPercentages);
      _newPercentages = widget.categories.map((c) => c.percentage).toList();
      // Pad shorter list if category count differs
      while (_oldPercentages.length < _newPercentages.length) {
        _oldPercentages.add(0);
      }
      while (_newPercentages.length < _oldPercentages.length) {
        _newPercentages.add(0);
      }
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final interpolated = <double>[];
        for (int i = 0; i < _newPercentages.length; i++) {
          interpolated.add(_oldPercentages[i] +
              (_newPercentages[i] - _oldPercentages[i]) * t);
        }

        return SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _SmoothDonutPainter(
              percentages: interpolated,
              colors: widget.categories.map((c) => c.color).toList(),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  widget.label,
                  key: ValueKey(widget.label),
                  style: WeRoboTypography.heading3.copyWith(
                    color: tc.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SmoothDonutPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;

  _SmoothDonutPainter({
    required this.percentages,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 20.0;
    const gapRadians = 0.04;

    final total = percentages.fold<double>(0, (sum, p) => sum + p);
    if (total <= 0) return;

    double startAngle = -pi / 2;

    for (int i = 0; i < percentages.length; i++) {
      final fullSweep = (percentages[i] / total) * 2 * pi;
      final sweepAngle = fullSweep - gapRadians;
      if (sweepAngle <= 0) {
        startAngle += fullSweep;
        continue;
      }

      final paint = Paint()
        ..color = i < colors.length ? colors[i] : Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gapRadians / 2,
        sweepAngle,
        false,
        paint,
      );
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothDonutPainter oldDelegate) {
    if (percentages.length != oldDelegate.percentages.length) return true;
    for (int i = 0; i < percentages.length; i++) {
      if (percentages[i] != oldDelegate.percentages[i]) return true;
    }
    return false;
  }
}

/// Sector breakdown list (fades in/out on portfolio switch)
class _SectorList extends StatelessWidget {
  final List<PortfolioCategory> categories;

  const _SectorList({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: categories
          .map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(cat.name,
                          style: WeRoboTypography.bodySmall
                              .copyWith(color: tc.textPrimary)),
                    ),
                    Text(
                      '${cat.percentage.toInt()}%',
                      style: WeRoboTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
