import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class DonutSegment {
  final double weight; // 0.0–1.0
  final Color color;
  const DonutSegment({required this.weight, required this.color});
}

class DonutChart extends StatefulWidget {
  final List<DonutSegment> segments;
  final String centerLabel;
  final bool compact;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    this.compact = false,
  });

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
    final tc = WeRoboThemeColors.of(context);
    final size = widget.compact ? 180.0 : 240.0;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            progress: _animation.value,
            segments: widget.segments,
            borderColor: tc.surface,
          ),
          child: Center(
            child: Text(
              widget.centerLabel,
              style: WeRoboTypography.heading3.themed(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final List<DonutSegment> segments;
  final Color borderColor;

  _DonutPainter({
    required this.progress,
    required this.segments,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 28.0;
    const gapAngle = 0.012; // ~1px gap at typical radius

    double startAngle = -pi / 2;
    for (final segment in segments) {
      final sweepAngle = 2 * pi * segment.weight * progress - gapAngle;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt; // butt + gap = clean separator
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += 2 * pi * segment.weight * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.segments != segments;
}
