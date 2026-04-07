import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../services/mobile_backend_api.dart';
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
  MobileRecommendationResponse? _recommendation;
  String? _errorMessage;
  bool _animationFinished = false;
  bool _requestFinished = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 4000),
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

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationFinished = true;
        _tryProceed();
      }
    });

    _progressController.forward();
    _loadRecommendation();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendation() async {
    setState(() {
      _errorMessage = null;
      _recommendation = null;
    });
    _requestFinished = false;

    try {
      final recommendation =
          await MobileBackendApi.instance.fetchRecommendation(
        propensityScore: widget.dotT * 100,
      );
      if (recommendation.portfolios.isEmpty) {
        throw const MobileBackendException('추천 포트폴리오가 아직 준비되지 않았어요.');
      }
      if (!mounted) {
        return;
      }

      _requestFinished = true;
      setState(() {
        _recommendation = recommendation;
      });
      _tryProceed();
    } catch (error) {
      if (!mounted) {
        return;
      }

      // Fall back to hardcoded portfolio data so the demo always works
      final fallback = _buildFallbackRecommendation();
      _requestFinished = true;
      setState(() {
        _recommendation = fallback;
      });
      _tryProceed();
    }
  }

  MobileRecommendationResponse _buildFallbackRecommendation() {
    final type = InvestmentType.fromDotT(widget.dotT);
    final categories = PortfolioData.categoriesFor(type);
    final details = PortfolioData.detailsFor(type);
    final (risk, returnRate) = PortfolioData.statsFor(type);

    final riskVal = double.parse(risk.replaceAll('%', '')) / 100;
    final returnVal = double.parse(returnRate.replaceAll('%', '')) / 100;

    MobilePortfolioRecommendation buildPortfolio(InvestmentType t) {
      final cats = PortfolioData.categoriesFor(t);
      final dets = PortfolioData.detailsFor(t);
      final (r, ret) = PortfolioData.statsFor(t);
      return MobilePortfolioRecommendation(
        code: t.name,
        label: t.label,
        portfolioId: 'fallback-${t.name}',
        targetVolatility: double.parse(r.replaceAll('%', '')) / 100,
        expectedReturn: double.parse(ret.replaceAll('%', '')) / 100,
        volatility: double.parse(r.replaceAll('%', '')) / 100,
        sharpeRatio: 0,
        sectorAllocations: [
          for (final cat in cats)
            MobileSectorAllocation(
              assetCode: cat.name,
              assetName: cat.name,
              weight: cat.percentage / 100,
              riskContribution: 0,
            ),
        ],
        stockAllocations: [
          for (final detail in dets)
            for (final ticker in detail.tickers)
              MobileStockAllocation(
                ticker: ticker.symbol,
                name: ticker.name,
                sectorCode: detail.category.name,
                sectorName: detail.category.name,
                weight: ticker.percentage / 100,
              ),
        ],
      );
    }

    return MobileRecommendationResponse(
      resolvedProfile: MobileResolvedProfile(
        code: type.name,
        label: type.label,
        propensityScore: widget.dotT * 100,
        targetVolatility: riskVal,
        investmentHorizon: 'medium',
      ),
      recommendedPortfolioCode: type.name,
      dataSource: 'fallback',
      portfolios: [
        for (final t in InvestmentType.values) buildPortfolio(t),
      ],
    );
  }

  void _tryProceed() {
    if (!_animationFinished ||
        !_requestFinished ||
        _recommendation == null ||
        _hasNavigated ||
        !mounted) {
      return;
    }

    _hasNavigated = true;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PortfolioResultScreen(
            recommendation: _recommendation!,
            selectedPortfolioCode: _recommendation!.recommendedPortfolioCode,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  void _retry() {
    _animationFinished = false;
    _requestFinished = false;
    _hasNavigated = false;
    _progressController.forward(from: 0);
    _loadRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorMessage != null;

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
              hasError ? '추천 포트폴리오를 불러오지 못했어요' : '최적 포트폴리오를 찾는 중...',
              style: WeRoboTypography.body.copyWith(
                color: WeRoboColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hasError ? _errorMessage! : '잠시만 기다려 주세요',
                style: WeRoboTypography.caption,
                textAlign: TextAlign.center,
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: _retry,
                  child: const Text('다시 시도'),
                ),
              ),
            ],
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
    return oldDelegate.progress != progress || oldDelegate.rotation != rotation;
  }
}
