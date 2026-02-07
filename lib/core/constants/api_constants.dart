import '../config/app_environment.dart';

/// API endpoint sabitleri. Base URL ortama göre (ENV) değişir.
class ApiConstants {
  static String get baseUrl => AppEnvironment.apiBaseUrl;

  // Endpoint path'leri (backend hazır olduğunda kullanılacak)
  static const String emergency = '/emergency';
  static const String contacts = '/contacts';
  static const String profile = '/profile';
  static const String location = '/location';
  static const String activity = '/activity';
}
