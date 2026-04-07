import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/portfolio_data.dart';

/// Reusable Vestor-style interactive pie chart
class VestorPieChart extends StatefulWidget {
  final List<PortfolioCategory> categories;
  final double size;
  final double ringWidth;
  final double selectedRingWidth;
  final ValueChanged<int?>? onSectorSelected;
  final int? initialSelected;

  /// Custom center content builder. If null, uses default name+percentage.
  final Widget Function(int? selectedIndex)? centerBuilder;

  const VestorPieChart({
    super.key,
    required this.categories,
    this.size = 248,
    this.ringWidth = 32,
    this.selectedRingWidth = 38,
    this.onSectorSelected,
    this.initialSelected,
    this.centerBuilder,
  });

  @override
  State<VestorPieChart> createState() => _VestorPieChartState();
}

class _VestorPieChartState extends State<VestorPieChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelected;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _hitTest(Offset localPos) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final tapOffset = localPos - center;
    final distance = tapOffset.distance;
    final outerRadius = widget.size / 2;
    final innerRadius = outerRadius - widget.ringWidth - 20;

    if (distance > outerRadius + 20 || distance < innerRadius) return null;

    var angle = atan2(tapOffset.dy, tapOffset.dx) + pi / 2;
    if (angle < 0) angle += 2 * pi;

    final total =
        widget.categories.fold<double>(0, (sum, c) => sum + c.percentage);
    double cumulative = 0;
    for (int i = 0; i < widget.categories.length; i++) {
      cumulative += widget.categories[i].percentage;
      if (angle <= (cumulative / total) * 2 * pi) return i;
    }
    return widget.categories.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final selected =
        _selectedIndex != null ? widget.categories[_selectedIndex!] : null;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final idx = _hitTest(details.localPosition);
          setState(() {
            _selectedIndex = (idx == _selectedIndex) ? null : idx;
          });
          widget.onSectorSelected?.call(_selectedIndex);
        },
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _VestorPieChartPainter(
                  categories: widget.categories,
                  progress: _animation.value,
                  selectedIndex: _selectedIndex,
                  ringWidth: widget.ringWidth,
                  selectedRingWidth: widget.selectedRingWidth,
                ),
                child: Center(
                  child: widget.centerBuilder != null
                      ? widget.centerBuilder!(_selectedIndex)
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: selected != null
                              ? Column(
                                  key: ValueKey(_selectedIndex),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          selected.name,
                                          style: WeRoboTypography.bodySmall
                                              .copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: tc.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 16,
                                          color: tc.textTertiary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${selected.percentage.toInt()}%',
                                      style: WeRoboTypography.number
                                          .themed(context),
                                    ),
                                  ],
                                )
                              : Text(
                                  key: const ValueKey('default'),
                                  '포트폴리오\n비중',
                                  style: WeRoboTypography.heading3.copyWith(
                                    color: tc.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VestorPieChartPainter extends CustomPainter {
  final List<PortfolioCategory> categories;
  final double progress;
  final int? selectedIndex;
  final double ringWidth;
  final double selectedRingWidth;

  _VestorPieChartPainter({
    required this.categories,
    required this.progress,
    this.selectedIndex,
    required this.ringWidth,
    required this.selectedRingWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRingRadius = size.width / 2 - ringWidth / 2;
    final selectedRingRadius = size.width / 2 - selectedRingWidth / 2 + 3;
    const gapRadians = 0.03;

    final total = categories.fold<double>(0, (sum, c) => sum + c.percentage);
    double startAngle = -pi / 2;

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final fullSweep = (cat.percentage / total) * 2 * pi * progress;
      final sweepAngle = fullSweep - gapRadians;
      if (sweepAngle <= 0) {
        startAngle += fullSweep;
        continue;
      }

      final isSelected = i == selectedIndex;
      final hasSelection = selectedIndex != null;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      if (isSelected) {
        paint.color = cat.color;
        paint.strokeWidth = selectedRingWidth;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: selectedRingRadius),
          startAngle + gapRadians / 2,
          sweepAngle,
          false,
          paint,
        );
      } else {
        paint.color =
            hasSelection ? cat.color.withValues(alpha: 0.6) : cat.color;
        paint.strokeWidth = ringWidth;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: baseRingRadius),
          startAngle + gapRadians / 2,
          sweepAngle,
          false,
          paint,
        );
      }

      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _VestorPieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
