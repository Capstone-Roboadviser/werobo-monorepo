import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static const List<String> _dataSources = <String>[
    'managed_universe',
    'stock_combination_demo',
  ];

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);

  Future<MobileRecommendationResponse> fetchRecommendation({
    required double propensityScore,
    String investmentHorizon = 'medium',
  }) {
    return _postWithFallback(
      path: '/portfolios/recommendation',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'propensity_score': propensityScore.clamp(0, 100),
        'investment_horizon': investmentHorizon,
        'data_source': dataSource,
      },
      parser: MobileRecommendationResponse.fromJson,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<MobileVolatilityHistoryResponse> fetchVolatilityHistory({
    required String riskProfile,
    String investmentHorizon = 'medium',
    int rollingWindow = 20,
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
      timeout: const Duration(seconds: 20),
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
      timeout: const Duration(seconds: 20),
    );
  }

  Future<MobileComparisonBacktestResponse> fetchComparisonBacktest() {
    return _postWithFallback(
      path: '/portfolios/comparison-backtest',
      bodyForDataSource: (dataSource) => <String, dynamic>{
        'data_source': dataSource,
      },
      parser: MobileComparisonBacktestResponse.fromJson,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<T> _postWithFallback<T>({
    required String path,
    required Map<String, dynamic> Function(String dataSource) bodyForDataSource,
    required T Function(Map<String, dynamic> json) parser,
    required Duration timeout,
  }) async {
    Object? lastError;
    final attemptLogs = <String>[];

    for (final dataSource in _dataSources) {
      try {
        return await _post(
          path: path,
          body: bodyForDataSource(dataSource),
          parser: parser,
          timeout: timeout,
        );
      } catch (error) {
        lastError = error;
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
  }) async {
    final request = await _client
        .postUrl(Uri.parse('$baseUrl/api/v1$path'))
        .timeout(timeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
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
}
