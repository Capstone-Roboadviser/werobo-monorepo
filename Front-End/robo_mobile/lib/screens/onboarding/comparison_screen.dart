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
  final MobileFrontierSelectionResponse frontierSelection;

  const ComparisonScreen({
    super.key,
    required this.frontierSelection,
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
  MobileFrontierSelectionResponse? _currentSelection;
  int _requestSeqNo = 0;
  Timer? _debounceTimer;

  // Frontier preview data (cached from onboarding)
  MobileFrontierPreviewResponse? _frontierPreview;
  late double _minVol;
  late double _maxVol;

  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.frontierSelection;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;

      // Read frontier preview from provider
      _frontierPreview =
          PortfolioStateProvider.of(context).frontierPreview;
      _initSliderRange();

      logPageEnter('ComparisonScreen', {
        'selected': widget.frontierSelection.classificationCode,
        'selected_point_index': widget.frontierSelection.selectedPointIndex,
      });
      logAction('comparison initial selected', {
        'classification': widget.frontierSelection.classificationCode,
        'selected_point_index': widget.frontierSelection.selectedPointIndex,
      });
    }
  }

  void _initSliderRange() {
    final preview = _frontierPreview;
    if (preview != null && preview.points.isNotEmpty) {
      _minVol = _frontierPreview!.minVolatility;
      _maxVol = _frontierPreview!.maxVolatility;
      final initialPosition =
          preview.positionForPointIndex(widget.frontierSelection.selectedPointIndex);
      _sliderValue = preview.points.length <= 1
          ? 0.5
          : initialPosition / (preview.points.length - 1);
    } else {
      _minVol = widget.frontierSelection.selectedTargetVolatility;
      _maxVol = widget.frontierSelection.selectedTargetVolatility;
      _sliderValue = 0.5;
    }
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

  int _previewPositionForSlider(double value) {
    final points = _frontierPreview?.points;
    if (points == null || points.isEmpty) {
      return 0;
    }
    final scaled = (value * (points.length - 1)).round();
    return scaled.clamp(0, points.length - 1);
  }

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
      _fetchSelection(_previewPositionForSlider(value));
    });
  }

  Future<void> _fetchSelection(int previewPosition) async {
    final preview = _frontierPreview;
    if (preview == null || preview.points.isEmpty) {
      return;
    }
    final selectedPreviewPoint = preview.points[previewPosition];
    final mySeq = ++_requestSeqNo;
    try {
      final result =
          await MobileBackendApi.instance.fetchFrontierSelection(
        propensityScore:
            widget.frontierSelection.resolvedProfile.propensityScore ?? 50,
        pointIndex: selectedPreviewPoint.index,
        targetVolatility: selectedPreviewPoint.volatility,
        investmentHorizon:
            widget.frontierSelection.resolvedProfile.investmentHorizon,
        preferredDataSource: widget.frontierSelection.dataSource,
        asOfDate: widget.frontierSelection.asOfDate,
      );
      if (!mounted || mySeq != _requestSeqNo) return;
      setState(() {
        _currentSelection = result;
      });
      logAction('slider selection loaded', {
        'selected_point_index': result.selectedPointIndex,
        'classification': result.classificationCode,
        'volatility': result.selectedTargetVolatility.toStringAsFixed(4),
      });
    } on Exception catch (e) {
      if (!mounted || mySeq != _requestSeqNo) return;
      logAction('slider selection error', {
        'error': e.toString(),
      });
      // Error handled silently — previous data stays visible
    }
  }

  String _portfolioSummary(MobilePortfolioRecommendation portfolio) {
    return '연 기대수익률 ${portfolio.expectedReturnLabel}, '
        '연 변동성 ${portfolio.volatilityLabel} 수준의 조합입니다.\n'
        '슬라이더를 움직이면 frontier 위의 다른 지점으로 바로 바꿀 수 있어요.';
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);

    // Instant stats from preview point
    final previewPoint = _nearestPreviewPoint(_sliderValue);
    final displayPortfolio = _currentSelection?.portfolio ??
        widget.frontierSelection.portfolio;
    final instantReturn = previewPoint != null
        ? formatRatioPercent(previewPoint.expectedReturn)
        : displayPortfolio.expectedReturnLabel;

    // Market-relative risk (instant from preview volatility)
    final avg = _frontierPreview?.averageVolatility ?? displayPortfolio.volatility;
    final previewVol = previewPoint?.volatility ?? displayPortfolio.volatility;
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

    final categories = displayPortfolio.toCategories();
    final donutLabel = displayPortfolio.label;

    final previewCount = _frontierPreview?.points.length ?? 0;
    final divisions = previewCount > 1 ? previewCount - 1 : null;

    return Scaffold(
      backgroundColor: tc.background,
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
                '${widget.frontierSelection.resolvedProfile.label}'
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
                          Text(
                            '낮은 위험',
                            style: WeRoboTypography.caption.copyWith(
                              color: tc.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '높은 기대수익',
                            style: WeRoboTypography.caption.copyWith(
                              color: tc.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                    _portfolioSummary(displayPortfolio),
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
                        '${displayPortfolio.code}_${_currentSelection?.selectedPointIndex ?? widget.frontierSelection.selectedPointIndex}'),
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
                      final selection = _currentSelection ?? widget.frontierSelection;
                      logAction('tap confirm portfolio', {
                        'selected': selection.classificationCode,
                        'selected_point_index': selection.selectedPointIndex,
                      });
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              ConfirmationScreen(
                            frontierSelection: selection,
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
