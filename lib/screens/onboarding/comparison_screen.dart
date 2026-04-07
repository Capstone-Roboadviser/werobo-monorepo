import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/portfolio_data.dart';
import 'confirmation_screen.dart';

class ComparisonScreen extends StatefulWidget {
  final InvestmentType investmentType;

  const ComparisonScreen({super.key, required this.investmentType});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen>
    with TickerProviderStateMixin {
  late InvestmentType _selected;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selected = widget.investmentType;
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
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = PortfolioData.categoriesFor(_selected);
    final (risk, returnRate) = PortfolioData.statsFor(_selected);

    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text('포트폴리오 비교',
                    style: WeRoboTypography.heading2,
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 4),
              Text('투자 성향에 맞는 포트폴리오를 선택하세요',
                  style: WeRoboTypography.bodySmall),
              const SizedBox(height: 20),

              // 3 type selector chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: InvestmentType.values.map((type) {
                    final isSelected = type == _selected;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: type == InvestmentType.safe ? 0 : 6,
                          right: type == InvestmentType.growth ? 0 : 6,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? WeRoboColors.primary
                                  : WeRoboColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: WeRoboColors.lightGray,
                                      width: 1),
                            ),
                            child: Text(
                              type.label,
                              textAlign: TextAlign.center,
                              style: WeRoboTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? WeRoboColors.white
                                    : WeRoboColors.textSecondary,
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
                        color: WeRoboColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Animated donut chart
              _AnimatedDonut(
                categories: categories,
                label: _selected.label,
              ),
              const SizedBox(height: 20),

              // Sector list with fade
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _SectorList(
                    key: ValueKey(_selected),
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
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              ConfirmationScreen(
                                  investmentType: _selected),
                          transitionsBuilder: (_, anim, __, child) =>
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

/// Rolling number stat chip — digits animate like a digital clock
class _AnimatedStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnimatedStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  double _parseValue(String v) {
    return double.tryParse(v.replaceAll('%', '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WeRoboColors.lightGray, width: 1),
      ),
      child: Column(
      children: [
        Text(label,
            style: WeRoboTypography.caption.copyWith(
                color: WeRoboColors.textSecondary)),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _parseValue(value)),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            return Text(
              '${val.toStringAsFixed(1)}%',
              style: WeRoboTypography.number.copyWith(
                color: WeRoboColors.textPrimary,
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
    _newPercentages =
        widget.categories.map((c) => c.percentage).toList();
    _oldPercentages = List.from(_newPercentages);
  }

  @override
  void didUpdateWidget(covariant _AnimatedDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _oldPercentages = List.from(_newPercentages);
      _newPercentages =
          widget.categories.map((c) => c.percentage).toList();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t =
            Curves.easeInOut.transform(_controller.value);
        final interpolated = <double>[];
        for (int i = 0; i < _newPercentages.length; i++) {
          interpolated.add(
              _oldPercentages[i] + (_newPercentages[i] - _oldPercentages[i]) * t);
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
                    color: WeRoboColors.textPrimary,
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
  bool shouldRepaint(covariant _SmoothDonutPainter oldDelegate) => true;
}

/// Sector breakdown list (fades in/out on portfolio switch)
class _SectorList extends StatelessWidget {
  final List<PortfolioCategory> categories;

  const _SectorList({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
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
                          style: WeRoboTypography.bodySmall.copyWith(
                              color: WeRoboColors.textPrimary)),
                    ),
                    Text(
                      '${cat.percentage.toInt()}%',
                      style: WeRoboTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: WeRoboColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
