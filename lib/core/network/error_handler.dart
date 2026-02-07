import 'package:dio/dio.dart';

class NetworkError {
  final String message;
  final int? statusCode;

  const NetworkError({required this.message, this.statusCode});

  factory NetworkError.fromDio(DioException exception) {
    return NetworkError(
      message: exception.message ?? 'Ağ hatası oluştu',
      statusCode: exception.response?.statusCode,
    );
  }
}
