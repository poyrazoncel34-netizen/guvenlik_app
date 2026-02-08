// ============================================================================
// ORTAM YAPILANDIRMASI (DEV / PRODUCTION)
// ============================================================================
// Kullanım:
//   flutter run --dart-define=ENV=production
//   flutter build apk --dart-define=ENV=production
// ============================================================================

class AppEnvironment {
  AppEnvironment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProduction => _env == 'production';
  static bool get isDev => !isProduction;
  static String get name => _env;

  /// API base URL - production'da gerçek backend, dev'de mock/placeholder
  static String get apiBaseUrl {
    if (isProduction) {
      return 'https://api.korubeni.com'; // Production backend
    }
    return 'https://api.example.com'; // Dev/test
  }
}
