import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'result_screen.dart';

class PortfolioLoadingScreen extends StatefulWidget {
  final double dotT;

  const PortfolioLoadingScreen({super.key, required this.dotT});

  @override
  State<PortfolioLoadingScreen> createState() => _PortfolioLoadingScreenState();
}

class _PortfolioLoadingScreenState extends State<PortfolioLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _rotationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ),
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _progressController.forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    PortfolioResultScreen(dotT: widget.dotT),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                _progressAnimation,
                _rotationController,
              ]),
              builder: (context, _) {
                final percent = (_progressAnimation.value * 100).toInt();
                return SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: _LoadingRingPainter(
                      progress: _progressAnimation.value,
                      rotation: _rotationController.value,
                    ),
                    child: Center(
                      child: Text(
                        '$percent%',
                        style: WeRoboTypography.number.copyWith(
                          fontSize: 36,
                          color: WeRoboColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              '최적 포트폴리오를 찾는 중...',
              style: WeRoboTypography.body.copyWith(
                color: WeRoboColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '잠시만 기다려 주세요',
              style: WeRoboTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingRingPainter extends CustomPainter {
  final double progress;
  final double rotation;

  _LoadingRingPainter({required this.progress, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = WeRoboColors.dotInactive.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = WeRoboColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    if (progress < 1.0) {
      final spinPaint = Paint()
        ..color = WeRoboColors.primaryLight.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        rotation * 2 * pi - pi / 2,
        pi / 3,
        false,
        spinPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoadingRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation;
  }
}
