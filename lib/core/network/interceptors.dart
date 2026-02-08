import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Attaches Firebase auth token to every outgoing request.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('AuthInterceptor: token fetch failed: $e');
    }
    handler.next(options);
  }
}

/// Retries failed requests up to [maxRetries] times for
/// timeout and 5xx server errors.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({required this.dio, this.maxRetries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final shouldRetry = _isRetryable(err);
    if (!shouldRetry) {
      handler.next(err);
      return;
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        debugPrint(
          'RetryInterceptor: attempt $attempt for ${err.requestOptions.path}',
        );
        await Future.delayed(
          Duration(milliseconds: 500 * attempt),
        ); // exponential backoff

        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        if (attempt >= maxRetries) {
          return handler.next(e);
        }
      }
    }
    handler.next(err);
  }

  bool _isRetryable(DioException err) {
    // Retry on timeouts
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    // Retry on 5xx server errors
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return true;
    }
    return false;
  }
}
