import 'package:flutter/material.dart';
import '../models/chart_data.dart';
import '../models/mobile_backend_models.dart';
import '../models/portfolio_data.dart';

/// App-level state holder for the user's selected investment type
/// and the API recommendation data.
class PortfolioState extends ChangeNotifier {
  InvestmentType _type = InvestmentType.balanced;
  MobileRecommendationResponse? _recommendation;
  MobileComparisonBacktestResponse? _backtest;

  InvestmentType get type => _type;
  MobileRecommendationResponse? get recommendation => _recommendation;
  MobileComparisonBacktestResponse? get backtest => _backtest;

  /// The selected portfolio from the API recommendation.
  MobilePortfolioRecommendation? get selectedPortfolio {
    if (_recommendation == null) return null;
    for (final p in _recommendation!.portfolios) {
      if (p.investmentType == _type) return p;
    }
    return null;
  }

  /// Categories from API data.
  List<PortfolioCategory> get categories {
    return selectedPortfolio?.toCategories() ?? const [];
  }

  /// Category details from API data.
  List<PortfolioCategoryDetail> get categoryDetails {
    return selectedPortfolio?.toCategoryDetails() ?? const [];
  }

  void setType(InvestmentType newType) {
    if (_type != newType) {
      _type = newType;
      notifyListeners();
    }
  }

  void setRecommendation(MobileRecommendationResponse rec) {
    _recommendation = rec;
    notifyListeners();
  }

  void setBacktest(MobileComparisonBacktestResponse bt) {
    _backtest = bt;
    notifyListeners();
  }

  void setTypeAndRecommendation(
    InvestmentType newType,
    MobileRecommendationResponse rec,
  ) {
    _type = newType;
    _recommendation = rec;
    notifyListeners();
  }

  /// Portfolio value points derived from API backtest data.
  /// Converts return % to ₩ values using a base investment.
  List<ChartPoint> portfolioValuePoints({
    double baseInvestment = 10000000,
  }) {
    if (_backtest == null) return const [];
    final code = _type.riskCode;
    MobileComparisonLine? line;
    for (final l in _backtest!.lines) {
      if (l.key == code) {
        line = l;
        break;
      }
    }
    if (line == null || line.points.isEmpty) return const [];
    return line.points
        .map((p) => ChartPoint(
              date: p.date,
              value: baseInvestment * (1 + p.returnPct),
            ))
        .toList();
  }

  /// Comparison lines mapped to ChartLine for chart widgets.
  List<ChartLine> get comparisonLines {
    if (_backtest == null) return const [];
    return _backtest!.lines
        .map((line) => ChartLine(
              key: line.key,
              label: line.label,
              color: parseBackendHexColor(line.color),
              dashed: line.style != 'solid',
              points: line.points
                  .map((p) =>
                      ChartPoint(date: p.date, value: p.returnPct))
                  .toList(),
            ))
        .toList();
  }

  List<DateTime> get rebalanceDates =>
      _backtest?.rebalanceDates ?? const [];

  /// Convenience: derive type from efficient frontier dot position
  void setFromDotT(double dotT) {
    setType(InvestmentType.fromDotT(dotT));
  }
}

/// Access the portfolio state from any widget tree
class PortfolioStateProvider extends InheritedNotifier<PortfolioState> {
  const PortfolioStateProvider({
    super.key,
    required PortfolioState state,
    required super.child,
  }) : super(notifier: state);

  static PortfolioState of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<PortfolioStateProvider>();
    assert(provider != null, 'No PortfolioStateProvider in widget tree');
    return provider!.notifier!;
  }
}
