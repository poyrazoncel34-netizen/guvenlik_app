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
  static const String defaultMapTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String _revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );
  static const String _mapTileUrlTemplate = String.fromEnvironment(
    'MAP_TILE_URL_TEMPLATE',
    defaultValue: defaultMapTileUrlTemplate,
  );

  static bool get isProduction => envIsProduction(_env);
  static bool get isCiSmoke => envIsCiSmoke(_env);
  static bool get isDev => envIsDev(_env);
  static String get name => _env;
  static String get mapTileUrlTemplate => _mapTileUrlTemplate;

  // Three named environments, each matched by its OWN literal.
  //
  // `isDev` used to be `!isProduction`, so `ci_smoke` counted as "dev" -- a
  // two-valued flag inside a three-valued model (audit A-022). It happens to
  // be harmless today only because nothing branches on isDev; the next caller
  // would have inherited the wrong answer.
  //
  // These take the environment as a PARAMETER because the getters above read
  // `String.fromEnvironment`, a compile-time constant: no unit test can vary
  // it, which is precisely why the defect was never caught by a test. With the
  // seam, the ci_smoke case is testable without a --dart-define run.
  //
  // Public, not @visibleForTesting: RevenueCatService's key policy classifies
  // through these same predicates. Its private copy of `ENV` was the second
  // two-valued flag, and one classification must not be written twice.
  static bool envIsProduction(String env) => env == 'production';

  static bool envIsCiSmoke(String env) => env == 'ci_smoke';

  static bool envIsDev(String env) => env == 'dev';

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

  static bool isSafeMapTileUrlTemplate(String value) {
    if (value.isEmpty || RegExp(r'\s').hasMatch(value)) return false;
    for (final placeholder in const <String>['{z}', '{x}', '{y}']) {
      if (placeholder.allMatches(value).length != 1) return false;
    }
    final resolved = value
        .replaceAll('{z}', '0')
        .replaceAll('{x}', '0')
        .replaceAll('{y}', '0');
    final uri = Uri.tryParse(resolved);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
  }

  static void validateReleaseConfiguration({required bool isReleaseMode}) {
    if (!isReleaseMode) return;
    if (!isSafeMapTileUrlTemplate(_mapTileUrlTemplate)) {
      throw StateError(
        'Release requires a valid HTTPS map tile URL template with exactly '
        'one {z}, {x}, and {y} placeholder',
      );
    }
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
