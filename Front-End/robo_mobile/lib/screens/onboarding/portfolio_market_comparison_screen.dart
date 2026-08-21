import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import '../home/home_shell.dart';
import 'onboarding_screen.dart' show OnboardingFrontierSelection;
import 'widgets/portfolio_charts.dart';

typedef PortfolioMarketSelectionResolver
    = Future<MobileFrontierSelectionResponse> Function({
  required PortfolioState state,
  required OnboardingFrontierSelection selection,
});

typedef PortfolioMarketAccountCreator = Future<MobileAccountDashboard>
    Function({
  required PortfolioState state,
  required MobileFrontierSelectionResponse selection,
  required double initialCashAmount,
  required DateTime startedAt,
});

typedef PortfolioMarketBacktestFetcher
    = Future<MobileComparisonBacktestResponse> Function({
  required PortfolioState state,
  required OnboardingFrontierSelection selection,
});

typedef PortfolioMarketHomePrefetcher = Future<void> Function(
  PortfolioState state,
);

const double _initialPortfolioCashAmount = 10000000;

class PortfolioMarketComparisonScreen extends StatefulWidget {
  final OnboardingFrontierSelection selection;
  final DateTime Function()? now;
  final PortfolioMarketSelectionResolver? resolveFrontierSelection;
  final PortfolioMarketAccountCreator? createInitialAccount;
  final PortfolioMarketBacktestFetcher? fetchComparisonBacktest;
  final PortfolioMarketHomePrefetcher? prefetchHomeBacktest;

  const PortfolioMarketComparisonScreen({
    super.key,
    required this.selection,
    this.now,
    this.resolveFrontierSelection,
    this.createInitialAccount,
    this.fetchComparisonBacktest,
    this.prefetchHomeBacktest,
  });

  @override
  State<PortfolioMarketComparisonScreen> createState() =>
      _PortfolioMarketComparisonScreenState();
}

class _PortfolioMarketComparisonScreenState
    extends State<PortfolioMarketComparisonScreen> {
  MobileComparisonBacktestResponse? _comparisonBacktest;
  bool _didRequestComparisonBacktest = false;
  bool _isConfirming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestComparisonBacktest) return;
    _didRequestComparisonBacktest = true;
    final state = PortfolioStateProvider.of(context);
    final existingBacktest = state.backtest;
    if (existingBacktest != null) {
      _comparisonBacktest = existingBacktest;
    } else {
      unawaited(_fetchComparisonBacktest(state));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final backtest =
        _comparisonBacktest ?? PortfolioStateProvider.of(context).backtest;
    final chartData = _comparisonChartData(
      backtest,
      selection: widget.selection,
    );
    final summary = _ComparisonSummary.fromBacktest(
      backtest,
      selection: widget.selection,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _StepDots(activeIndex: 3),
                      const SizedBox(height: 28),
                      Text(
                        '같은 기간,\n시장과 비교해 보세요',
                        style: WeRoboTypography.heading1.themed(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '제안 포트폴리오가 누적 수익률, 변동성, MDD에서 어떤 차이를 보였는지 한눈에 확인할 수 있습니다.',
                        style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ComparisonCard(
                        chartData: chartData,
                        periodText: _periodText(
                          backtest,
                          selection: widget.selection,
                        ),
                      ),
                      const SizedBox(height: 14),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.show_chart_rounded,
                                label: '누적 수익률',
                                portfolioValue:
                                    _signedPct(summary.portfolioReturn),
                                marketValue: _signedPct(summary.marketReturn),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.shield_rounded,
                                label: '변동성',
                                portfolioValue:
                                    _plainPct(summary.portfolioVolatility),
                                marketValue:
                                    _plainPct(summary.marketVolatility),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                icon: Icons.keyboard_double_arrow_down_rounded,
                                label: 'MDD',
                                portfolioValue:
                                    _signedPct(summary.portfolioMdd),
                                marketValue: _signedPct(summary.marketMdd),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _RiskNote(),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: WeRoboSpacing.bottomButton,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isConfirming ? null : _confirm,
                      child: _isConfirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WeRoboColors.white,
                              ),
                            )
                          : const Text('다음'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchComparisonBacktest(PortfolioState state) async {
    try {
      final fetcher = widget.fetchComparisonBacktest;
      final response = fetcher != null
          ? await fetcher(state: state, selection: widget.selection)
          : await MobileBackendApi.instance.fetchComparisonBacktest(
              preferredDataSource: widget.selection.dataSource,
              investmentHorizon:
                  widget.selection.preview?.resolvedProfile.investmentHorizon ??
                      state.recommendation?.resolvedProfile.investmentHorizon ??
                      'medium',
              selectedPointIndex: widget.selection.selectedPointIndex,
              targetVolatility: _apiTargetVolatility(widget.selection),
            );
      if (!mounted) return;
      state.setBacktest(response);
      setState(() {
        _comparisonBacktest = response;
      });
    } catch (_) {
      // Keep the instant fallback chart on screen if the live comparison fails.
    }
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    final state = PortfolioStateProvider.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final startedAt = PortfolioState.prototypeAccountStartDate(
      widget.now?.call() ?? DateTime.now(),
    );
    state.recordFrontierSelection(widget.selection);
    setState(() {
      _isConfirming = true;
    });
    try {
      final frontierSelection = await _resolveFrontierSelectionForAccount(
        state,
      );
      if (!mounted) return;
      state.setFrontierSelection(frontierSelection);
      final dashboard = await _createInitialAccountForSelection(
        state: state,
        selection: frontierSelection,
        startedAt: startedAt,
      );
      if (!mounted) return;
      state.setAccountDashboard(dashboard);
      final prefetcher =
          widget.prefetchHomeBacktest ?? HomeShell.prefetchBacktest;
      unawaited(prefetcher(state).catchError((_) {}));
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('계좌를 만드는 중 문제가 발생했어요. 다시 시도해 주세요.'),
        ),
      );
    }
  }

  Future<MobileFrontierSelectionResponse> _resolveFrontierSelectionForAccount(
    PortfolioState state,
  ) {
    final resolver = widget.resolveFrontierSelection;
    if (resolver != null) {
      return resolver(state: state, selection: widget.selection);
    }
    return MobileBackendApi.instance.fetchFrontierSelection(
      propensityScore:
          widget.selection.preview?.resolvedProfile.propensityScore ?? 45.0,
      targetVolatility: _apiTargetVolatility(widget.selection),
      pointIndex: widget.selection.selectedPointIndex,
      investmentHorizon:
          widget.selection.preview?.resolvedProfile.investmentHorizon ??
              state.recommendation?.resolvedProfile.investmentHorizon ??
              'medium',
      preferredDataSource: widget.selection.dataSource,
      asOfDate: widget.selection.asOfDate,
    );
  }

  Future<MobileAccountDashboard> _createInitialAccountForSelection({
    required PortfolioState state,
    required MobileFrontierSelectionResponse selection,
    required DateTime startedAt,
  }) {
    final creator = widget.createInitialAccount;
    if (creator != null) {
      return creator(
        state: state,
        selection: selection,
        initialCashAmount: _initialPortfolioCashAmount,
        startedAt: startedAt,
      );
    }
    return state.createPrototypeAccount(
      selection: selection,
      initialCashAmount: _initialPortfolioCashAmount,
      startedAt: startedAt,
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final ({
    List<List<double>> seriesData,
    List<DateTime> timeAxis,
    List<String> labels,
  }) chartData;
  final String periodText;

  const _ComparisonCard({
    required this.chartData,
    required this.periodText,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '누적 수익률을 비교',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                periodText,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: PortfolioComparisonChart(
              seriesData: chartData.seriesData,
              timeAxis: chartData.timeAxis,
              seriesLabels: chartData.labels,
              initialRange: TimeRange.all,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String portfolioValue;
  final String marketValue;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.portfolioValue,
    required this.marketValue,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      key: Key('comparison_metric_$label'),
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: WeRoboColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: WeRoboColors.primary),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              portfolioValue,
              style: WeRoboTypography.number.copyWith(
                color: WeRoboColors.primaryDark,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '시장 지수 $marketValue',
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskNote extends StatelessWidget {
  const _RiskNote();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeRoboColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WeRoboColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 19,
              color: WeRoboColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '과거 성과는 미래 수익을 보장하지 않지만, 위험 관리 방식은 확인할 수 있습니다.',
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int activeIndex;

  const _StepDots({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final active = index == activeIndex;
        return Container(
          margin: const EdgeInsets.only(right: 12),
          width: active ? 18 : 12,
          height: active ? 18 : 12,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? WeRoboColors.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: WeRoboColors.primary),
          ),
          child: active
              ? Text(
                  '${index + 1}',
                  style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        );
      }),
    );
  }
}

class _ComparisonSummary {
  final double portfolioReturn;
  final double marketReturn;
  final double portfolioVolatility;
  final double marketVolatility;
  final double portfolioMdd;
  final double marketMdd;

  const _ComparisonSummary({
    required this.portfolioReturn,
    required this.marketReturn,
    required this.portfolioVolatility,
    required this.marketVolatility,
    required this.portfolioMdd,
    required this.marketMdd,
  });

  factory _ComparisonSummary.fromBacktest(
    MobileComparisonBacktestResponse? response, {
    required OnboardingFrontierSelection selection,
  }) {
    final portfolioLine = response == null
        ? null
        : _findLine(response, preferredKey: 'selected') ??
            _findLine(response, preferredLabel: '포트폴리오');
    final marketLine = response == null
        ? null
        : _findLine(response, preferredKey: 'market') ??
            _findLine(response, preferredLabel: '시장');
    final portfolioReturn = _lastReturn(portfolioLine);
    final marketReturn = _lastReturn(marketLine);
    final fallbackPortfolioVolatility = selection.targetVolatility > 0
        ? selection.targetVolatility
        : selection.preview?.resolvedProfile.targetVolatility ?? 0.114;
    final portfolioVolatility =
        _annualizedVolatility(portfolioLine) ?? fallbackPortfolioVolatility;
    final marketVolatility =
        _annualizedVolatility(marketLine) ?? portfolioVolatility * 1.08;

    return _ComparisonSummary(
      portfolioReturn: portfolioReturn ?? selection.previewReturn,
      marketReturn:
          marketReturn ?? (portfolioReturn ?? selection.previewReturn) * 0.33,
      portfolioVolatility: portfolioVolatility,
      marketVolatility: marketVolatility,
      portfolioMdd: _maxDrawdown(portfolioLine) ?? -portfolioVolatility * 1.1,
      marketMdd: _maxDrawdown(marketLine) ?? -marketVolatility * 1.25,
    );
  }
}

extension on OnboardingFrontierSelection {
  double get previewReturn {
    final preview = this.preview;
    if (preview == null || preview.points.isEmpty) return 0.0;
    final position = preview.positionForPointIndex(selectedPointIndex);
    return preview.points[position].expectedReturn;
  }
}

({
  List<List<double>> seriesData,
  List<DateTime> timeAxis,
  List<String> labels,
}) _comparisonChartData(
  MobileComparisonBacktestResponse? response, {
  required OnboardingFrontierSelection selection,
}) {
  if (response == null || response.lines.isEmpty) {
    return _fallbackComparisonChartData(selection);
  }

  final axisLine = response.lines.firstWhere(
    (line) => line.points.isNotEmpty,
    orElse: () => response.lines.first,
  );
  if (axisLine.points.isEmpty) {
    return _fallbackComparisonChartData(selection);
  }
  final timeAxis = [for (final point in axisLine.points) point.date];
  final seriesData = <List<double>>[];
  final labels = <String>[];
  for (final line in response.lines.take(2)) {
    if (!_lineMatchesAxis(line, timeAxis)) continue;
    seriesData.add([for (final point in line.points) point.returnPct]);
    labels.add(line.label);
  }
  if (seriesData.isEmpty || labels.isEmpty) {
    return _fallbackComparisonChartData(selection);
  }
  return (
    seriesData: seriesData,
    timeAxis: timeAxis,
    labels: labels,
  );
}

({
  List<List<double>> seriesData,
  List<DateTime> timeAxis,
  List<String> labels,
}) _fallbackComparisonChartData(OnboardingFrontierSelection selection) {
  final end = selection.asOfDate ?? DateTime.now();
  final start = DateTime(end.year - 1, end.month, end.day);
  final portfolioReturn = selection.previewReturn;
  final marketReturn = portfolioReturn * 0.33;
  return (
    seriesData: [
      [0, portfolioReturn],
      [0, marketReturn],
    ],
    timeAxis: [start, end],
    labels: const ['포트폴리오', '시장'],
  );
}

bool _lineMatchesAxis(MobileComparisonLine line, List<DateTime> timeAxis) {
  if (line.points.length != timeAxis.length) return false;
  for (var i = 0; i < timeAxis.length; i++) {
    if (line.points[i].date != timeAxis[i]) return false;
  }
  return true;
}

MobileComparisonLine? _findLine(
  MobileComparisonBacktestResponse response, {
  String? preferredKey,
  String? preferredLabel,
}) {
  for (final line in response.lines) {
    if (preferredKey != null && line.key == preferredKey) return line;
    if (preferredLabel != null && line.label.contains(preferredLabel)) {
      return line;
    }
  }
  return null;
}

double? _lastReturn(MobileComparisonLine? line) {
  final points = line?.points;
  if (points == null || points.isEmpty) return null;
  return points.last.returnPct;
}

double? _maxDrawdown(MobileComparisonLine? line) {
  final points = line?.points;
  if (points == null || points.length < 2) return null;
  var peak = 1 + points.first.returnPct;
  var maxDrawdown = 0.0;
  for (final point in points) {
    final value = 1 + point.returnPct;
    peak = math.max(peak, value);
    if (peak <= 0) continue;
    maxDrawdown = math.min(maxDrawdown, (value / peak) - 1);
  }
  return maxDrawdown;
}

double? _annualizedVolatility(MobileComparisonLine? line) {
  final points = line?.points;
  if (points == null || points.length < 3) return null;
  final returns = <double>[];
  for (var i = 1; i < points.length; i++) {
    final previousBase = 1 + points[i - 1].returnPct;
    final currentBase = 1 + points[i].returnPct;
    if (previousBase <= 0 || currentBase <= 0) return null;
    returns.add((currentBase / previousBase) - 1);
  }
  if (returns.length < 2) return null;
  final mean = returns.reduce((a, b) => a + b) / returns.length;
  final variance = returns
          .map((value) => math.pow(value - mean, 2).toDouble())
          .reduce((a, b) => a + b) /
      (returns.length - 1);
  return math.sqrt(variance) * math.sqrt(252);
}

String _periodText(
  MobileComparisonBacktestResponse? response, {
  required OnboardingFrontierSelection selection,
}) {
  if (response == null) {
    final end = selection.asOfDate ?? DateTime.now();
    final start = DateTime(end.year - 1, end.month, end.day);
    return '기간: ${_ym(start)} ~ ${_ym(end)}';
  }
  return '기간: ${_ym(response.startDate)} ~ ${_ym(response.endDate)}';
}

String _ym(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}';
}

String _signedPct(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${(value * 100).toStringAsFixed(1)}%';
}

String _plainPct(double value) => '${(value * 100).toStringAsFixed(1)}%';

double? _apiTargetVolatility(OnboardingFrontierSelection selection) =>
    selection.targetVolatility > 0 ? selection.targetVolatility : null;
