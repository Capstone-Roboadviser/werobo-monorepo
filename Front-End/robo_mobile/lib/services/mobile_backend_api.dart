import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/debug_page_logger.dart';
import '../models/mobile_backend_models.dart';

class MobileBackendException implements Exception {
  final String message;
  final int? statusCode;
  final List<String> attemptLogs;

  const MobileBackendException(
    this.message, {
    this.statusCode,
    this.attemptLogs = const [],
  });

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return '$statusCode: $message';
  }
}

class MobileBackendApi {
  MobileBackendApi._internal();

  static final MobileBackendApi instance = MobileBackendApi._internal();

  static const String baseUrl =
      'https://robomobilebackend-production.up.railway.app';
  static const Duration _defaultTimeout = Duration(seconds: 45);
  static const List<String> _dataSources = <String>[
    'managed_universe',
    'stock_combination_demo',
  ];

  final http.Client _client = http.Client();

  Future<MobileRecommendationResponse> fetchRecommendation({
    required double propensityScore,
    String investmentHorizon = 'medium',
    String? preferredDataSource,
  }) {
    return _postWithFallback(
      path: '/portfolios/recommendation',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'propensity_score': propensityScore.clamp(0, 100),
        'investment_horizon': investmentHorizon,
        'data_source': dataSource,
      },
      parser: MobileRecommendationResponse.fromJson,
      timeout: _defaultTimeout,
      preferredDataSource: preferredDataSource,
    );
  }

  Future<MobileFrontierPreviewResponse> fetchFrontierPreview({
    required double propensityScore,
    String investmentHorizon = 'medium',
    int samplePoints = 61,
    String? preferredDataSource,
  }) {
    return _postWithFallback(
      path: '/portfolios/frontier-preview',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'propensity_score': propensityScore.clamp(0, 100),
        'investment_horizon': investmentHorizon,
        'data_source': dataSource,
        'sample_points': samplePoints,
      },
      parser: MobileFrontierPreviewResponse.fromJson,
      timeout: _defaultTimeout,
      preferredDataSource: preferredDataSource,
    );
  }

  Future<MobileFrontierSelectionResponse> fetchFrontierSelection({
    required double propensityScore,
    required double targetVolatility,
    String investmentHorizon = 'medium',
    String? preferredDataSource,
  }) {
    return _postWithFallback(
      path: '/portfolios/frontier-selection',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'propensity_score': propensityScore.clamp(0, 100),
        'investment_horizon': investmentHorizon,
        'data_source': dataSource,
        'target_volatility': targetVolatility,
      },
      parser: MobileFrontierSelectionResponse.fromJson,
      timeout: _defaultTimeout,
      preferredDataSource: preferredDataSource,
    );
  }

  Future<MobileVolatilityHistoryResponse> fetchVolatilityHistory({
    required String riskProfile,
    String investmentHorizon = 'medium',
    int rollingWindow = 20,
    String? preferredDataSource,
  }) {
    return _postWithFallback(
      path: '/portfolios/volatility-history',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'risk_profile': riskProfile,
        'investment_horizon': investmentHorizon,
        'rolling_window': rollingWindow,
        'data_source': dataSource,
      },
      parser: MobileVolatilityHistoryResponse.fromJson,
      timeout: _defaultTimeout,
      preferredDataSource: preferredDataSource,
    );
  }

  Future<MobileReturnHistoryResponse> fetchReturnHistory({
    required String riskProfile,
    String investmentHorizon = 'medium',
    int rollingWindow = 20,
  }) {
    return _postWithFallback(
      path: '/portfolios/return-history',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'risk_profile': riskProfile,
        'investment_horizon': investmentHorizon,
        'rolling_window': rollingWindow,
        'data_source': dataSource,
      },
      parser: MobileReturnHistoryResponse.fromJson,
      timeout: _defaultTimeout,
    );
  }

  Future<MobileEarningsHistoryResponse> fetchEarningsHistory({
    required Map<String, double> weights,
    required String startDate,
    double investmentAmount = 100000000,
  }) {
    return _postWithFallback(
      path: '/portfolio/earnings-history',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'weights': weights,
        'start_date': startDate,
        'investment_amount': investmentAmount,
        'data_source': dataSource,
      },
      parser: MobileEarningsHistoryResponse.fromJson,
      timeout: _defaultTimeout,
    );
  }

  Future<MobileRebalanceSimulationResponse> fetchRebalanceSimulation({
    required Map<String, double> weights,
    required String startDate,
    double investmentAmount = 100000000,
  }) {
    return _postWithFallback(
      path: '/portfolio/rebalance-simulation',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'weights': weights,
        'start_date': startDate,
        'investment_amount': investmentAmount,
        'data_source': dataSource,
      },
      parser: MobileRebalanceSimulationResponse.fromJson,
      timeout: _defaultTimeout,
    );
  }

  Future<MobileComparisonBacktestResponse> fetchComparisonBacktest() {
    return _postWithFallback(
      path: '/portfolios/comparison-backtest',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'data_source': dataSource,
      },
      parser: MobileComparisonBacktestResponse.fromJson,
      timeout: _defaultTimeout,
    );
  }

  Future<MobileAuthSession> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    const path = '/auth/signup';
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    };
    logApi('start', 'signup', {
      'email': body['email'],
    });
    try {
      final result = await _post(
        path: path,
        body: body,
        parser: MobileAuthSession.fromJson,
        timeout: _defaultTimeout,
      );
      logApi('success', 'signup', {
        'email': body['email'],
      });
      return result;
    } catch (error) {
      logApi('fail', 'signup', {
        'email': body['email'],
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<MobileAuthSession> login({
    required String email,
    required String password,
  }) async {
    const path = '/auth/login';
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
    };
    logApi('start', 'login', {
      'email': body['email'],
    });
    try {
      final result = await _post(
        path: path,
        body: body,
        parser: MobileAuthSession.fromJson,
        timeout: _defaultTimeout,
      );
      logApi('success', 'login', {
        'email': body['email'],
      });
      return result;
    } catch (error) {
      logApi('fail', 'login', {
        'email': body['email'],
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<MobileCurrentAuthSession> fetchCurrentAuthSession({
    required String accessToken,
  }) async {
    logApi('start', 'fetchCurrentAuthSession');
    try {
      final result = await _get(
        path: '/auth/me',
        parser: MobileCurrentAuthSession.fromJson,
        timeout: _defaultTimeout,
        headers: _authHeaders(accessToken),
      );
      logApi('success', 'fetchCurrentAuthSession', {
        'provider': authProviderTypeToApi(result.user.provider),
      });
      return result;
    } catch (error) {
      logApi('fail', 'fetchCurrentAuthSession', {
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<void> logout({
    required String accessToken,
  }) async {
    logApi('start', 'logout');
    try {
      await _post(
        path: '/auth/logout',
        body: const <String, dynamic>{},
        parser: (_) => null,
        timeout: _defaultTimeout,
        headers: _authHeaders(accessToken),
      );
      logApi('success', 'logout');
    } catch (error) {
      logApi('fail', 'logout', {
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<MobileAccountDashboard> fetchPortfolioAccountDashboard({
    required String accessToken,
  }) async {
    logApi('start', 'fetchPortfolioAccountDashboard');
    try {
      final result = await _get(
        path: '/account/dashboard',
        parser: MobileAccountDashboard.fromJson,
        timeout: _defaultTimeout,
        headers: _authHeaders(accessToken),
      );
      logApi('success', 'fetchPortfolioAccountDashboard', {
        'hasAccount': result.hasAccount,
      });
      return result;
    } catch (error) {
      logApi('fail', 'fetchPortfolioAccountDashboard', {
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<MobileAccountDashboard> createPortfolioAccount({
    required String accessToken,
    required MobileRecommendationResponse recommendation,
    required MobilePortfolioRecommendation portfolio,
    required double initialCashAmount,
  }) async {
    const path = '/account';
    final body = <String, dynamic>{
      'data_source': recommendation.dataSource,
      'investment_horizon': recommendation.resolvedProfile.investmentHorizon,
      'portfolio_code': portfolio.code,
      'portfolio_label': portfolio.label,
      'portfolio_id': portfolio.portfolioId,
      'target_volatility': portfolio.targetVolatility,
      'expected_return': portfolio.expectedReturn,
      'volatility': portfolio.volatility,
      'sharpe_ratio': portfolio.sharpeRatio,
      'initial_cash_amount': initialCashAmount,
      'sector_allocations':
          portfolio.sectorAllocations.map((item) => item.toJson()).toList(),
      'stock_allocations':
          portfolio.stockAllocations.map((item) => item.toJson()).toList(),
    };
    logApi('start', 'createPortfolioAccount', {
      'portfolio': portfolio.code,
      'amount': initialCashAmount.toInt(),
    });
    try {
      final result = await _post(
        path: path,
        body: body,
        parser: MobileAccountDashboard.fromJson,
        timeout: _defaultTimeout,
        headers: _authHeaders(accessToken),
      );
      logApi('success', 'createPortfolioAccount', {
        'portfolio': portfolio.code,
      });
      return result;
    } catch (error) {
      logApi('fail', 'createPortfolioAccount', {
        'portfolio': portfolio.code,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<MobileAccountDashboard> cashInPortfolioAccount({
    required String accessToken,
    required double amount,
  }) async {
    logApi('start', 'cashInPortfolioAccount', {
      'amount': amount.toInt(),
    });
    try {
      final result = await _post(
        path: '/account/cash-in',
        body: <String, dynamic>{
          'amount': amount,
        },
        parser: MobileAccountDashboard.fromJson,
        timeout: _defaultTimeout,
        headers: _authHeaders(accessToken),
      );
      logApi('success', 'cashInPortfolioAccount', {
        'amount': amount.toInt(),
      });
      return result;
    } catch (error) {
      logApi('fail', 'cashInPortfolioAccount', {
        'amount': amount.toInt(),
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<T> _postWithFallback<T>({
    required String path,
    required Map<String, dynamic> Function(String dataSource) bodyForDataSource,
    required T Function(Map<String, dynamic> json) parser,
    required Duration timeout,
    String? preferredDataSource,
  }) async {
    Object? lastError;
    final attemptLogs = <String>[];
    final dataSources = preferredDataSource == null
        ? _dataSources
        : <String>[preferredDataSource];
    final operation = _operationName(path);

    for (final dataSource in dataSources) {
      final body = bodyForDataSource(dataSource);
      logApi('start', operation, {
        'dataSource': dataSource,
        'body': _formatBody(body),
      });
      try {
        final result = await _post(
          path: path,
          body: body,
          parser: parser,
          timeout: timeout,
        );
        logApi('success', operation, {
          'dataSource': dataSource,
        });
        return result;
      } catch (error) {
        lastError = error;
        logApi('fail', operation, {
          'dataSource': dataSource,
          'error': error.toString(),
        });
        attemptLogs.add(_formatAttemptLog(
          path: path,
          dataSource: dataSource,
          error: error,
        ));
      }
    }

    if (lastError is MobileBackendException) {
      throw MobileBackendException(
        lastError.message,
        statusCode: lastError.statusCode,
        attemptLogs: attemptLogs,
      );
    }
    if (lastError is TimeoutException) {
      throw MobileBackendException(
        '서버 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.',
        attemptLogs: attemptLogs,
      );
    }
    throw MobileBackendException(
      lastError?.toString() ?? '알 수 없는 오류가 발생했습니다.',
      attemptLogs: attemptLogs,
    );
  }

  Future<T> _post<T>({
    required String path,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic> json) parser,
    required Duration timeout,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/v1$path'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            ...headers,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final responseBody = response.body;
    final decoded = responseBody.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(responseBody);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is! Map<String, dynamic>) {
        throw const MobileBackendException('응답 형식을 해석할 수 없습니다.');
      }
      return parser(decoded);
    }

    final detail =
        decoded is Map<String, dynamic> ? decoded['detail']?.toString() : null;
    throw MobileBackendException(
      detail ?? '서버 요청에 실패했습니다.',
      statusCode: response.statusCode,
    );
  }

  Future<T> _get<T>({
    required String path,
    required T Function(Map<String, dynamic> json) parser,
    required Duration timeout,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1$path'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...headers,
      },
    ).timeout(timeout);
    final responseBody = response.body;
    final decoded = responseBody.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(responseBody);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is! Map<String, dynamic>) {
        throw const MobileBackendException('응답 형식을 해석할 수 없습니다.');
      }
      return parser(decoded);
    }

    final detail =
        decoded is Map<String, dynamic> ? decoded['detail']?.toString() : null;
    throw MobileBackendException(
      detail ?? '서버 요청에 실패했습니다.',
      statusCode: response.statusCode,
    );
  }

  String _formatAttemptLog({
    required String path,
    required String dataSource,
    required Object error,
  }) {
    if (error is MobileBackendException) {
      final status = error.statusCode == null ? 'error' : '${error.statusCode}';
      return '$dataSource $path -> $status ${error.message}';
    }
    if (error is TimeoutException) {
      return '$dataSource $path -> timeout';
    }
    return '$dataSource $path -> ${error.runtimeType}';
  }

  String _operationName(String path) {
    switch (path) {
      case '/portfolios/recommendation':
        return 'fetchRecommendation';
      case '/portfolios/frontier-preview':
        return 'fetchFrontierPreview';
      case '/portfolios/frontier-selection':
        return 'fetchFrontierSelection';
      case '/portfolios/volatility-history':
        return 'fetchVolatilityHistory';
      case '/portfolios/return-history':
        return 'fetchReturnHistory';
      case '/portfolio/earnings-history':
        return 'fetchEarningsHistory';
      case '/portfolio/rebalance-simulation':
        return 'fetchRebalanceSimulation';
      case '/portfolios/comparison-backtest':
        return 'fetchComparisonBacktest';
      case '/auth/me':
        return 'fetchCurrentAuthSession';
      case '/auth/logout':
        return 'logout';
      case '/account/dashboard':
        return 'fetchPortfolioAccountDashboard';
      case '/account':
        return 'createPortfolioAccount';
      case '/account/cash-in':
        return 'cashInPortfolioAccount';
      default:
        return path;
    }
  }

  String _formatBody(Map<String, dynamic> body) {
    return body.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
  }

  Map<String, String> _authHeaders(String accessToken) {
    return <String, String>{
      'Authorization': 'Bearer $accessToken',
    };
  }
}
