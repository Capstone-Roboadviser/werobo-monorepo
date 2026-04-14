import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class DigestLoading extends StatefulWidget {
  const DigestLoading({super.key});

  @override
  State<DigestLoading> createState() => _DigestLoadingState();
}

class _DigestLoadingState extends State<DigestLoading>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _timer;
  late final AnimationController _pulseController;

  static const _steps = [
    '포트폴리오 수익률 계산',
    '상승/하락 기여 종목 분석',
    '관련 뉴스 수집 및 검증 중',
    '요약 생성 중',
  ];

  static const _delays = [1000, 1000, 1500, 2000];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _advanceStep();
  }

  void _advanceStep() {
    if (_currentStep >= _steps.length - 1) return;
    _timer = Timer(
      Duration(milliseconds: _delays[_currentStep]),
      () {
        if (mounted) {
          setState(() => _currentStep++);
          _advanceStep();
        }
      },
    );
  }

  void completeAllSteps() {
    _timer?.cancel();
    if (mounted) setState(() => _currentStep = _steps.length - 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + _pulseController.value * 0.08;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            WeRoboColors.primary
                                .withValues(alpha: 0.15),
                            WeRoboColors.primary
                                .withValues(alpha: 0.25),
                          ]
                        : [WeRoboColors.sky1, WeRoboColors.sky2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: WeRoboColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: WeRoboSpacing.xxl),
            Text(
              '다이제스트 생성 중',
              style: WeRoboTypography.heading3.copyWith(
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: WeRoboSpacing.sm),
            Text(
              'AI가 포트폴리오를 분석하고\n주간 리포트를 작성하고 있습니다',
              textAlign: TextAlign.center,
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textTertiary,
              ),
            ),
            const SizedBox(height: WeRoboSpacing.xxxxl),
            ...List.generate(_steps.length, (i) {
              final isDone = i < _currentStep;
              final isActive = i == _currentStep;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? tc.accent
                            : isActive
                                ? WeRoboColors.primary
                                : tc.border,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isDone ? '${_steps[i]} 완료' : _steps[i],
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: isDone
                            ? tc.accent
                            : isActive
                                ? WeRoboColors.primary
                                : tc.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
