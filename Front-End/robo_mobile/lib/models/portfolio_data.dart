import 'package:flutter/material.dart';

/// Investment tendency type based on efficient frontier position
enum InvestmentType {
  safe('안전형', '안전형 투자를 원하시는 군요!'),
  balanced('균형형', '균형 잡힌 투자를 원하시는 군요!'),
  growth('성장형', '성장형 투자를 원하시는 군요!');

  final String label;
  final String description;
  const InvestmentType(this.label, this.description);

  /// API-side risk profile code.
  String get riskCode {
    switch (this) {
      case InvestmentType.safe:
        return 'conservative';
      case InvestmentType.balanced:
        return 'balanced';
      case InvestmentType.growth:
        return 'growth';
    }
  }

  static InvestmentType fromDotT(double dotT) {
    if (dotT < 0.33) return InvestmentType.safe;
    if (dotT < 0.66) return InvestmentType.balanced;
    return InvestmentType.growth;
  }
}

/// A portfolio sector with name, percentage, and color
class PortfolioCategory {
  final String name;
  final double percentage;
  final Color color;

  const PortfolioCategory({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

/// A single ETF ticker within a sector
class TickerHolding {
  final String symbol;
  final String name;
  final double percentage;

  const TickerHolding({
    required this.symbol,
    required this.name,
    required this.percentage,
  });
}

/// Sector category with its constituent tickers
class PortfolioCategoryDetail {
  final PortfolioCategory category;
  final List<TickerHolding> tickers;

  const PortfolioCategoryDetail({
    required this.category,
    required this.tickers,
  });
}
