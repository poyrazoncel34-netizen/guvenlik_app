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

  group('AppEnvironment map tile attribution policy', () {
    const osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    const mapTiler =
        'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=k';

    test('default OSM template and default attribution pass', () {
      expect(
        AppEnvironment.isSafeMapTileAttribution(
          urlTemplate: AppEnvironment.defaultMapTileUrlTemplate,
          attribution: AppEnvironment.defaultMapTileAttribution,
          attributionUrl: AppEnvironment.defaultMapTileAttributionUrl,
        ),
        isTrue,
      );
    });

    test('a provider switch passes only with its own credit line', () {
      expect(
        AppEnvironment.isSafeMapTileAttribution(
          urlTemplate: mapTiler,
          attribution: AppEnvironment.defaultMapTileAttribution,
          attributionUrl: AppEnvironment.defaultMapTileAttributionUrl,
        ),
        isFalse,
        reason: 'shipping MapTiler tiles under the bare OSM line omits '
            "MapTiler's required credit",
      );
      expect(
        AppEnvironment.isSafeMapTileAttribution(
          urlTemplate: mapTiler,
          attribution: '© MapTiler © OpenStreetMap contributors',
          attributionUrl: 'https://www.maptiler.com/copyright/',
        ),
        isTrue,
      );
    });

    test('rejects credit lines without OSM or with an unsafe link', () {
      for (final (text, url) in <(String, String)>[
        ('', AppEnvironment.defaultMapTileAttributionUrl),
        ('© MapTiler', 'https://www.maptiler.com/copyright/'),
        (AppEnvironment.defaultMapTileAttribution, 'http://osm.org/copyright'),
        (AppEnvironment.defaultMapTileAttribution, 'not a url'),
      ]) {
        expect(
          AppEnvironment.isSafeMapTileAttribution(
            urlTemplate: osm,
            attribution: text,
            attributionUrl: url,
          ),
          isFalse,
          reason: '$text / $url',
        );
      }
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
