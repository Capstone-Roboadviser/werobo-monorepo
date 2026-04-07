import 'package:flutter/material.dart';
import '../models/portfolio_data.dart';

/// App-level state holder for the user's selected investment type.
/// Survives across navigation and is accessible from any screen.
class PortfolioState extends ChangeNotifier {
  InvestmentType _type = InvestmentType.balanced;

  InvestmentType get type => _type;

  void setType(InvestmentType newType) {
    if (_type != newType) {
      _type = newType;
      notifyListeners();
    }
  }

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
