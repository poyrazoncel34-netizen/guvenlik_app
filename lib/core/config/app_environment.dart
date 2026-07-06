// ============================================================================
// ORTAM YAPILANDIRMASI (DEV / PRODUCTION)
// ============================================================================
// Kullanım:
//   flutter run --dart-define=ENV=production
//   flutter build appbundle --release --flavor play --dart-define=ENV=production
//
// NOTE: KoruBeni is offline-first. No third-party crash reporting (KVKK compliance).
// ============================================================================


class AppEnvironment {
  AppEnvironment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String _revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  static bool get isProduction => _env == 'production';
  static bool get isDev => !isProduction;
  static String get name => _env;

  static void validateReleaseConfiguration({required bool isReleaseMode}) {
    if (!isReleaseMode) return;
    if (!isProduction) {
      throw StateError('Release build requires --dart-define=ENV=production');
    }
    if (_revenueCatAndroidApiKey.trim().isEmpty) {
      throw StateError(
        'Release build requires --dart-define=REVENUECAT_ANDROID_API_KEY',
      );
    }
  }
}
