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

  group('AppEnvironment map tile URL policy', () {
    test('accepts HTTPS templates with one z x and y placeholder', () {
      expect(
        AppEnvironment.isSafeMapTileUrlTemplate(
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        isTrue,
      );
      expect(
        AppEnvironment.isSafeMapTileUrlTemplate(
          'https://tiles.example.test/styles/basic/{z}/{x}/{y}.png?key=public',
        ),
        isTrue,
      );
    });

    test('rejects insecure malformed or credential-bearing templates', () {
      for (final value in <String>[
        '',
        'http://tile.openstreetmap.org/{z}/{x}/{y}.png',
        'https://tile.openstreetmap.org/{z}/{x}.png',
        'https://tile.openstreetmap.org/{z}/{x}/{y}/{y}.png',
        'https://user:pass@tiles.example.test/{z}/{x}/{y}.png',
        'https://tiles.example.test/{z}/{x}/{y}.png#fragment',
        'https://tiles.example.test/{z}/{x}/{y}.png with-space',
      ]) {
        expect(
          AppEnvironment.isSafeMapTileUrlTemplate(value),
          isFalse,
          reason: value,
        );
      }
    });
  });
}
