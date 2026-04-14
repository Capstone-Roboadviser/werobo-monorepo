import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/rebalance_insight.dart';

/// Animated donut chart that morphs from before→after allocation weights.
class InsightTransitionChart extends StatefulWidget {
  final List<RebalanceInsightAllocation> allocations;
  final double size;
  final double ringWidth;

  const InsightTransitionChart({
    super.key,
    required this.allocations,
    this.size = 220,
    this.ringWidth = 28,
  });

  @override
  State<InsightTransitionChart> createState() =>
      _InsightTransitionChartState();
}

class _InsightTransitionChartState extends State<InsightTransitionChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _TransitionPainter(
              allocations: widget.allocations,
              progress: _animation.value,
              ringWidth: widget.ringWidth,
            ),
          ),
        );
      },
    );
  }
}

class _TransitionPainter extends CustomPainter {
  final List<RebalanceInsightAllocation> allocations;
  final double progress;
  final double ringWidth;

  _TransitionPainter({
    required this.allocations,
    required this.progress,
    required this.ringWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - ringWidth / 2;
    const gapRadians = 0.03;

    // Compute total before and after to normalize
    final totalBefore =
        allocations.fold<double>(0, (s, a) => s + a.beforePct);
    final totalAfter =
        allocations.fold<double>(0, (s, a) => s + a.afterPct);

    double startAngle = -pi / 2;

    for (final alloc in allocations) {
      final beforeFrac = totalBefore > 0
          ? alloc.beforePct / totalBefore
          : 0.0;
      final afterFrac = totalAfter > 0
          ? alloc.afterPct / totalAfter
          : 0.0;

      // Interpolate between before and after sweep
      final fraction = lerpDouble(beforeFrac, afterFrac, progress)!;
      final fullSweep = fraction * 2 * pi;
      final sweepAngle = fullSweep - gapRadians;

      if (sweepAngle <= 0) {
        startAngle += fullSweep;
        continue;
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.butt
        ..color = alloc.hasChanged
            ? alloc.color
            : const Color(0x26444444);

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
  bool shouldRepaint(covariant _TransitionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Small static donut thumbnail for list items — shows post-allocation.
class InsightDonutThumbnail extends StatelessWidget {
  final List<RebalanceInsightAllocation> allocations;
  final double size;

  const InsightDonutThumbnail({
    super.key,
    required this.allocations,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ThumbnailPainter(allocations: allocations),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final List<RebalanceInsightAllocation> allocations;

  _ThumbnailPainter({required this.allocations});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const ringWidth = 6.0;
    final radius = size.width / 2 - ringWidth / 2;
    const gapRadians = 0.04;

    final total =
        allocations.fold<double>(0, (s, a) => s + a.afterPct);
    if (total <= 0) return;

    double startAngle = -pi / 2;

    for (final alloc in allocations) {
      final fullSweep = (alloc.afterPct / total) * 2 * pi;
      final sweepAngle = fullSweep - gapRadians;
      if (sweepAngle <= 0) {
        startAngle += fullSweep;
        continue;
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.butt
        ..color = alloc.hasChanged
            ? alloc.color
            : const Color(0x26444444);

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
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => false;
}
