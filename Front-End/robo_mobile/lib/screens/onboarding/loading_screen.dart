import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import 'frontier_selection_resolver.dart';
import '../../models/portfolio_data.dart';
import '../../services/mobile_backend_api.dart';
import 'result_screen.dart';

class PortfolioLoadingScreen extends StatefulWidget {
  final double dotT;
  final int? selectedPointIndex;
  final double? targetVolatility;
  final String? previewDataSource;
  final DateTime? asOfDate;
  final Future<MobileFrontierPreviewResponse?>? previewFuture;

  const PortfolioLoadingScreen({
    super.key,
    required this.dotT,
    this.selectedPointIndex,
    this.targetVolatility,
    this.previewDataSource,
    this.asOfDate,
    this.previewFuture,
  });

  @override
  State<PortfolioLoadingScreen> createState() => _PortfolioLoadingScreenState();
}

class _PortfolioLoadingScreenState extends State<PortfolioLoadingScreen>
    with TickerProviderStateMixin {
  static const Duration _previewResolutionTimeout = Duration(seconds: 2);
  late AnimationController _progressController;
  late AnimationController _rotationController;
  late Animation<double> _progressAnimation;
  MobileFrontierSelectionResponse? _frontierSelection;
  MobileFrontierSelectionResponse? _fallbackSelection;
  String? _errorMessage;
  bool _animationFinished = false;
  bool _requestFinished = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    logPageEnter('PortfolioLoadingScreen', {
      'dotT': widget.dotT.toStringAsFixed(2),
      'point_index': widget.selectedPointIndex,
      'target_volatility': widget.targetVolatility?.toStringAsFixed(4),
      'as_of_date': widget.asOfDate?.toIso8601String().split('T').first,
    });

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
    _loadSelection();
  }

  @override
  void dispose() {
    logPageExit('PortfolioLoadingScreen');
    _progressController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadSelection() async {
    logAction('load frontier selection', {
      'dotT': widget.dotT.toStringAsFixed(2),
      'point_index': widget.selectedPointIndex,
    });
    setState(() {
      _errorMessage = null;
      _frontierSelection = null;
      _fallbackSelection = null;
    });
    _requestFinished = false;

    try {
      final selectionRequest = await _resolveSelectionRequest();
      if (!mounted) {
        return;
      }
      final frontierSelection =
          await MobileBackendApi.instance.fetchFrontierSelection(
        propensityScore: widget.dotT * 100,
        pointIndex: selectionRequest.pointIndex,
        targetVolatility: selectionRequest.targetVolatility,
        preferredDataSource: selectionRequest.preferredDataSource,
        asOfDate: selectionRequest.asOfDate,
      );
      if (!mounted) {
        return;
      }

      _requestFinished = true;
      setState(() {
        _frontierSelection = frontierSelection;
      });
      logAction('frontier selection resolved', {
        'classification': frontierSelection.classificationCode,
        'selected_point_index': frontierSelection.selectedPointIndex,
        'target_volatility':
            frontierSelection.selectedTargetVolatility.toStringAsFixed(4),
        'dataSource': frontierSelection.dataSource,
        'as_of_date':
            frontierSelection.asOfDate?.toIso8601String().split('T').first,
      });
      _tryProceed();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _requestFinished = true;
      setState(() {
        _errorMessage = _buildUiErrorMessage(error);
        _fallbackSelection = _buildFallbackSelection();
      });
      logAction('frontier selection failed', {
        'error': error.toString(),
      });
    }
  }

  Future<OnboardingSelectionRequest> _resolveSelectionRequest() async {
    if (widget.previewDataSource != null || widget.previewFuture == null) {
      return resolveOnboardingSelectionRequest(
        normalizedT: widget.dotT,
        selectedPointIndex: widget.selectedPointIndex,
        targetVolatility: widget.targetVolatility,
        preferredDataSource: widget.previewDataSource,
        asOfDate: widget.asOfDate,
      );
    }

    final preview = await widget.previewFuture!.timeout(
      _previewResolutionTimeout,
      onTimeout: () {
        logAction('frontier preview future timed out before selection', {
          'timeout_ms': _previewResolutionTimeout.inMilliseconds,
        });
        return null;
      },
    );
    final request = resolveOnboardingSelectionRequest(
      normalizedT: widget.dotT,
      selectedPointIndex: widget.selectedPointIndex,
      targetVolatility: widget.targetVolatility,
      preferredDataSource: widget.previewDataSource,
      asOfDate: widget.asOfDate,
      preview: preview,
    );
    if (preview != null && request.preferredDataSource != null) {
      logAction('resolved frontier selection from preview', {
        'dataSource': request.preferredDataSource,
        'point_index': request.pointIndex,
        'target_volatility': request.targetVolatility?.toStringAsFixed(4),
      });
    }
    return request;
  }

  MobileFrontierSelectionResponse _buildFallbackSelection() {
    final type = InvestmentType.fromDotT(widget.dotT);
    final (risk, _) = PortfolioData.statsFor(type);

    final riskVal = double.parse(risk.replaceAll('%', '')) / 100;

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

    return MobileFrontierSelectionResponse(
      resolvedProfile: MobileResolvedProfile(
        code: type.name,
        label: type.label,
        propensityScore: widget.dotT * 100,
        targetVolatility: riskVal,
        investmentHorizon: 'medium',
      ),
      dataSource: 'fallback',
      asOfDate: widget.asOfDate,
      requestedTargetVolatility: riskVal,
      selectedTargetVolatility: riskVal,
      selectedPointIndex: widget.selectedPointIndex ?? 0,
      totalPointCount: 1,
      representativeCode: type.name,
      representativeLabel: type.label,
      portfolio: buildPortfolio(type),
    );
  }

  String _buildUiErrorMessage(Object error) {
    if (error is MobileBackendException) {
      if (error.attemptLogs.isNotEmpty) {
        return error.attemptLogs.join('\n');
      }
      return error.message;
    }
    return '선택 포트폴리오 API 호출에 실패했어요. 다시 시도하거나 데모로 계속 진행할 수 있어요.';
  }

  void _continueWithDemo() {
    final fallback = _fallbackSelection;
    if (fallback == null) {
      return;
    }
    logAction('continue with demo');
    setState(() {
      _frontierSelection = fallback;
      _errorMessage = null;
    });
    _tryProceed();
  }

  void _tryProceed() {
    if (!_animationFinished ||
        !_requestFinished ||
        _frontierSelection == null ||
        _hasNavigated ||
        !mounted) {
      return;
    }

    _hasNavigated = true;
    logAction('navigate loading -> result', {
      'selected': _frontierSelection!.classificationCode,
      'selected_point_index': _frontierSelection!.selectedPointIndex,
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PortfolioResultScreen(
            frontierSelection: _frontierSelection!,
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
    logAction('tap retry frontier selection');
    _animationFinished = false;
    _requestFinished = false;
    _hasNavigated = false;
    _progressController.forward(from: 0);
    _loadSelection();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: tc.background,
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
              hasError ? '선택 포트폴리오를 불러오지 못했어요' : '선택 포트폴리오를 찾는 중...',
              style: WeRoboTypography.body.copyWith(
                color: tc.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hasError ? _errorMessage! : '잠시만 기다려 주세요',
                style: WeRoboTypography.caption.themed(context),
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
              const SizedBox(height: 12),
              SizedBox(
                width: 180,
                child: OutlinedButton(
                  onPressed:
                      _fallbackSelection == null ? null : _continueWithDemo,
                  child: const Text('데모로 계속 보기'),
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
