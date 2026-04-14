import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class GlowingBorder extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double borderRadius;
  final bool shrinkWrap;

  const GlowingBorder({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2200),
    this.borderRadius = WeRoboColors.radiusXL,
    this.shrinkWrap = false,
  });

  @override
  State<GlowingBorder> createState() => _GlowingBorderState();
}

class _GlowingBorderState extends State<GlowingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.shrinkWrap ? null : double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _GlowingBorderPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _GlowingBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  _GlowingBorderPainter({
    required this.progress,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius),
    );

    // Subtle full border (always visible)
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = WeRoboColors.primary.withValues(alpha: 0.12);
    canvas.drawRRect(rrect, basePaint);

    // Animated glow arc - bright, visible traveling segment
    final sweepGradient = SweepGradient(
      transform: GradientRotation(progress * 2 * pi),
      colors: const [
        Color(0x0020A7DB),
        Color(0x6620A7DB),
        Color(0xFF20A7DB),
        Color(0xFF20A7DB),
        Color(0x6620A7DB),
        Color(0x0020A7DB),
        Color(0x0020A7DB),
      ],
      stops: const [
        0.0,
        0.05,
        0.10,
        0.18,
        0.23,
        0.28,
        1.0,
      ],
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = sweepGradient.createShader(rect);
    canvas.drawRRect(rrect, glowPaint);

    // Outer glow (soft bloom effect)
    final outerRrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius + 1),
    );
    final outerGlow = SweepGradient(
      transform: GradientRotation(progress * 2 * pi),
      colors: const [
        Color(0x0020A7DB),
        Color(0x1A20A7DB),
        Color(0x4D20A7DB),
        Color(0x4D20A7DB),
        Color(0x1A20A7DB),
        Color(0x0020A7DB),
        Color(0x0020A7DB),
      ],
      stops: const [
        0.0,
        0.05,
        0.10,
        0.18,
        0.23,
        0.28,
        1.0,
      ],
    );
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..shader = outerGlow.createShader(rect)
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawRRect(outerRrect, outerPaint);
  }

  @override
  bool shouldRepaint(_GlowingBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
