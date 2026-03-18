// ============================================================================
// ORTAM YAPILANDIRMASI (DEV / PRODUCTION)
// ============================================================================
// Kullanım:
//   flutter run --dart-define=ENV=production --dart-define=SENTRY_DSN=https://...
//   flutter build apk --dart-define=ENV=production --dart-define=SENTRY_DSN=https://...
//
// NOTE: KoruBeni is offline-first. Sentry buffers crashes locally and sends when online.
// ============================================================================

class AppEnvironment {
  AppEnvironment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProduction => _env == 'production';
  static bool get isDev => !isProduction;
  static String get name => _env;

  /// Sentry DSN — crash raporlama için.
  /// Build sırasında --dart-define=SENTRY_DSN=https://... ile set edilir.
  /// Boş bırakılırsa Sentry devre dışı kalır (dev ortamında güvenli).
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
}
