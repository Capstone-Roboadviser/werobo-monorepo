import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../../services/mobile_backend_api.dart';
import '../home/home_shell.dart';
import 'widgets/portfolio_charts.dart';
import 'widgets/vestor_pie_chart.dart';

class ConfirmationScreen extends StatefulWidget {
  final MobileRecommendationResponse recommendation;
  final String selectedPortfolioCode;
  final MobileFrontierSelectionResponse? frontierSelection;

  const ConfirmationScreen({
    super.key,
    required this.recommendation,
    required this.selectedPortfolioCode,
    this.frontierSelection,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedSector;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  late MobilePortfolioRecommendation _portfolio;
  late List<PortfolioCategoryDetail> _details;
  late List<PortfolioCategory> _categories;

  bool _isLoadingCharts = true;
  String? _chartError;
  List<ChartPoint>? _volatilityPoints;
  List<ChartPoint>? _performancePoints;
  List<ChartLine>? _comparisonLines;
  List<DateTime>? _rebalanceDates;
  MobileComparisonBacktestResponse? _backtestResponse;

  @override
  void initState() {
    super.initState();
    _portfolio = widget.frontierSelection?.portfolio ??
        widget.recommendation
            .portfolioByCodeOrRecommended(widget.selectedPortfolioCode);
    logPageEnter('ConfirmationScreen', {
      'selected': widget.selectedPortfolioCode,
      'portfolio': _portfolio.code,
    });
    _details = _portfolio.toCategoryDetails();
    _categories = _portfolio.toCategories();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _loadChartData();
  }

  @override
  void dispose() {
    logPageExit('ConfirmationScreen');
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoadingCharts = true;
      _chartError = null;
    });

    MobileVolatilityHistoryResponse? volatilityHistory;
    MobileComparisonBacktestResponse? comparisonBacktest;
    final errors = <String>[];

    // Card 2: volatility-history
    try {
      volatilityHistory =
          await MobileBackendApi.instance.fetchVolatilityHistory(
        riskProfile:
            widget.frontierSelection?.representativeCode ?? _portfolio.code,
        investmentHorizon:
            widget.recommendation.resolvedProfile.investmentHorizon,
      );
    } catch (error) {
      errors.add(_friendlyError(error));
    }

    // Card 7: comparison-backtest
    try {
      comparisonBacktest =
          await MobileBackendApi.instance.fetchComparisonBacktest();
    } catch (error) {
      errors.add(_friendlyError(error));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingCharts = false;
      _chartError = errors.isEmpty ? null : errors.first;

      if (volatilityHistory != null) {
        _volatilityPoints = volatilityHistory.points
            .map(
              (point) => ChartPoint(
                date: point.date,
                value: point.volatility,
              ),
            )
            .toList();
      }

      if (comparisonBacktest != null) {
        _backtestResponse = comparisonBacktest;
        _rebalanceDates = comparisonBacktest.rebalanceDates;
        _comparisonLines = comparisonBacktest.lines
            .map(
              (line) => ChartLine(
                key: line.key,
                label: line.label,
                color: parseBackendHexColor(line.color),
                dashed: line.style != 'solid',
                points: line.points
                    .map(
                      (point) => ChartPoint(
                        date: point.date,
                        value: point.returnPct,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();

        // Extract performance points from the portfolio's
        // return line in comparison-backtest.
        final code = _portfolio.code;
        for (final line in comparisonBacktest.lines) {
          if (line.key == code) {
            _performancePoints = line.points
                .map((p) => ChartPoint(
                      date: p.date,
                      value: p.returnPct,
                    ))
                .toList();
            break;
          }
        }
      }
    });
  }

  String _friendlyError(Object error) {
    if (error is MobileBackendException) {
      return error.message;
    }
    return '차트 데이터를 불러오지 못했어요.';
  }

  Widget _buildPieCenter() {
    final tc = WeRoboThemeColors.of(context);
    if (_selectedSector == null) {
      return Text(
        key: const ValueKey('default'),
        '포트폴리오\n비중',
        style: WeRoboTypography.heading3.copyWith(color: tc.textPrimary),
        textAlign: TextAlign.center,
      );
    }

    final detail = _details[_selectedSector!];
    final category = detail.category;

    return Column(
      key: ValueKey('sector_$_selectedSector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          category.name,
          style: WeRoboTypography.caption.copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${category.percentage.toInt()}%',
          style: WeRoboTypography.number.copyWith(
            color: tc.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        ...detail.tickers.take(3).map(
              (ticker) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${ticker.symbol} ${ticker.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontFamily: WeRoboFonts.english,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: tc.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildChartsSection() {
    final tc = WeRoboThemeColors.of(context);
    if (_isLoadingCharts) {
      return const Center(
        child: CircularProgressIndicator(color: WeRoboColors.primary),
      );
    }

    if (_volatilityPoints == null &&
        _performancePoints == null &&
        _comparisonLines == null) {
      return _ChartErrorState(
        message: _chartError ?? '차트 데이터를 불러오지 못했어요.',
        onRetry: _loadChartData,
      );
    }

    return Column(
      children: [
        if (_chartError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: WeRoboColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _chartError!,
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textPrimary,
                ),
              ),
            ),
          ),
        Expanded(
          child: PortfolioCharts(
            type: _portfolio.investmentType,
            volatilityPoints: _volatilityPoints,
            performancePoints: _performancePoints,
            comparisonLines: _comparisonLines,
            rebalanceDates: _rebalanceDates,
            useFallbackMock: false,
          ),
        ),
      ],
    );
  }

  void _confirmPortfolio() {
    logAction('confirm portfolio selection', {
      'selected': _portfolio.code,
    });
    final state = PortfolioStateProvider.of(context);
    final selectedType = widget.frontierSelection == null
        ? _portfolio.investmentType
        : investmentTypeFromRiskCode(
            widget.frontierSelection!.representativeCode ??
                widget.recommendation.recommendedPortfolioCode,
          );
    state.setTypeAndRecommendation(
      selectedType,
      widget.recommendation,
    );
    state.setFrontierSelection(widget.frontierSelection);
    if (_backtestResponse != null) {
      state.setBacktest(_backtestResponse!);
    }
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: WeRoboColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _portfolio.label,
                        style: WeRoboTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: WeRoboColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '포트폴리오 상세',
                        style: WeRoboTypography.heading3.themed(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: VestorPieChart(
                  categories: _categories,
                  size: 260,
                  onSectorSelected: (idx) {
                    setState(() => _selectedSector = idx);
                  },
                  centerBuilder: (_) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildPieCenter(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildChartsSection()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmPortfolio,
                    child: const Text('투자 확정'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChartErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '차트 데이터를 불러오지 못했어요',
              style: WeRoboTypography.heading3.themed(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: WeRoboTypography.bodySmall.themed(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
