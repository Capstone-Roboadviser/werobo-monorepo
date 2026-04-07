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

/// Fixed colors per category — consistent across all portfolio types
class CategoryColors {
  CategoryColors._();

  static const valueStock = Color(0xFF20A7DB); // primary sky
  static const growthStock = Color(0xFF7B8CDE); // periwinkle
  static const newGrowth = Color(0xFF9B7FCC); // soft violet
  static const bond = Color(0xFF3D5A80); // muted navy
  static const cash = Color(0xFFA8D8EA); // ice blue
  static const gold = Color(0xFF293241); // deep navy
  static const infra = Color(0xFF98C1D9); // dusty blue
}

/// All portfolio data for the 3 investment types
class PortfolioData {
  PortfolioData._();

  static List<PortfolioCategory> categoriesFor(InvestmentType type) {
    switch (type) {
      case InvestmentType.safe:
        return _safeCats;
      case InvestmentType.balanced:
        return _balancedCats;
      case InvestmentType.growth:
        return _growthCats;
    }
  }

  static List<PortfolioCategoryDetail> detailsFor(InvestmentType type) {
    switch (type) {
      case InvestmentType.safe:
        return _safeDetails;
      case InvestmentType.balanced:
        return _balancedDetails;
      case InvestmentType.growth:
        return _growthDetails;
    }
  }

  // Risk/return ranges per type
  static (String risk, String returnRate) statsFor(InvestmentType type) {
    switch (type) {
      case InvestmentType.safe:
        return ('8.4%', '24.7%');
      case InvestmentType.balanced:
        return ('10.8%', '28.1%');
      case InvestmentType.growth:
        return ('13.7%', '31.6%');
    }
  }

  // ── Safe ──
  static const _safeCats = [
    PortfolioCategory(
        name: '단기 채권', percentage: 35, color: CategoryColors.bond),
    PortfolioCategory(
        name: '현금성자산', percentage: 20, color: CategoryColors.cash),
    PortfolioCategory(name: '금', percentage: 15, color: CategoryColors.gold),
    PortfolioCategory(
        name: '미국 가치주', percentage: 10, color: CategoryColors.valueStock),
    PortfolioCategory(
        name: '미국 성장주', percentage: 8, color: CategoryColors.growthStock),
    PortfolioCategory(
        name: '인프라 채권', percentage: 7, color: CategoryColors.infra),
    PortfolioCategory(
        name: '신성장주', percentage: 5, color: CategoryColors.newGrowth),
  ];

  static const _safeDetails = [
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '단기 채권', percentage: 35, color: CategoryColors.bond),
        tickers: [
          TickerHolding(
              symbol: 'SHV', name: 'iShares Short Treasury', percentage: 15.0),
          TickerHolding(
              symbol: 'BSV',
              name: 'Vanguard Short-Term Bond',
              percentage: 12.0),
          TickerHolding(
              symbol: 'SCHO',
              name: 'Schwab Short-Term US Treasury',
              percentage: 8.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '현금성자산', percentage: 20, color: CategoryColors.cash),
        tickers: [
          TickerHolding(
              symbol: 'BIL', name: 'SPDR 1-3 Month T-Bill', percentage: 12.0),
          TickerHolding(
              symbol: 'SGOV',
              name: 'iShares 0-3 Month Treasury',
              percentage: 8.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '금', percentage: 15, color: CategoryColors.gold),
        tickers: [
          TickerHolding(
              symbol: 'GLD', name: 'SPDR Gold Shares', percentage: 10.0),
          TickerHolding(
              symbol: 'IAU', name: 'iShares Gold Trust', percentage: 5.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '미국 가치주', percentage: 10, color: CategoryColors.valueStock),
        tickers: [
          TickerHolding(
              symbol: 'VTV', name: 'Vanguard Value ETF', percentage: 6.0),
          TickerHolding(
              symbol: 'SCHV',
              name: 'Schwab US Large-Cap Value',
              percentage: 4.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '미국 성장주', percentage: 8, color: CategoryColors.growthStock),
        tickers: [
          TickerHolding(
              symbol: 'VUG', name: 'Vanguard Growth ETF', percentage: 5.0),
          TickerHolding(
              symbol: 'QQQ', name: 'Invesco QQQ Trust', percentage: 3.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '인프라 채권', percentage: 7, color: CategoryColors.infra),
        tickers: [
          TickerHolding(
              symbol: 'IFRA',
              name: 'iShares US Infrastructure',
              percentage: 4.0),
          TickerHolding(
              symbol: 'PAVE',
              name: 'Global X US Infrastructure',
              percentage: 3.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '신성장주', percentage: 5, color: CategoryColors.newGrowth),
        tickers: [
          TickerHolding(
              symbol: 'ARKK', name: 'ARK Innovation ETF', percentage: 3.0),
          TickerHolding(
              symbol: 'QCLN',
              name: 'First Trust NASDAQ Clean Edge',
              percentage: 2.0),
        ]),
  ];

  // ── Balanced ──
  static const _balancedCats = [
    PortfolioCategory(
        name: '미국 가치주', percentage: 20, color: CategoryColors.valueStock),
    PortfolioCategory(
        name: '단기 채권', percentage: 20, color: CategoryColors.bond),
    PortfolioCategory(
        name: '미국 성장주', percentage: 18, color: CategoryColors.growthStock),
    PortfolioCategory(
        name: '신성장주', percentage: 12, color: CategoryColors.newGrowth),
    PortfolioCategory(name: '금', percentage: 12, color: CategoryColors.gold),
    PortfolioCategory(
        name: '현금성자산', percentage: 10, color: CategoryColors.cash),
    PortfolioCategory(
        name: '인프라 채권', percentage: 8, color: CategoryColors.infra),
  ];

  static const _balancedDetails = [
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '미국 가치주', percentage: 20, color: CategoryColors.valueStock),
        tickers: [
          TickerHolding(
              symbol: 'VTV', name: 'Vanguard Value ETF', percentage: 8.0),
          TickerHolding(
              symbol: 'SCHV',
              name: 'Schwab US Large-Cap Value',
              percentage: 7.0),
          TickerHolding(
              symbol: 'RPV',
              name: 'Invesco S&P 500 Pure Value',
              percentage: 5.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '단기 채권', percentage: 20, color: CategoryColors.bond),
        tickers: [
          TickerHolding(
              symbol: 'SHV', name: 'iShares Short Treasury', percentage: 10.0),
          TickerHolding(
              symbol: 'BSV',
              name: 'Vanguard Short-Term Bond',
              percentage: 10.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '미국 성장주', percentage: 18, color: CategoryColors.growthStock),
        tickers: [
          TickerHolding(
              symbol: 'VUG', name: 'Vanguard Growth ETF', percentage: 7.0),
          TickerHolding(
              symbol: 'QQQ', name: 'Invesco QQQ Trust', percentage: 6.0),
          TickerHolding(
              symbol: 'SCHG',
              name: 'Schwab US Large-Cap Growth',
              percentage: 5.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '신성장주', percentage: 12, color: CategoryColors.newGrowth),
        tickers: [
          TickerHolding(
              symbol: 'ARKK', name: 'ARK Innovation ETF', percentage: 5.0),
          TickerHolding(
              symbol: 'QCLN',
              name: 'First Trust NASDAQ Clean Edge',
              percentage: 4.0),
          TickerHolding(
              symbol: 'ICLN',
              name: 'iShares Global Clean Energy',
              percentage: 3.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '금', percentage: 12, color: CategoryColors.gold),
        tickers: [
          TickerHolding(
              symbol: 'GLD', name: 'SPDR Gold Shares', percentage: 7.0),
          TickerHolding(
              symbol: 'IAU', name: 'iShares Gold Trust', percentage: 5.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '현금성자산', percentage: 10, color: CategoryColors.cash),
        tickers: [
          TickerHolding(
              symbol: 'BIL', name: 'SPDR 1-3 Month T-Bill', percentage: 6.0),
          TickerHolding(
              symbol: 'SGOV',
              name: 'iShares 0-3 Month Treasury',
              percentage: 4.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '인프라 채권', percentage: 8, color: CategoryColors.infra),
        tickers: [
          TickerHolding(
              symbol: 'IFRA',
              name: 'iShares US Infrastructure',
              percentage: 4.5),
          TickerHolding(
              symbol: 'PAVE',
              name: 'Global X US Infrastructure',
              percentage: 3.5),
        ]),
  ];

  // ── Growth ──
  static const _growthCats = [
    PortfolioCategory(
        name: '미국 가치주', percentage: 25, color: CategoryColors.valueStock),
    PortfolioCategory(
        name: '미국 성장주', percentage: 25, color: CategoryColors.growthStock),
    PortfolioCategory(
        name: '신성장주', percentage: 20, color: CategoryColors.newGrowth),
    PortfolioCategory(
        name: '단기 채권', percentage: 10, color: CategoryColors.bond),
    PortfolioCategory(name: '금', percentage: 10, color: CategoryColors.gold),
    PortfolioCategory(name: '현금성자산', percentage: 5, color: CategoryColors.cash),
    PortfolioCategory(
        name: '인프라 채권', percentage: 5, color: CategoryColors.infra),
  ];

  static const _growthDetails = [
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '미국 가치주', percentage: 25, color: CategoryColors.valueStock),
        tickers: [
          TickerHolding(
              symbol: 'VTV', name: 'Vanguard Value ETF', percentage: 10.0),
          TickerHolding(
              symbol: 'SCHV',
              name: 'Schwab US Large-Cap Value',
              percentage: 8.0),
          TickerHolding(
              symbol: 'RPV',
              name: 'Invesco S&P 500 Pure Value',
              percentage: 7.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '미국 성장주', percentage: 25, color: CategoryColors.growthStock),
        tickers: [
          TickerHolding(
              symbol: 'VUG', name: 'Vanguard Growth ETF', percentage: 9.0),
          TickerHolding(
              symbol: 'QQQ', name: 'Invesco QQQ Trust', percentage: 9.0),
          TickerHolding(
              symbol: 'SCHG',
              name: 'Schwab US Large-Cap Growth',
              percentage: 7.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '신성장주', percentage: 20, color: CategoryColors.newGrowth),
        tickers: [
          TickerHolding(
              symbol: 'ARKK', name: 'ARK Innovation ETF', percentage: 7.0),
          TickerHolding(
              symbol: 'QCLN',
              name: 'First Trust NASDAQ Clean Edge',
              percentage: 7.0),
          TickerHolding(
              symbol: 'ICLN',
              name: 'iShares Global Clean Energy',
              percentage: 6.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '단기 채권', percentage: 10, color: CategoryColors.bond),
        tickers: [
          TickerHolding(
              symbol: 'SHV', name: 'iShares Short Treasury', percentage: 6.0),
          TickerHolding(
              symbol: 'BSV', name: 'Vanguard Short-Term Bond', percentage: 4.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '금', percentage: 10, color: CategoryColors.gold),
        tickers: [
          TickerHolding(
              symbol: 'GLD', name: 'SPDR Gold Shares', percentage: 6.0),
          TickerHolding(
              symbol: 'IAU', name: 'iShares Gold Trust', percentage: 4.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '현금성자산', percentage: 5, color: CategoryColors.cash),
        tickers: [
          TickerHolding(
              symbol: 'BIL', name: 'SPDR 1-3 Month T-Bill', percentage: 3.0),
          TickerHolding(
              symbol: 'SGOV',
              name: 'iShares 0-3 Month Treasury',
              percentage: 2.0),
        ]),
    PortfolioCategoryDetail(
        category: PortfolioCategory(
            name: '인프라 채권', percentage: 5, color: CategoryColors.infra),
        tickers: [
          TickerHolding(
              symbol: 'IFRA',
              name: 'iShares US Infrastructure',
              percentage: 3.0),
          TickerHolding(
              symbol: 'PAVE',
              name: 'Global X US Infrastructure',
              percentage: 2.0),
        ]),
  ];
}
