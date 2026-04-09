import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/portfolio_data.dart';
import 'widgets/chart_painters.dart';

class VolatilityScreen extends StatefulWidget {
  final InvestmentType type;
  final List<ChartPoint>? volatilityPoints;

  const VolatilityScreen({
    super.key,
    required this.type,
    this.volatilityPoints,
  });

  @override
  State<VolatilityScreen> createState() => _VolatilityScreenState();
}

class _VolatilityScreenState extends State<VolatilityScreen>
    with SingleTickerProviderStateMixin {
  int _range = 4;
  int? _touchIndex;
  late AnimationController _drawCtrl;

  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체'];
  static const _rangeDays = [7, 90, 365, 1825, 99999];

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    super.dispose();
  }

  List<ChartPoint> get _points {
    final all = widget.volatilityPoints ?? const <ChartPoint>[];
    if (all.isEmpty) return const <ChartPoint>[];
    final cutoff = DateTime.now()
        .subtract(Duration(days: _rangeDays[_range]));
    final filtered =
        all.where((p) => p.date.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  double _expectedVolatility() {
    return widget.type == InvestmentType.safe
        ? 0.084
        : widget.type == InvestmentType.balanced
            ? 0.108
            : 0.137;
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final points = _points;

    return Scaffold(
      backgroundColor: tc.surface,
      appBar: AppBar(
        backgroundColor: tc.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: tc.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '포트폴리오 변동성',
          style: WeRoboTypography.heading3
              .copyWith(color: tc.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Time range chips
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(_rangeLabels.length, (i) {
                  final active = _range == i;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _range = i);
                        _drawCtrl.forward(from: 0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? WeRoboColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _rangeLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? WeRoboColors.white
                                : tc.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              // Chart
              Expanded(
                child: points.isEmpty
                    ? const EmptyChartState(
                        message: '아직 차트 데이터를 준비하는 중입니다.',
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanUpdate: (d) {
                              if (points.isEmpty) return;
                              final x = d.localPosition.dx - 36;
                              final chartW =
                                  constraints.maxWidth - 36 - 12;
                              final idx = ((x / chartW) *
                                      (points.length - 1))
                                  .round()
                                  .clamp(0, points.length - 1);
                              setState(() => _touchIndex = idx);
                            },
                            onPanEnd: (_) =>
                                setState(() => _touchIndex = null),
                            onTapUp: (_) =>
                                setState(() => _touchIndex = null),
                            child: AnimatedBuilder(
                              animation: _drawCtrl,
                              builder: (context, _) {
                                return CustomPaint(
                                  size: Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                  painter: AreaChartPainter(
                                    points: points,
                                    progress: _drawCtrl.value,
                                    color: WeRoboColors.primary,
                                    touchIndex: _touchIndex,
                                    valueLabel: '변동성',
                                    baselineValue:
                                        _expectedVolatility(),
                                    baselineLabel: '기대 변동성',
                                    gridColor: tc.border,
                                    textTertiaryColor:
                                        tc.textTertiary,
                                    textPrimaryColor:
                                        tc.textPrimary,
                                    tooltipBackground: tc.surface,
                                    tooltipBorder: tc.border,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
