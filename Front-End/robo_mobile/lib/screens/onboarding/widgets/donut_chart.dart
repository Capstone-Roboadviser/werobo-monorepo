import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class DonutChart extends StatefulWidget {
  const DonutChart({super.key});

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: WeRoboMotion.chartDraw,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: WeRoboMotion.chartReveal),
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
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: _DonutPainter(
              progress: _animation.value,
              segments: const [
                _Segment(0.45, WeRoboColors.assetTier4),
                _Segment(0.40, WeRoboColors.assetTier5),
                _Segment(0.15, WeRoboColors.assetTier3),
              ],
            ),
            child: Center(
              child: Text(
                '${(45 * _animation.value).toInt()}%',
                style: WeRoboTypography.number.copyWith(
                  color: WeRoboColors.assetTier4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Segment {
  final double value;
  final Color color;
  const _Segment(this.value, this.color);
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final List<_Segment> segments;

  _DonutPainter({required this.progress, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 28.0;

    // Background ring
    final bgPaint = Paint()
      ..color = WeRoboColors.dotInactive.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Segments
    double startAngle = -pi / 2;
    for (final segment in segments) {
      final sweepAngle = 2 * pi * segment.value * progress;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += 2 * pi * segment.value * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
