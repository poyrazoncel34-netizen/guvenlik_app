import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment RevenueCat public SDK key policy', () {
    test('accepts a non-secret public SDK key shape', () {
      expect(
        AppEnvironment.isProductionRevenueCatAndroidSdkKey(
          'goog_KoruBeniPublicSdkKey123',
        ),
        isTrue,
      );
    });

    test('rejects secrets, placeholders, smoke sentinel, and whitespace', () {
      for (final value in [
        '',
        '   ',
        'sk_server_secret_must_never_be_embedded',
        'placeholder_build_check',
        'dummy_key',
        AppEnvironment.ciSmokeRevenueCatKey,
        'goog_key with whitespace',
      ]) {
        expect(
          AppEnvironment.isProductionRevenueCatAndroidSdkKey(value),
          isFalse,
          reason: 'must reject unsafe key value category: $value',
        );
      }
    });

    test('allows test store key only for non-production client setup', () {
      expect(
        AppEnvironment.isSafeRevenueCatClientSdkKey('test_local_store_key'),
        isTrue,
      );
      expect(
        AppEnvironment.isProductionRevenueCatAndroidSdkKey(
          'test_local_store_key',
        ),
        isFalse,
      );
      expect(
        AppEnvironment.isProductionRevenueCatAndroidSdkKey('appl_wrong_store'),
        isFalse,
      );
    });
  });
}
