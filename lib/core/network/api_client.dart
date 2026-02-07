import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import 'interceptors.dart';

class ApiClient {
  static Dio build() {
    final options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    );
    final dio = Dio(options);

    dio.interceptors.addAll([
      AuthInterceptor(),
      RetryInterceptor(dio: dio, maxRetries: 3),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: false,
          error: true,
          compact: true,
        ),
    ]);
    return dio;
  }
}
