import 'package:dio/dio.dart';

import '../exceptions/kyc_failure.dart';
import '../idz_config.dart';

/// Internal HTTP client that wraps [Dio] with IDz auth, retry, and
/// error mapping. Not for direct use — call [IdzApiClient] instead.
class DioClient {
  late final Dio _dio;

  /// Maximum retries for transient failures (timeouts + connection
  /// errors). 4xx/5xx are not retried automatically.
  static const int _maxRetries = 2;

  DioClient({required IdzConfig config}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.timeout,
        receiveTimeout: config.timeout,
        // Multipart for the verification POSTs; JSON for everything else.
        // Per-request Options can override.
        contentType: 'application/json',
        headers: <String, dynamic>{
          'Authorization': 'Bearer ${config.apiKey}',
          'User-Agent': 'idz-flutter/0.1.0',
        },
      ),
    );
    _setupInterceptors(config.enableLogging);
  }

  /// Test-only constructor — no interceptors, no auth header injection.
  /// Bring your own [Dio] preconfigured with whatever you need.
  DioClient.test(Dio dio) : _dio = dio;

  void _setupInterceptors(bool enableLogging) {
    if (enableLogging) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final failure = mapDioError(error);
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: failure,
              message: error.message,
            ),
          );
        },
      ),
    );
  }

  /// Map a [DioException] to the right [KycFailure] variant.
  KycFailure mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const KycFailureTimeout();
      case DioExceptionType.connectionError:
        return const KycFailureNetwork();
      case DioExceptionType.badResponse:
        return _mapBadResponse(error);
      case DioExceptionType.cancel:
        return const KycFailureNetwork();
      case DioExceptionType.badCertificate:
        return const KycFailureNetwork();
      case DioExceptionType.unknown:
        return KycFailureUnknown(error.message ?? 'Unknown error');
    }
  }

  KycFailure _mapBadResponse(DioException error) {
    final response = error.response;
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final errorCode = _extractErrorCode(body);
    final message =
        _extractErrorMessage(body) ?? error.message ?? 'Unknown error';

    switch (status) {
      case 400:
      case 422:
        return KycFailureInvalidInput(message, errorCode: errorCode);
      case 401:
        return KycFailureUnauthorized(message);
      case 403:
        return KycFailureForbidden(message);
      case 404:
        return KycFailureNotFound(message);
      case 409:
        return KycFailureIdempotencyConflict(message);
      default:
        if (status >= 500 && status < 600) {
          return KycFailureServerError(status, message);
        }
        return KycFailureServerError(status, message);
    }
  }

  /// Pull a structured `error` code out of `{"detail": {"error": "...", ...}}`
  /// or `{"error": "..."}` bodies.
  String? _extractErrorCode(Object? body) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        final code = detail['error'];
        if (code is String) return code;
      }
      final code = body['error'];
      if (code is String) return code;
    }
    return null;
  }

  String? _extractErrorMessage(Object? body) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        final msg = detail['message'];
        if (msg is String) return msg;
      }
      if (detail is String) return detail;
      final msg = body['message'];
      if (msg is String) return msg;
    }
    return null;
  }

  /// Run [request] with retry on transient failures only.
  Future<Response<T>> requestWithRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    var attempts = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        attempts++;
        if (attempts > _maxRetries || !_isRetryable(e)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: attempts));
      }
    }
  }

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  Dio get dio => _dio;

  void dispose() {
    _dio.close();
  }
}
