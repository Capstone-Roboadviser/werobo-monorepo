import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
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
  late String _selectedCode;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.frontierSelection == null
        ? widget.selectedPortfolioCode
        : 'selected';
    logPageEnter('ComparisonScreen', {
      'selected': _selectedCode,
    });
    logAction('comparison initial selected', {
      'portfolio': _selectedCode,
    });
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
  void dispose() {
    logPageExit('ComparisonScreen');
    _fadeController.dispose();
    super.dispose();
  }

  String _portfolioSummary(String code) {
    if (code == 'selected') {
      final target = widget.frontierSelection?.selectedTargetVolatility ?? 0;
      return '선택한 변동성 ${formatRatioPercent(target)}에 가장 가까운\n'
          '프론티어 포인트를 그대로 반영했어요.';
    }
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
    if (frontierSelection != null && code == 'selected') {
      return frontierSelection.portfolio;
    }
    return widget.recommendation.recommendedPortfolio;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolios = <MobilePortfolioRecommendation>[
      widget.frontierSelection?.portfolio ??
          widget.recommendation.recommendedPortfolio,
    ];
    final selected = _portfolioForCode(_selectedCode);
    final categories = selected.toCategories();
    final risk = selected.volatilityLabel;
    final returnRate = selected.expectedReturnLabel;

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
                          style: WeRoboTypography.heading2.themed(context),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('${widget.recommendation.resolvedProfile.label} 성향과 비교해 보세요',
                  style: WeRoboTypography.bodySmall.themed(context)),
              const SizedBox(height: 20),

              // Portfolio selector chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: portfolios.asMap().entries.map((entry) {
                    final index = entry.key;
                    final portfolio = entry.value;
                    final isSelected = portfolio.code == _selectedCode;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 6,
                          right: index == portfolios.length - 1 ? 0 : 6,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            logAction('select comparison portfolio', {
                              'portfolio': portfolio.code,
                            });
                            setState(() => _selectedCode = portfolio.code);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? WeRoboColors.primary : tc.card,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? null
                                  : Border.all(color: tc.border, width: 1),
                            ),
                            child: Text(
                              portfolio.label,
                              textAlign: TextAlign.center,
                              style: WeRoboTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? WeRoboColors.white
                                    : tc.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Stats with rolling number animation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _AnimatedStatChip(
                        label: '위험도',
                        value: risk,
                        color: WeRoboColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnimatedStatChip(
                        label: '수익률',
                        value: returnRate,
                        color: tc.accent,
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
                    color: WeRoboColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _portfolioSummary(_selectedCode),
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
                label: selected.label,
              ),
              const SizedBox(height: 20),

              // Sector list with fade
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _SectorList(
                    key: ValueKey(_selectedCode),
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
                        'selected': _selectedCode,
                      });
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => ConfirmationScreen(
                            recommendation: widget.recommendation,
                            selectedPortfolioCode: _selectedCode,
                            frontierSelection: _selectedCode == 'selected'
                                ? widget.frontierSelection
                                : null,
                          ),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration: const Duration(milliseconds: 400),
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
  final Color color;

  const _AnimatedStatChip({
    required this.label,
    required this.value,
    required this.color,
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
    return double.tryParse(v.replaceAll('%', '')) ?? 0;
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
              style: WeRoboTypography.caption.copyWith(color: widget.color)),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              final val = _previousValue + (_currentValue - _previousValue) * t;
              return Text(
                '${val.toStringAsFixed(1)}%',
                style: WeRoboTypography.number.copyWith(
                  color: tc.textPrimary,
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
