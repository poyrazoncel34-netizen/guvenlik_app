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

  static const String ciSmokeRevenueCatKey = 'NON_RELEASE_SMOKE_REVENUECAT_KEY';

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String _revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  static bool get isProduction => _env == 'production';
  static bool get isCiSmoke => _env == 'ci_smoke';
  static bool get isDev => !isProduction;
  static String get name => _env;

  static bool _hasSafeRevenueCatClientKeyShape(String value) {
    final normalized = value.trim();
    final lower = normalized.toLowerCase();
    return normalized.isNotEmpty &&
        !RegExp(r'\s').hasMatch(normalized) &&
        !lower.startsWith('sk_') &&
        !lower.contains('placeholder') &&
        !lower.contains('dummy') &&
        !lower.contains('non_release_smoke');
  }

  static bool isSafeRevenueCatClientSdkKey(String value) {
    final lower = value.trim().toLowerCase();
    return _hasSafeRevenueCatClientKeyShape(value) &&
        (lower.startsWith('goog_') || lower.startsWith('test_'));
  }

  static bool isProductionRevenueCatAndroidSdkKey(String value) {
    return _hasSafeRevenueCatClientKeyShape(value) &&
        value.trim().toLowerCase().startsWith('goog_');
  }

  static void validateReleaseConfiguration({required bool isReleaseMode}) {
    if (!isReleaseMode) return;
    if (isCiSmoke && _revenueCatAndroidApiKey == ciSmokeRevenueCatKey) {
      return;
    }
    if (!isProduction) {
      throw StateError('Play release requires --dart-define=ENV=production');
    }
    if (!isProductionRevenueCatAndroidSdkKey(_revenueCatAndroidApiKey)) {
      throw StateError(
        'Play release requires a goog_ RevenueCat Android public SDK key; '
        'test_, sk_, and placeholder keys are forbidden',
      );
    }
  }
}
