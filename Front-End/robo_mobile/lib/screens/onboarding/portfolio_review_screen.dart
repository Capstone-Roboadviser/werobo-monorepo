import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
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
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: tc.background,
        elevation: 0,
        leading: const BackButton(),
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
  const _CompareVolatilityTabs({
    required this.controller,
    required this.selection,
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
              _CompareTabBody(selection: selection),
              _VolatilityTabBody(selection: selection),
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
/// The frontier preview only carries scalar volatility/expected-return
/// values — it has no time-series. Real series need a follow-up call to
/// `fetchComparisonBacktest` (or equivalent) which Task 3.5 will wire.
/// For now we render `PortfolioComparisonChart`'s empty state so the tab
/// reads honestly instead of showing fabricated data.
class _CompareTabBody extends StatelessWidget {
  final OnboardingFrontierSelection selection;
  const _CompareTabBody({required this.selection});

  @override
  Widget build(BuildContext context) {
    final series = _seriesFromPreview(selection);
    final timeAxis = _timeAxisFromPreview(selection);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PortfolioComparisonChart(
        seriesData: series,
        timeAxis: timeAxis,
        initialRange: TimeRange.threeYear,
        enablePinchZoom: true,
        enableHorizontalDrag: true,
      ),
    );
  }

  // TODO(backend): wire via fetchComparisonBacktest (or equivalent).
  // The frontier preview itself has no time-series, so until the backtest
  // API is reused on this screen the chart shows its empty state.
  List<List<double>> _seriesFromPreview(
    OnboardingFrontierSelection selection,
  ) =>
      const <List<double>>[];

  List<DateTime> _timeAxisFromPreview(
    OnboardingFrontierSelection selection,
  ) =>
      const <DateTime>[];
}

/// Second tab: portfolio rolling 60d σ overlaid against the market's
/// rolling 60d σ. The frontier preview only carries scalar volatility
/// per point, so until a dedicated volatility-time-series endpoint
/// lands the chart degrades to its empty state.
class _VolatilityTabBody extends StatelessWidget {
  final OnboardingFrontierSelection selection;
  const _VolatilityTabBody({required this.selection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PortfolioComparisonChart(
        seriesData: _volatilitySeries(selection),
        timeAxis: _volatilityTimeAxis(selection),
        seriesLabels: const ['포트폴리오', '시장'],
        initialRange: TimeRange.threeYear,
        enablePinchZoom: true,
        enableHorizontalDrag: true,
      ),
    );
  }

  List<List<double>> _volatilitySeries(OnboardingFrontierSelection selection) {
    // TODO(backend): wire portfolio rolling 60d σ + market rolling 60d σ.
    // Today the backend exposes only scalar volatility per frontier point;
    // a separate endpoint will provide the time series.
    return const [];
  }

  List<DateTime> _volatilityTimeAxis(OnboardingFrontierSelection selection) {
    // TODO(backend): wire date axis aligned with the volatility series.
    return const [];
  }
}
