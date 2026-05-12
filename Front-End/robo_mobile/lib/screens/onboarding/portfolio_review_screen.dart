import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import 'frontier_selection_resolver.dart';
import 'onboarding_screen.dart' show OnboardingFrontierSelection;
import 'widgets/asset_weight.dart';
import 'widgets/donut_chart.dart';
import 'widgets/portfolio_charts.dart';

/// Post-frontier confirmation screen. Layout per 2026-05-05 user notes
/// (and rev F–J 2026-05-04):
///   - Centered "포트폴리오 상세" page title
///   - Donut centered with tap-for-details (slice → asset breakdown)
///   - Tabs: 포트폴리오 비교 (default) / 변동성 (secondary)
///   - 3-year default time range with pinch-zoom
///   - Bottom CTA: 투자 확정
class PortfolioReviewScreen extends StatefulWidget {
  final OnboardingFrontierSelection selection;

  const PortfolioReviewScreen({super.key, required this.selection});

  @override
  State<PortfolioReviewScreen> createState() => _PortfolioReviewScreenState();
}

class _PortfolioReviewScreenState extends State<PortfolioReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<AssetWeight> _assets;
  late final List<DonutSegment> _segments;
  MobileComparisonBacktestResponse? _comparisonBacktest;
  bool _didRequestComparisonBacktest = false;
  bool _isLoadingComparisonBacktest = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _assets = resolveAssetWeights(widget.selection);
    _segments = _assets
        .map((a) => DonutSegment(
              weight: a.weight,
              color: WeRoboColors.assetColor(a.cls),
              label: a.label,
              tickers: [
                // The frontier preview only carries the slice's overall
                // weight, so we split it evenly across the constituent
                // tickers. Once a per-ticker weight feed is wired this can
                // be replaced with the real values.
                if (a.tickers.isNotEmpty)
                  for (final t in a.tickers)
                    DonutTicker(
                      symbol: t,
                      weight: a.weight / a.tickers.length,
                    ),
              ],
            ))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestComparisonBacktest) {
      return;
    }
    _didRequestComparisonBacktest = true;
    final state = PortfolioStateProvider.of(context);
    final existingBacktest = state.backtest;
    if (existingBacktest != null) {
      _comparisonBacktest = existingBacktest;
      return;
    }
    _isLoadingComparisonBacktest = true;
    unawaited(_fetchComparisonBacktest(state));
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final comparisonBacktest = _comparisonBacktest ?? state.backtest;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: tc.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: Text(
          '포트폴리오 상세',
          style: WeRoboTypography.heading3.themed(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _DonutAndListColumn(segments: _segments),
              const SizedBox(height: 24),
              _CompareVolatilityTabs(
                controller: _tabController,
                selection: widget.selection,
                comparisonBacktest: comparisonBacktest,
                isLoadingComparisonBacktest: _isLoadingComparisonBacktest,
              ),
              const SizedBox(height: 100), // bottom CTA clearance
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: WeRoboSpacing.bottomButton,
          child: ElevatedButton(
            onPressed: () => _confirmInvestment(context),
            child: const Text('투자 확정'),
          ),
        ),
      ),
    );
  }

  void _confirmInvestment(BuildContext context) {
    final state = PortfolioStateProvider.of(context);
    state.recordFrontierSelection(widget.selection);
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  Future<void> _fetchComparisonBacktest(PortfolioState state) async {
    try {
      final response = await MobileBackendApi.instance.fetchComparisonBacktest(
        preferredDataSource: widget.selection.dataSource,
        investmentHorizon:
            widget.selection.preview?.resolvedProfile.investmentHorizon ??
                state.recommendation?.resolvedProfile.investmentHorizon ??
                'medium',
        selectedPointIndex: widget.selection.selectedPointIndex,
        targetVolatility: widget.selection.targetVolatility,
      );
      if (!mounted) {
        return;
      }
      state.setBacktest(response);
      setState(() {
        _comparisonBacktest = response;
        _isLoadingComparisonBacktest = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingComparisonBacktest = false;
      });
    }
  }
}

/// Donut chart only — the asset list was removed (rev J, 2026-05-04) because
/// tap-for-details on the donut now surfaces the same per-asset breakdown.
class _DonutAndListColumn extends StatelessWidget {
  final List<DonutSegment> segments;
  const _DonutAndListColumn({required this.segments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: DonutChart(
          segments: segments,
          centerLabel: '포트폴리오\n비중',
          compact: false, // full size — top of screen, anchors hierarchy
        ),
      ),
    );
  }
}

/// Tab control + bodies for the comparison vs volatility views.
/// Task 3.3 fills the comparison body; Task 3.4 will replace the
/// volatility stub.
class _CompareVolatilityTabs extends StatelessWidget {
  final TabController controller;
  final OnboardingFrontierSelection selection;
  final MobileComparisonBacktestResponse? comparisonBacktest;
  final bool isLoadingComparisonBacktest;
  const _CompareVolatilityTabs({
    required this.controller,
    required this.selection,
    required this.comparisonBacktest,
    required this.isLoadingComparisonBacktest,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: tc.card,
            borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
          ),
          child: TabBar(
            controller: controller,
            indicator: BoxDecoration(
              color: WeRoboColors.primary,
              borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
            ),
            labelColor: WeRoboColors.white,
            unselectedLabelColor: tc.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '포트폴리오 비교'),
              Tab(text: '변동성'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: TabBarView(
            controller: controller,
            children: [
              _CompareTabBody(
                comparisonBacktest: comparisonBacktest,
                isLoading: isLoadingComparisonBacktest,
              ),
              _VolatilityTabBody(
                selection: selection,
                comparisonBacktest: comparisonBacktest,
                isLoading: isLoadingComparisonBacktest,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// First tab: multi-line time-series comparing the user's portfolio
/// against the market and other benchmarks.
///
/// The frontier preview only carries scalar volatility/expected-return values,
/// so the parent screen fetches comparison-backtest data before this body draws
/// the chart.
class _CompareTabBody extends StatelessWidget {
  final MobileComparisonBacktestResponse? comparisonBacktest;
  final bool isLoading;
  const _CompareTabBody({
    required this.comparisonBacktest,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ChartLoadingState(message: '비교 데이터를 불러오는 중이에요');
    }
    final chartData = _comparisonChartData(comparisonBacktest);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PortfolioComparisonChart(
        seriesData: chartData.seriesData,
        timeAxis: chartData.timeAxis,
        seriesLabels: chartData.labels,
        initialRange: TimeRange.threeYear,
        enablePinchZoom: true,
        enableHorizontalDrag: true,
      ),
    );
  }

  ({
    List<List<double>> seriesData,
    List<DateTime> timeAxis,
    List<String> labels,
  }) _comparisonChartData(MobileComparisonBacktestResponse? response) {
    if (response == null || response.lines.isEmpty) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
        labels: const <String>[],
      );
    }

    MobileComparisonLine? axisLine;
    for (final line in response.lines) {
      if (line.points.isNotEmpty) {
        axisLine = line;
        break;
      }
    }
    if (axisLine == null) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
        labels: const <String>[],
      );
    }
    final timeAxis = [for (final point in axisLine.points) point.date];
    final seriesData = <List<double>>[];
    final labels = <String>[];
    for (final line in response.lines) {
      if (!_lineMatchesAxis(line, timeAxis)) {
        continue;
      }
      seriesData.add([for (final point in line.points) point.returnPct]);
      labels.add(line.label);
    }
    return (
      seriesData: seriesData,
      timeAxis: timeAxis,
      labels: labels,
    );
  }

  bool _lineMatchesAxis(MobileComparisonLine line, List<DateTime> timeAxis) {
    if (line.points.length != timeAxis.length) {
      return false;
    }
    for (var i = 0; i < timeAxis.length; i++) {
      if (line.points[i].date != timeAxis[i]) {
        return false;
      }
    }
    return true;
  }
}

class _ChartLoadingState extends StatelessWidget {
  final String message;

  const _ChartLoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: WeRoboColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Second tab: portfolio rolling σ overlaid against the market's rolling σ.
/// It derives per-period returns from the same comparison backtest payload
/// used by the first tab, so onboarding does not need a second fetch.
class _VolatilityTabBody extends StatelessWidget {
  final OnboardingFrontierSelection selection;
  final MobileComparisonBacktestResponse? comparisonBacktest;
  final bool isLoading;

  const _VolatilityTabBody({
    required this.selection,
    required this.comparisonBacktest,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ChartLoadingState(message: '변동성 데이터를 불러오는 중이에요');
    }
    final chartData = _volatilityChartData(comparisonBacktest);
    final fallbackChartData = chartData.seriesData.isEmpty
        ? _fallbackVolatilityChartData(selection, comparisonBacktest)
        : chartData;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PortfolioComparisonChart(
        seriesData: fallbackChartData.seriesData,
        timeAxis: fallbackChartData.timeAxis,
        seriesLabels: const ['포트폴리오', '시장'],
        initialRange: TimeRange.threeYear,
        rebaseToFirstValue: false,
        enablePinchZoom: true,
        enableHorizontalDrag: true,
      ),
    );
  }

  ({
    List<List<double>> seriesData,
    List<DateTime> timeAxis,
  }) _fallbackVolatilityChartData(
    OnboardingFrontierSelection selection,
    MobileComparisonBacktestResponse? response,
  ) {
    final targetVolatility = selection.targetVolatility;
    if (targetVolatility <= 0) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
      );
    }

    final dates = _fallbackDates(selection, response);
    if (dates.length < 2) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
      );
    }
    final marketVolatility = targetVolatility * 1.08;
    return (
      seriesData: [
        List<double>.filled(dates.length, targetVolatility),
        List<double>.filled(dates.length, marketVolatility),
      ],
      timeAxis: dates,
    );
  }

  List<DateTime> _fallbackDates(
    OnboardingFrontierSelection selection,
    MobileComparisonBacktestResponse? response,
  ) {
    if (response != null && response.startDate != response.endDate) {
      return [response.startDate, response.endDate];
    }
    final asOfDate = selection.asOfDate ?? response?.endDate ?? DateTime.now();
    return [
      asOfDate.subtract(const Duration(days: 365)),
      asOfDate,
    ];
  }

  ({
    List<List<double>> seriesData,
    List<DateTime> timeAxis,
  }) _volatilityChartData(MobileComparisonBacktestResponse? response) {
    if (response == null || response.lines.isEmpty) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
      );
    }

    final selectedLine = _findLine(response, preferredKey: 'selected');
    final marketLine = _findLine(response, preferredKey: 'market');
    if (selectedLine == null || marketLine == null) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
      );
    }

    final selectedVolatility = _rollingVolatilitySeries(selectedLine);
    final marketVolatility = _rollingVolatilitySeries(marketLine);
    if (selectedVolatility.values.isEmpty ||
        marketVolatility.values.isEmpty ||
        !_sameAxis(selectedVolatility.dates, marketVolatility.dates)) {
      return (
        seriesData: const <List<double>>[],
        timeAxis: const <DateTime>[],
      );
    }

    return (
      seriesData: [selectedVolatility.values, marketVolatility.values],
      timeAxis: selectedVolatility.dates,
    );
  }

  MobileComparisonLine? _findLine(
    MobileComparisonBacktestResponse response, {
    required String preferredKey,
  }) {
    for (final line in response.lines) {
      if (line.key == preferredKey && line.points.length >= 3) {
        return line;
      }
    }
    return null;
  }

  ({List<double> values, List<DateTime> dates}) _rollingVolatilitySeries(
    MobileComparisonLine line,
  ) {
    if (line.points.length < 3) {
      return (values: const <double>[], dates: const <DateTime>[]);
    }

    final returns = <double>[];
    final returnDates = <DateTime>[];
    for (var i = 1; i < line.points.length; i++) {
      final previousBase = 1 + line.points[i - 1].returnPct;
      final currentBase = 1 + line.points[i].returnPct;
      if (previousBase <= 0 || currentBase <= 0) {
        return (values: const <double>[], dates: const <DateTime>[]);
      }
      returns.add((currentBase / previousBase) - 1);
      returnDates.add(line.points[i].date);
    }

    const tradingDaysPerYear = 252.0;
    const rollingWindow = 60;
    final values = <double>[];
    final dates = <DateTime>[];
    for (var i = 1; i < returns.length; i++) {
      final start = math.max(0, i - rollingWindow + 1);
      final sample = returns.sublist(start, i + 1);
      final mean = sample.reduce((a, b) => a + b) / sample.length;
      final variance = sample
              .map((value) => math.pow(value - mean, 2).toDouble())
              .reduce((a, b) => a + b) /
          (sample.length - 1);
      values.add(math.sqrt(variance) * math.sqrt(tradingDaysPerYear));
      dates.add(returnDates[i]);
    }

    return (values: values, dates: dates);
  }

  bool _sameAxis(List<DateTime> left, List<DateTime> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }
}
