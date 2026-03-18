// ============================================================================
// ORTAM YAPILANDIRMASI (DEV / PRODUCTION)
// ============================================================================
// Kullanım:
//   flutter run --dart-define=ENV=production
//   flutter build apk --dart-define=ENV=production
//
// NOTE: KoruBeni is 100% offline-only. No remote API exists or is planned.
// ENV is used only for debug/release logging behavior.
// ============================================================================

class AppEnvironment {
  AppEnvironment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProduction => _env == 'production';
  static bool get isDev => !isProduction;
  static String get name => _env;
}
