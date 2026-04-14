import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'portfolio_data.dart';

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _normalizeComparisonReturn(Object? value) {
  final parsed = _asDouble(value);
  // API returns percentage points (12.32 = 12.32%).
  // Charts expect decimal ratios (0.1232 = 12.32%).
  return parsed / 100;
}

DateTime _parseDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _parseOptionalDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String? _dateToJson(DateTime? value) {
  if (value == null) {
    return null;
  }
  final normalized = DateTime(value.year, value.month, value.day);
  return normalized.toIso8601String().split('T').first;
}

Color parseBackendHexColor(String value) {
  final hex = value.replaceFirst('#', '');
  if (hex.length == 6) {
    return Color(int.parse('FF$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return WeRoboColors.primary;
}

String formatRatioPercent(double value, {int fractionDigits = 1}) {
  return '${(value * 100).toStringAsFixed(fractionDigits)}%';
}

enum AuthProviderType {
  password,
  google,
  kakao,
  naver,
  apple,
  unknown,
}

AuthProviderType authProviderTypeFromApi(String value) {
  switch (value) {
    case 'password':
      return AuthProviderType.password;
    case 'google':
      return AuthProviderType.google;
    case 'kakao':
      return AuthProviderType.kakao;
    case 'naver':
      return AuthProviderType.naver;
    case 'apple':
      return AuthProviderType.apple;
    default:
      return AuthProviderType.unknown;
  }
}

String authProviderTypeToApi(AuthProviderType value) {
  switch (value) {
    case AuthProviderType.password:
      return 'password';
    case AuthProviderType.google:
      return 'google';
    case AuthProviderType.kakao:
      return 'kakao';
    case AuthProviderType.naver:
      return 'naver';
    case AuthProviderType.apple:
      return 'apple';
    case AuthProviderType.unknown:
      return 'unknown';
  }
}

InvestmentType investmentTypeFromRiskCode(String code) {
  switch (code) {
    case 'conservative':
      return InvestmentType.safe;
    case 'growth':
      return InvestmentType.growth;
    case 'balanced':
    default:
      return InvestmentType.balanced;
  }
}

Color _categoryColorForCode(String code, int index) {
  switch (code) {
    case 'us_value':
    case 'value_stock':
      return CategoryColors.valueStock;
    case 'us_growth':
    case 'growth_stock':
      return CategoryColors.growthStock;
    case 'new_growth':
    case 'innovation':
      return CategoryColors.newGrowth;
    case 'short_term_bond':
    case 'bond':
    case 'treasury':
      return CategoryColors.bond;
    case 'cash':
    case 'cash_equivalent':
      return CategoryColors.cash;
    case 'gold':
    case 'commodity_gold':
      return CategoryColors.gold;
    case 'infra':
    case 'infrastructure':
    case 'infrastructure_bond':
      return CategoryColors.infra;
    default:
      const palette = <Color>[
        CategoryColors.valueStock,
        CategoryColors.bond,
        CategoryColors.growthStock,
        CategoryColors.newGrowth,
        CategoryColors.gold,
        CategoryColors.cash,
        CategoryColors.infra,
      ];
      return palette[index % palette.length];
  }
}

class MobileAuthUser {
  final int id;
  final String email;
  final String name;
  final AuthProviderType provider;
  final String createdAt;

  const MobileAuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.provider,
    required this.createdAt,
  });

  factory MobileAuthUser.fromJson(Map<String, dynamic> json) {
    return MobileAuthUser(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provider: authProviderTypeFromApi(json['provider']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'name': name,
      'provider': authProviderTypeToApi(provider),
      'created_at': createdAt,
    };
  }
}

class MobileAuthSession {
  final String accessToken;
  final String tokenType;
  final String expiresAt;
  final MobileAuthUser user;

  const MobileAuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  factory MobileAuthSession.fromJson(Map<String, dynamic> json) {
    return MobileAuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: json['expires_at']?.toString() ?? '',
      user: MobileAuthUser.fromJson(
        (json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_at': expiresAt,
      'user': user.toJson(),
    };
  }
}

class MobileCurrentAuthSession {
  final bool authenticated;
  final String expiresAt;
  final MobileAuthUser user;

  const MobileCurrentAuthSession({
    required this.authenticated,
    required this.expiresAt,
    required this.user,
  });

  factory MobileCurrentAuthSession.fromJson(Map<String, dynamic> json) {
    return MobileCurrentAuthSession(
      authenticated: json['authenticated'] == true,
      expiresAt: json['expires_at']?.toString() ?? '',
      user: MobileAuthUser.fromJson(
        (json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
      ),
    );
  }
}

class MobileAccountSummary {
  final String portfolioCode;
  final String portfolioLabel;
  final String portfolioId;
  final String dataSource;
  final String investmentHorizon;
  final double targetVolatility;
  final double expectedReturn;
  final double volatility;
  final double sharpeRatio;
  final String startedAt;
  final String lastSnapshotDate;
  final double currentValue;
  final double investedAmount;
  final double profitLoss;
  final double profitLossPct;
  final List<MobileSectorAllocation> sectorAllocations;
  final List<MobileStockAllocation> stockAllocations;

  const MobileAccountSummary({
    required this.portfolioCode,
    required this.portfolioLabel,
    required this.portfolioId,
    required this.dataSource,
    required this.investmentHorizon,
    required this.targetVolatility,
    required this.expectedReturn,
    required this.volatility,
    required this.sharpeRatio,
    required this.startedAt,
    required this.lastSnapshotDate,
    required this.currentValue,
    required this.investedAmount,
    required this.profitLoss,
    required this.profitLossPct,
    required this.sectorAllocations,
    required this.stockAllocations,
  });

  factory MobileAccountSummary.fromJson(Map<String, dynamic> json) {
    return MobileAccountSummary(
      portfolioCode: json['portfolio_code']?.toString() ?? '',
      portfolioLabel: json['portfolio_label']?.toString() ?? '',
      portfolioId: json['portfolio_id']?.toString() ?? '',
      dataSource: json['data_source']?.toString() ?? '',
      investmentHorizon: json['investment_horizon']?.toString() ?? 'medium',
      targetVolatility: _asDouble(json['target_volatility']),
      expectedReturn: _asDouble(json['expected_return']),
      volatility: _asDouble(json['volatility']),
      sharpeRatio: _asDouble(json['sharpe_ratio']),
      startedAt: json['started_at']?.toString() ?? '',
      lastSnapshotDate: json['last_snapshot_date']?.toString() ?? '',
      currentValue: _asDouble(json['current_value']),
      investedAmount: _asDouble(json['invested_amount']),
      profitLoss: _asDouble(json['profit_loss']),
      profitLossPct: _asDouble(json['profit_loss_pct']),
      sectorAllocations:
          (json['sector_allocations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MobileSectorAllocation.fromJson)
              .toList(),
      stockAllocations:
          (json['stock_allocations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MobileStockAllocation.fromJson)
              .toList(),
    );
  }
}

class MobileAccountHistoryPoint {
  final DateTime date;
  final double portfolioValue;
  final double investedAmount;
  final double profitLoss;
  final double profitLossPct;

  const MobileAccountHistoryPoint({
    required this.date,
    required this.portfolioValue,
    required this.investedAmount,
    required this.profitLoss,
    required this.profitLossPct,
  });

  factory MobileAccountHistoryPoint.fromJson(Map<String, dynamic> json) {
    return MobileAccountHistoryPoint(
      date: _parseDate(json['date']),
      portfolioValue: _asDouble(json['portfolio_value']),
      investedAmount: _asDouble(json['invested_amount']),
      profitLoss: _asDouble(json['profit_loss']),
      profitLossPct: _asDouble(json['profit_loss_pct']),
    );
  }
}

class MobileAccountActivity {
  final String type;
  final String title;
  final String date;
  final double? amount;
  final String? description;

  const MobileAccountActivity({
    required this.type,
    required this.title,
    required this.date,
    required this.amount,
    required this.description,
  });

  factory MobileAccountActivity.fromJson(Map<String, dynamic> json) {
    return MobileAccountActivity(
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: json['amount'] == null ? null : _asDouble(json['amount']),
      description: json['description']?.toString(),
    );
  }
}

class MobileAccountDashboard {
  final bool hasAccount;
  final MobileAccountSummary? summary;
  final List<MobileAccountHistoryPoint> history;
  final List<MobileAccountActivity> recentActivity;

  const MobileAccountDashboard({
    required this.hasAccount,
    required this.summary,
    required this.history,
    required this.recentActivity,
  });

  factory MobileAccountDashboard.fromJson(Map<String, dynamic> json) {
    return MobileAccountDashboard(
      hasAccount: json['has_account'] == true,
      summary: (json['summary'] as Map<String, dynamic>?)
          ?.let(MobileAccountSummary.fromJson),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileAccountHistoryPoint.fromJson)
          .toList(),
      recentActivity: (json['recent_activity'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileAccountActivity.fromJson)
          .toList(),
    );
  }
}

extension _NullableMapLet on Map<String, dynamic>? {
  T? let<T>(T Function(Map<String, dynamic> value) mapper) {
    final value = this;
    if (value == null) {
      return null;
    }
    return mapper(value);
  }
}

class MobileResolvedProfile {
  final String code;
  final String label;
  final double? propensityScore;
  final double targetVolatility;
  final String investmentHorizon;

  const MobileResolvedProfile({
    required this.code,
    required this.label,
    required this.propensityScore,
    required this.targetVolatility,
    required this.investmentHorizon,
  });

  factory MobileResolvedProfile.fromJson(Map<String, dynamic> json) {
    return MobileResolvedProfile(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      propensityScore: json['propensity_score'] == null
          ? null
          : _asDouble(json['propensity_score']),
      targetVolatility: _asDouble(json['target_volatility']),
      investmentHorizon: json['investment_horizon']?.toString() ?? 'medium',
    );
  }

  InvestmentType get investmentType => investmentTypeFromRiskCode(code);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'label': label,
      'propensity_score': propensityScore,
      'target_volatility': targetVolatility,
      'investment_horizon': investmentHorizon,
    };
  }
}

class MobileSectorAllocation {
  final String assetCode;
  final String assetName;
  final double weight;
  final double riskContribution;

  const MobileSectorAllocation({
    required this.assetCode,
    required this.assetName,
    required this.weight,
    required this.riskContribution,
  });

  factory MobileSectorAllocation.fromJson(Map<String, dynamic> json) {
    return MobileSectorAllocation(
      assetCode: json['asset_code']?.toString() ?? '',
      assetName: json['asset_name']?.toString() ?? '',
      weight: _asDouble(json['weight']),
      riskContribution: _asDouble(json['risk_contribution']),
    );
  }

  PortfolioCategory toCategory(int index) {
    return PortfolioCategory(
      name: assetName,
      percentage: weight * 100,
      color: _categoryColorForCode(assetCode, index),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'asset_code': assetCode,
      'asset_name': assetName,
      'weight': weight,
      'risk_contribution': riskContribution,
    };
  }
}

class MobileStockAllocation {
  final String ticker;
  final String name;
  final String sectorCode;
  final String sectorName;
  final double weight;

  const MobileStockAllocation({
    required this.ticker,
    required this.name,
    required this.sectorCode,
    required this.sectorName,
    required this.weight,
  });

  factory MobileStockAllocation.fromJson(Map<String, dynamic> json) {
    return MobileStockAllocation(
      ticker: json['ticker']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sectorCode: json['sector_code']?.toString() ?? '',
      sectorName: json['sector_name']?.toString() ?? '',
      weight: _asDouble(json['weight']),
    );
  }

  TickerHolding toTickerHolding() {
    return TickerHolding(
      symbol: ticker,
      name: name,
      percentage: weight * 100,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ticker': ticker,
      'name': name,
      'sector_code': sectorCode,
      'sector_name': sectorName,
      'weight': weight,
    };
  }
}

class MobilePortfolioRecommendation {
  final String code;
  final String label;
  final String portfolioId;
  final double targetVolatility;
  final double expectedReturn;
  final double volatility;
  final double sharpeRatio;
  final List<MobileSectorAllocation> sectorAllocations;
  final List<MobileStockAllocation> stockAllocations;

  const MobilePortfolioRecommendation({
    required this.code,
    required this.label,
    required this.portfolioId,
    required this.targetVolatility,
    required this.expectedReturn,
    required this.volatility,
    required this.sharpeRatio,
    required this.sectorAllocations,
    required this.stockAllocations,
  });

  factory MobilePortfolioRecommendation.fromJson(Map<String, dynamic> json) {
    return MobilePortfolioRecommendation(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      portfolioId: json['portfolio_id']?.toString() ?? '',
      targetVolatility: _asDouble(json['target_volatility']),
      expectedReturn: _asDouble(json['expected_return']),
      volatility: _asDouble(json['volatility']),
      sharpeRatio: _asDouble(json['sharpe_ratio']),
      sectorAllocations:
          (json['sector_allocations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MobileSectorAllocation.fromJson)
              .toList(),
      stockAllocations:
          (json['stock_allocations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(MobileStockAllocation.fromJson)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'label': label,
      'portfolio_id': portfolioId,
      'target_volatility': targetVolatility,
      'expected_return': expectedReturn,
      'volatility': volatility,
      'sharpe_ratio': sharpeRatio,
      'sector_allocations':
          sectorAllocations.map((allocation) => allocation.toJson()).toList(),
      'stock_allocations':
          stockAllocations.map((allocation) => allocation.toJson()).toList(),
    };
  }

  InvestmentType get investmentType => investmentTypeFromRiskCode(code);

  String get volatilityLabel => formatRatioPercent(volatility);

  String get expectedReturnLabel => formatRatioPercent(expectedReturn);

  Map<String, double> get stockWeights {
    return <String, double>{
      for (final allocation in stockAllocations)
        allocation.ticker.toUpperCase(): allocation.weight,
    };
  }

  List<PortfolioCategory> toCategories() {
    if (sectorAllocations.isNotEmpty) {
      return [
        for (int i = 0; i < sectorAllocations.length; i++)
          sectorAllocations[i].toCategory(i),
      ];
    }

    final grouped = _groupStocksBySector();
    return [
      for (int i = 0; i < grouped.length; i++)
        PortfolioCategory(
          name: grouped[i].name,
          percentage: grouped[i].weight * 100,
          color: _categoryColorForCode(grouped[i].code, i),
        ),
    ];
  }

  List<PortfolioCategoryDetail> toCategoryDetails() {
    final grouped = _groupStocksBySector();
    final categories = toCategories();
    final detailByCode = <String, _GroupedSector>{
      for (final sector in grouped) sector.code: sector,
    };

    final details = <PortfolioCategoryDetail>[];
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final sectorCode = i < sectorAllocations.length
          ? sectorAllocations[i].assetCode
          : grouped[i].code;
      final tickers =
          detailByCode[sectorCode]?.tickers ?? const <MobileStockAllocation>[];
      details.add(
        PortfolioCategoryDetail(
          category: category,
          tickers: tickers.map((holding) => holding.toTickerHolding()).toList(),
        ),
      );
    }
    return details;
  }

  List<TickerHolding> topTickerHoldings({int limit = 3}) {
    final sorted = [...stockAllocations]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return sorted
        .take(limit)
        .map((holding) => holding.toTickerHolding())
        .toList();
  }

  List<_GroupedSector> _groupStocksBySector() {
    final grouped = <String, List<MobileStockAllocation>>{};
    for (final allocation in stockAllocations) {
      grouped.putIfAbsent(allocation.sectorCode, () => []).add(allocation);
    }

    final ordered = <_GroupedSector>[];
    final usedCodes = <String>{};

    for (final sector in sectorAllocations) {
      final stocks = [
        ...(grouped[sector.assetCode] ?? const <MobileStockAllocation>[])
      ]..sort((a, b) => b.weight.compareTo(a.weight));
      ordered.add(
        _GroupedSector(
          code: sector.assetCode,
          name: sector.assetName,
          weight: sector.weight,
          tickers: stocks,
        ),
      );
      usedCodes.add(sector.assetCode);
    }

    for (final entry in grouped.entries) {
      if (usedCodes.contains(entry.key)) {
        continue;
      }
      final stocks = [...entry.value]
        ..sort((a, b) => b.weight.compareTo(a.weight));
      ordered.add(
        _GroupedSector(
          code: entry.key,
          name: stocks.isNotEmpty ? stocks.first.sectorName : entry.key,
          weight: stocks.fold<double>(0, (sum, item) => sum + item.weight),
          tickers: stocks,
        ),
      );
    }

    return ordered;
  }
}

class MobileRecommendationResponse {
  final MobileResolvedProfile resolvedProfile;
  final String recommendedPortfolioCode;
  final String dataSource;
  final DateTime? asOfDate;
  final List<MobilePortfolioRecommendation> portfolios;

  const MobileRecommendationResponse({
    required this.resolvedProfile,
    required this.recommendedPortfolioCode,
    required this.dataSource,
    required this.asOfDate,
    required this.portfolios,
  });

  factory MobileRecommendationResponse.fromJson(Map<String, dynamic> json) {
    return MobileRecommendationResponse(
      resolvedProfile: MobileResolvedProfile.fromJson(
        json['resolved_profile'] as Map<String, dynamic>? ?? const {},
      ),
      recommendedPortfolioCode:
          json['recommended_portfolio_code']?.toString() ?? '',
      dataSource: json['data_source']?.toString() ?? '',
      asOfDate: _parseOptionalDate(json['as_of_date']),
      portfolios: (json['portfolios'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobilePortfolioRecommendation.fromJson)
          .toList(),
    );
  }

  MobilePortfolioRecommendation? portfolioByCode(String code) {
    for (final portfolio in portfolios) {
      if (portfolio.code == code) {
        return portfolio;
      }
    }
    return null;
  }

  MobilePortfolioRecommendation get recommendedPortfolio {
    return portfolioByCode(recommendedPortfolioCode) ??
        (portfolios.isNotEmpty
            ? portfolios.first
            : const MobilePortfolioRecommendation(
                code: 'balanced',
                label: '균형형',
                portfolioId: '',
                targetVolatility: 0,
                expectedReturn: 0,
                volatility: 0,
                sharpeRatio: 0,
                sectorAllocations: [],
                stockAllocations: [],
              ));
  }

  MobilePortfolioRecommendation portfolioByCodeOrRecommended(String code) {
    return portfolioByCode(code) ?? recommendedPortfolio;
  }

  double get averageVolatility {
    if (portfolios.isEmpty) return 0.0;
    final sum = portfolios.fold<double>(
      0.0,
      (acc, p) => acc + p.volatility,
    );
    return sum / portfolios.length;
  }

  ({int percentDiff, bool isRiskier}) marketRiskComparison(
    MobilePortfolioRecommendation portfolio,
  ) {
    final avg = averageVolatility;
    if (avg == 0.0) return (percentDiff: 0, isRiskier: false);
    final diff = (portfolio.volatility - avg) / avg;
    return (
      percentDiff: (diff.abs() * 100).round(),
      isRiskier: diff >= 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'resolved_profile': resolvedProfile.toJson(),
      'recommended_portfolio_code': recommendedPortfolioCode,
      'data_source': dataSource,
      'as_of_date': _dateToJson(asOfDate),
      'portfolios': portfolios.map((portfolio) => portfolio.toJson()).toList(),
    };
  }
}

class MobileFrontierPreviewPoint {
  final int index;
  final double volatility;
  final double expectedReturn;
  final bool isRecommended;
  final String? representativeCode;
  final String? representativeLabel;

  const MobileFrontierPreviewPoint({
    required this.index,
    required this.volatility,
    required this.expectedReturn,
    required this.isRecommended,
    required this.representativeCode,
    required this.representativeLabel,
  });

  factory MobileFrontierPreviewPoint.fromJson(Map<String, dynamic> json) {
    return MobileFrontierPreviewPoint(
      index: (json['index'] as num?)?.toInt() ?? 0,
      volatility: _asDouble(json['volatility']),
      expectedReturn: _asDouble(json['expected_return']),
      isRecommended: json['is_recommended'] == true,
      representativeCode: json['representative_code']?.toString(),
      representativeLabel: json['representative_label']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      'volatility': volatility,
      'expected_return': expectedReturn,
      'is_recommended': isRecommended,
      'representative_code': representativeCode,
      'representative_label': representativeLabel,
    };
  }
}

class MobileFrontierPreviewResponse {
  final MobileResolvedProfile resolvedProfile;
  final String recommendedPortfolioCode;
  final String dataSource;
  final DateTime? asOfDate;
  final int totalPointCount;
  final double minVolatility;
  final double maxVolatility;
  final List<MobileFrontierPreviewPoint> points;

  const MobileFrontierPreviewResponse({
    required this.resolvedProfile,
    required this.recommendedPortfolioCode,
    required this.dataSource,
    required this.asOfDate,
    required this.totalPointCount,
    required this.minVolatility,
    required this.maxVolatility,
    required this.points,
  });

  factory MobileFrontierPreviewResponse.fromJson(Map<String, dynamic> json) {
    return MobileFrontierPreviewResponse(
      resolvedProfile: MobileResolvedProfile.fromJson(
        json['resolved_profile'] as Map<String, dynamic>? ?? const {},
      ),
      recommendedPortfolioCode:
          json['recommended_portfolio_code']?.toString() ?? '',
      dataSource: json['data_source']?.toString() ?? '',
      asOfDate: _parseOptionalDate(json['as_of_date']),
      totalPointCount: (json['total_point_count'] as num?)?.toInt() ?? 0,
      minVolatility: _asDouble(json['min_volatility']),
      maxVolatility: _asDouble(json['max_volatility']),
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileFrontierPreviewPoint.fromJson)
          .toList(),
    );
  }

  int get recommendedPreviewPosition {
    final recommendedIndex = points.indexWhere((point) => point.isRecommended);
    if (recommendedIndex >= 0) {
      return recommendedIndex;
    }
    if (points.isEmpty) {
      return 0;
    }
    return points.length ~/ 2;
  }

  MobileFrontierPreviewPoint? get recommendedPoint {
    if (points.isEmpty) {
      return null;
    }
    return points[recommendedPreviewPosition];
  }

  double get averageVolatility {
    if (points.isEmpty) {
      return 0.0;
    }
    final total = points.fold<double>(
      0.0,
      (sum, point) => sum + point.volatility,
    );
    return total / points.length;
  }

  MobileFrontierPreviewPoint? pointByIndex(int index) {
    for (final point in points) {
      if (point.index == index) {
        return point;
      }
    }
    return null;
  }

  int positionForPointIndex(int index) {
    final position = points.indexWhere((point) => point.index == index);
    if (position >= 0) {
      return position;
    }
    if (points.isEmpty) {
      return 0;
    }
    return recommendedPreviewPosition;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'resolved_profile': resolvedProfile.toJson(),
      'recommended_portfolio_code': recommendedPortfolioCode,
      'data_source': dataSource,
      'as_of_date': _dateToJson(asOfDate),
      'total_point_count': totalPointCount,
      'min_volatility': minVolatility,
      'max_volatility': maxVolatility,
      'points': points.map((point) => point.toJson()).toList(),
    };
  }
}

class MobileFrontierSelectionResponse {
  final MobileResolvedProfile resolvedProfile;
  final String dataSource;
  final DateTime? asOfDate;
  final double requestedTargetVolatility;
  final double selectedTargetVolatility;
  final int selectedPointIndex;
  final int totalPointCount;
  final String? representativeCode;
  final String? representativeLabel;
  final MobilePortfolioRecommendation portfolio;

  const MobileFrontierSelectionResponse({
    required this.resolvedProfile,
    required this.dataSource,
    required this.asOfDate,
    required this.requestedTargetVolatility,
    required this.selectedTargetVolatility,
    required this.selectedPointIndex,
    required this.totalPointCount,
    required this.representativeCode,
    required this.representativeLabel,
    required this.portfolio,
  });

  factory MobileFrontierSelectionResponse.fromJson(Map<String, dynamic> json) {
    return MobileFrontierSelectionResponse(
      resolvedProfile: MobileResolvedProfile.fromJson(
        json['resolved_profile'] as Map<String, dynamic>? ?? const {},
      ),
      dataSource: json['data_source']?.toString() ?? '',
      asOfDate: _parseOptionalDate(json['as_of_date']),
      requestedTargetVolatility: _asDouble(json['requested_target_volatility']),
      selectedTargetVolatility: _asDouble(json['selected_target_volatility']),
      selectedPointIndex: (json['selected_point_index'] as num?)?.toInt() ?? 0,
      totalPointCount: (json['total_point_count'] as num?)?.toInt() ?? 0,
      representativeCode: json['representative_code']?.toString(),
      representativeLabel: json['representative_label']?.toString(),
      portfolio: MobilePortfolioRecommendation.fromJson(
        json['portfolio'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  String get classificationCode => representativeCode ?? resolvedProfile.code;

  String get classificationLabel =>
      representativeLabel ?? resolvedProfile.label;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'resolved_profile': resolvedProfile.toJson(),
      'data_source': dataSource,
      'as_of_date': _dateToJson(asOfDate),
      'requested_target_volatility': requestedTargetVolatility,
      'selected_target_volatility': selectedTargetVolatility,
      'selected_point_index': selectedPointIndex,
      'total_point_count': totalPointCount,
      'representative_code': representativeCode,
      'representative_label': representativeLabel,
      'portfolio': portfolio.toJson(),
    };
  }
}

class MobileVolatilityPoint {
  final DateTime date;
  final double volatility;

  const MobileVolatilityPoint({
    required this.date,
    required this.volatility,
  });

  factory MobileVolatilityPoint.fromJson(Map<String, dynamic> json) {
    return MobileVolatilityPoint(
      date: _parseDate(json['date']),
      volatility: _asDouble(json['volatility']),
    );
  }
}

class MobileVolatilityHistoryResponse {
  final String portfolioCode;
  final String portfolioLabel;
  final int rollingWindow;
  final DateTime earliestDataDate;
  final DateTime latestDataDate;
  final List<MobileVolatilityPoint> points;
  final List<MobileVolatilityPoint>? benchmarkPoints;

  const MobileVolatilityHistoryResponse({
    required this.portfolioCode,
    required this.portfolioLabel,
    required this.rollingWindow,
    required this.earliestDataDate,
    required this.latestDataDate,
    required this.points,
    this.benchmarkPoints,
  });

  factory MobileVolatilityHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawBenchmark = json['benchmark_points'] as List<dynamic>?;
    return MobileVolatilityHistoryResponse(
      portfolioCode: json['portfolio_code']?.toString() ?? '',
      portfolioLabel: json['portfolio_label']?.toString() ?? '',
      rollingWindow: (json['rolling_window'] as num?)?.toInt() ?? 20,
      earliestDataDate: _parseDate(json['earliest_data_date']),
      latestDataDate: _parseDate(json['latest_data_date']),
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileVolatilityPoint.fromJson)
          .toList(),
      benchmarkPoints: rawBenchmark
          ?.whereType<Map<String, dynamic>>()
          .map(MobileVolatilityPoint.fromJson)
          .toList(),
    );
  }
}

class MobileReturnPoint {
  final DateTime date;
  final double expectedReturn;

  const MobileReturnPoint({
    required this.date,
    required this.expectedReturn,
  });

  factory MobileReturnPoint.fromJson(Map<String, dynamic> json) {
    return MobileReturnPoint(
      date: _parseDate(json['date']),
      expectedReturn: _asDouble(json['expected_return']),
    );
  }
}

class MobileReturnHistoryResponse {
  final DateTime earliestDataDate;
  final DateTime latestDataDate;
  final List<MobileReturnPoint> points;

  const MobileReturnHistoryResponse({
    required this.earliestDataDate,
    required this.latestDataDate,
    required this.points,
  });

  factory MobileReturnHistoryResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return MobileReturnHistoryResponse(
      earliestDataDate: _parseDate(json['earliest_data_date']),
      latestDataDate: _parseDate(json['latest_data_date']),
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileReturnPoint.fromJson)
          .toList(),
    );
  }
}

class MobileComparisonLinePoint {
  final DateTime date;
  final double returnPct;

  const MobileComparisonLinePoint({
    required this.date,
    required this.returnPct,
  });

  factory MobileComparisonLinePoint.fromJson(Map<String, dynamic> json) {
    return MobileComparisonLinePoint(
      date: _parseDate(json['date']),
      returnPct: _normalizeComparisonReturn(json['return_pct']),
    );
  }
}

class MobileComparisonLine {
  final String key;
  final String label;
  final String color;
  final String style;
  final List<MobileComparisonLinePoint> points;

  const MobileComparisonLine({
    required this.key,
    required this.label,
    required this.color,
    required this.style,
    required this.points,
  });

  factory MobileComparisonLine.fromJson(Map<String, dynamic> json) {
    return MobileComparisonLine(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      color: json['color']?.toString() ?? '#20A7DB',
      style: json['style']?.toString() ?? 'solid',
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileComparisonLinePoint.fromJson)
          .toList(),
    );
  }
}

class MobileRebalancePolicy {
  final String strategy;
  final String? scheduledRebalanceFrequency;
  final bool forceRebalanceOnSchedule;
  final String? driftCheckFrequency;
  final double? driftThreshold;

  const MobileRebalancePolicy({
    required this.strategy,
    required this.scheduledRebalanceFrequency,
    required this.forceRebalanceOnSchedule,
    required this.driftCheckFrequency,
    required this.driftThreshold,
  });

  factory MobileRebalancePolicy.fromJson(Map<String, dynamic> json) {
    return MobileRebalancePolicy(
      strategy: json['strategy']?.toString() ?? '',
      scheduledRebalanceFrequency:
          json['scheduled_rebalance_frequency']?.toString(),
      forceRebalanceOnSchedule:
          (json['force_rebalance_on_schedule'] as bool?) ?? false,
      driftCheckFrequency: json['drift_check_frequency']?.toString(),
      driftThreshold: json['drift_threshold'] == null
          ? null
          : _asDouble(json['drift_threshold']),
    );
  }
}

class MobileComparisonBacktestResponse {
  final DateTime trainStartDate;
  final DateTime trainEndDate;
  final DateTime testStartDate;
  final DateTime startDate;
  final DateTime endDate;
  final double splitRatio;
  final List<DateTime> rebalanceDates;
  final MobileRebalancePolicy? rebalancePolicy;
  final List<MobileComparisonLine> lines;

  const MobileComparisonBacktestResponse({
    required this.trainStartDate,
    required this.trainEndDate,
    required this.testStartDate,
    required this.startDate,
    required this.endDate,
    required this.splitRatio,
    required this.rebalanceDates,
    required this.rebalancePolicy,
    required this.lines,
  });

  factory MobileComparisonBacktestResponse.fromJson(Map<String, dynamic> json) {
    final rebalancePolicyJson =
        json['rebalance_policy'] as Map<String, dynamic>?;
    return MobileComparisonBacktestResponse(
      trainStartDate: _parseDate(json['train_start_date']),
      trainEndDate: _parseDate(json['train_end_date']),
      testStartDate: _parseDate(json['test_start_date']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      splitRatio: _asDouble(json['split_ratio']),
      rebalanceDates: (json['rebalance_dates'] as List<dynamic>? ?? const [])
          .map(_parseDate)
          .toList(),
      rebalancePolicy: rebalancePolicyJson == null
          ? null
          : MobileRebalancePolicy.fromJson(rebalancePolicyJson),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileComparisonLine.fromJson)
          .toList(),
    );
  }
}

// ── Earnings History ──

class MobileEarningsPoint {
  final DateTime date;
  final double totalEarnings;
  final double totalReturnPct;
  final Map<String, double> assetEarnings;

  const MobileEarningsPoint({
    required this.date,
    required this.totalEarnings,
    required this.totalReturnPct,
    required this.assetEarnings,
  });

  factory MobileEarningsPoint.fromJson(Map<String, dynamic> json) {
    final raw = json['asset_earnings'] as Map<String, dynamic>? ?? {};
    return MobileEarningsPoint(
      date: _parseDate(json['date']),
      totalEarnings: _asDouble(json['total_earnings']),
      totalReturnPct: _asDouble(json['total_return_pct']),
      assetEarnings: raw.map((k, v) => MapEntry(k, _asDouble(v))),
    );
  }
}

class MobileAssetEarningSummary {
  final String assetCode;
  final String assetName;
  final double weight;
  final double earnings;
  final double returnPct;

  const MobileAssetEarningSummary({
    required this.assetCode,
    required this.assetName,
    required this.weight,
    required this.earnings,
    required this.returnPct,
  });

  factory MobileAssetEarningSummary.fromJson(Map<String, dynamic> json) {
    return MobileAssetEarningSummary(
      assetCode: json['asset_code']?.toString() ?? '',
      assetName: json['asset_name']?.toString() ?? '',
      weight: _asDouble(json['weight']),
      earnings: _asDouble(json['earnings']),
      returnPct: _asDouble(json['return_pct']),
    );
  }
}

class MobileEarningsHistoryResponse {
  final List<MobileEarningsPoint> points;
  final double investmentAmount;
  final String startDate;
  final String endDate;
  final double totalReturnPct;
  final double totalEarnings;
  final List<MobileAssetEarningSummary> assetSummary;

  const MobileEarningsHistoryResponse({
    required this.points,
    required this.investmentAmount,
    required this.startDate,
    required this.endDate,
    required this.totalReturnPct,
    required this.totalEarnings,
    required this.assetSummary,
  });

  factory MobileEarningsHistoryResponse.fromJson(Map<String, dynamic> json) {
    return MobileEarningsHistoryResponse(
      points: (json['points'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileEarningsPoint.fromJson)
          .toList(),
      investmentAmount: _asDouble(json['investment_amount']),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      totalReturnPct: _asDouble(json['total_return_pct']),
      totalEarnings: _asDouble(json['total_earnings']),
      assetSummary: (json['asset_summary'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileAssetEarningSummary.fromJson)
          .toList(),
    );
  }
}

// ── Rebalance Simulation ──

class MobileRebalanceTimePoint {
  final DateTime date;
  final double totalValue;
  final Map<String, double> assetValues;

  const MobileRebalanceTimePoint({
    required this.date,
    required this.totalValue,
    required this.assetValues,
  });

  factory MobileRebalanceTimePoint.fromJson(Map<String, dynamic> json) {
    final raw = json['asset_values'] as Map<String, dynamic>? ?? {};
    return MobileRebalanceTimePoint(
      date: _parseDate(json['date']),
      totalValue: _asDouble(json['total_value']),
      assetValues: raw.map((k, v) => MapEntry(k, _asDouble(v))),
    );
  }
}

class MobileRebalanceEvent {
  final DateTime date;
  final double totalValue;
  final Map<String, double> preWeights;
  final Map<String, double> postWeights;
  final Map<String, double> trades;

  const MobileRebalanceEvent({
    required this.date,
    required this.totalValue,
    required this.preWeights,
    required this.postWeights,
    required this.trades,
  });

  factory MobileRebalanceEvent.fromJson(Map<String, dynamic> json) {
    final pre = json['pre_weights'] as Map<String, dynamic>? ?? {};
    final post = json['post_weights'] as Map<String, dynamic>? ?? {};
    final tr = json['trades'] as Map<String, dynamic>? ?? {};
    return MobileRebalanceEvent(
      date: _parseDate(json['date']),
      totalValue: _asDouble(json['total_value']),
      preWeights: pre.map((k, v) => MapEntry(k, _asDouble(v))),
      postWeights: post.map((k, v) => MapEntry(k, _asDouble(v))),
      trades: tr.map((k, v) => MapEntry(k, _asDouble(v))),
    );
  }
}

class MobileRebalanceSimulationResponse {
  final String startDate;
  final String endDate;
  final double investmentAmount;
  final Map<String, double> targetWeights;
  final MobileRebalancePolicy? rebalancePolicy;
  final Map<String, String> sectorNames;
  final List<MobileRebalanceTimePoint> timeSeries;
  final List<MobileRebalanceEvent> rebalanceEvents;
  final double finalValue;
  final double totalReturnPct;
  final double noRebalanceFinalValue;
  final double noRebalanceReturnPct;

  const MobileRebalanceSimulationResponse({
    required this.startDate,
    required this.endDate,
    required this.investmentAmount,
    required this.targetWeights,
    required this.rebalancePolicy,
    required this.sectorNames,
    required this.timeSeries,
    required this.rebalanceEvents,
    required this.finalValue,
    required this.totalReturnPct,
    required this.noRebalanceFinalValue,
    required this.noRebalanceReturnPct,
  });

  factory MobileRebalanceSimulationResponse.fromJson(
      Map<String, dynamic> json) {
    final tw = json['target_weights'] as Map<String, dynamic>? ?? {};
    final sn = json['sector_names'] as Map<String, dynamic>? ?? {};
    final rebalancePolicyJson =
        json['rebalance_policy'] as Map<String, dynamic>?;
    return MobileRebalanceSimulationResponse(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      investmentAmount: _asDouble(json['investment_amount']),
      targetWeights: tw.map((k, v) => MapEntry(k, _asDouble(v))),
      rebalancePolicy: rebalancePolicyJson == null
          ? null
          : MobileRebalancePolicy.fromJson(rebalancePolicyJson),
      sectorNames: sn.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      timeSeries: (json['time_series'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileRebalanceTimePoint.fromJson)
          .toList(),
      rebalanceEvents: (json['rebalance_events'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MobileRebalanceEvent.fromJson)
          .toList(),
      finalValue: _asDouble(json['final_value']),
      totalReturnPct: _asDouble(json['total_return_pct']),
      noRebalanceFinalValue: _asDouble(json['no_rebalance_final_value']),
      noRebalanceReturnPct: _asDouble(json['no_rebalance_return_pct']),
    );
  }
}

class _GroupedSector {
  final String code;
  final String name;
  final double weight;
  final List<MobileStockAllocation> tickers;

  const _GroupedSector({
    required this.code,
    required this.name,
    required this.weight,
    required this.tickers,
  });
}

// ---------------------------------------------------------------------------
// Digest models
// ---------------------------------------------------------------------------

class DigestDriver {
  final String ticker;
  final String nameKo;
  final String sectorCode;
  final double weightPct;
  final double returnPct;
  final double contributionWon;
  final String? explanationKo;

  const DigestDriver({
    required this.ticker,
    required this.nameKo,
    required this.sectorCode,
    required this.weightPct,
    required this.returnPct,
    required this.contributionWon,
    this.explanationKo,
  });

  factory DigestDriver.fromJson(Map<String, dynamic> json) {
    return DigestDriver(
      ticker: json['ticker']?.toString() ?? '',
      nameKo: json['name_ko']?.toString() ?? '',
      sectorCode: json['sector_code']?.toString() ?? '',
      weightPct: _asDouble(json['weight_pct']),
      returnPct: _asDouble(json['return_pct']),
      contributionWon: _asDouble(json['contribution_won']),
      explanationKo: json['explanation_ko']?.toString(),
    );
  }
}

class MobileDigestResponse {
  final String digestDate;
  final String periodStart;
  final String periodEnd;
  final double totalReturnPct;
  final double totalReturnWon;
  final String? narrativeKo;
  final bool hasNarrative;
  final List<DigestDriver> drivers;
  final List<DigestDriver> detractors;
  final List<String> sourcesUsed;
  final String disclaimer;
  final String generatedAt;
  final int degradationLevel;

  const MobileDigestResponse({
    required this.digestDate,
    required this.periodStart,
    required this.periodEnd,
    required this.totalReturnPct,
    required this.totalReturnWon,
    this.narrativeKo,
    required this.hasNarrative,
    required this.drivers,
    required this.detractors,
    required this.sourcesUsed,
    required this.disclaimer,
    required this.generatedAt,
    required this.degradationLevel,
  });

  factory MobileDigestResponse.fromJson(Map<String, dynamic> json) {
    return MobileDigestResponse(
      digestDate: json['digest_date']?.toString() ?? '',
      periodStart: json['period_start']?.toString() ?? '',
      periodEnd: json['period_end']?.toString() ?? '',
      totalReturnPct: _asDouble(json['total_return_pct']),
      totalReturnWon: _asDouble(json['total_return_won']),
      narrativeKo: json['narrative_ko']?.toString(),
      hasNarrative: json['has_narrative'] == true,
      drivers: (json['drivers'] as List<dynamic>?)
              ?.map((e) =>
                  DigestDriver.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      detractors: (json['detractors'] as List<dynamic>?)
              ?.map((e) =>
                  DigestDriver.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sourcesUsed: (json['sources_used'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      disclaimer: json['disclaimer']?.toString() ?? '',
      generatedAt: json['generated_at']?.toString() ?? '',
      degradationLevel: (json['degradation_level'] as num?)?.toInt() ?? 0,
    );
  }
}
