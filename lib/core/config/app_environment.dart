// ============================================================================
// ORTAM YAPILANDIRMASI (DEV / PRODUCTION)
// ============================================================================
// Kullanım:
//   flutter run --dart-define=ENV=production
//   flutter build apk --dart-define=ENV=production
//
// NOTE: KoruBeni is offline-first. No third-party crash reporting (KVKK compliance).
// ============================================================================

class AppEnvironment {
  AppEnvironment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProduction => _env == 'production';
  static bool get isDev => !isProduction;
  static String get name => _env;
}
