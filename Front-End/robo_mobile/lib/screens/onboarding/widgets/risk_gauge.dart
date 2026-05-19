import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Maps a 0-100 risk value to the needle's rotation angle in radians.
/// Pivot is at the center of the semicircle; -π/2 points left (low risk),
/// +π/2 points right (high risk). Out-of-range inputs are clamped.
double riskGaugeNeedleAngle(double value) {
  final clamped = value.clamp(0.0, 100.0);
  return (clamped / 100) * math.pi - math.pi / 2;
}

/// Semicircle gauge with three colored zones (green/yellow/red) and a
/// rotating needle. Caller-driven `value` (no internal animation) so the
/// story canvas can lerp it from PageView scroll position.
class RiskGauge extends StatelessWidget {
  final double value;
  final double size;
  final bool showLabel;

  const RiskGauge({
    super.key,
    required this.value,
    this.size = 140,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final labelHeight = showLabel ? 30.0 : 0.0;
    return SizedBox(
      width: size,
      height: size / 2 + labelHeight + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size / 2 + 4,
            child: CustomPaint(
              painter: _RiskGaugePainter(value: value),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 4),
            Text(
              '리스크 ${value.round()}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: WeRoboColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double value;

  _RiskGaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final radius = size.width / 2 - 6;
    final thickness = size.width * 0.13;
    final center = Offset(centerX, size.height - 4);

    // Three arc zones along 180°: green [0,35], yellow [35,65], red [65,100].
    final rect = Rect.fromCircle(center: center, radius: radius);
    void arc(double startFrac, double endFrac, Color color) {
      final startAngle = math.pi + math.pi * startFrac; // pi = left edge
      final sweepAngle = math.pi * (endFrac - startFrac);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    arc(0.0, 0.35, WeRoboColors.accent);   // green
    arc(0.35, 0.65, WeRoboColors.warning); // yellow
    arc(0.65, 1.0, WeRoboColors.dangerRed);

    // Pivot dot
    final pivotPaint = Paint()..color = WeRoboColors.textPrimary;
    canvas.drawCircle(center, size.width * 0.04, pivotPaint);

    // Needle
    final angle = riskGaugeNeedleAngle(value);
    final needleLength = radius - thickness / 2 - 4;
    final needlePaint = Paint()
      ..color = WeRoboColors.textPrimary
      ..style = PaintingStyle.fill;
    final tip = Offset(
      center.dx + needleLength * math.sin(angle),
      center.dy - needleLength * math.cos(angle),
    );
    final baseHalf = size.width * 0.025;
    final basePerp = angle + math.pi / 2;
    final baseA = Offset(
      center.dx + baseHalf * math.sin(basePerp),
      center.dy - baseHalf * math.cos(basePerp),
    );
    final baseB = Offset(
      center.dx - baseHalf * math.sin(basePerp),
      center.dy + baseHalf * math.cos(basePerp),
    );
    final path = Path()
      ..moveTo(baseA.dx, baseA.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(baseB.dx, baseB.dy)
      ..close();
    canvas.drawPath(path, needlePaint);
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
