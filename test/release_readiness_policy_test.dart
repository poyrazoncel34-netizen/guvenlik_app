import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release readiness policy files', () {
    test('Gradle release builds require production env and secrets', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('dartDefineValue("ENV")'));
      expect(gradle, contains('ENV=production'));
      expect(gradle, contains('REVENUECAT_ANDROID_API_KEY'));
      expect(gradle, contains('ENCRYPTION_KEY'));
    });

    test('Play declaration and data safety docs exist', () {
      expect(File('docs/play_console_declarations.md').existsSync(), isTrue);
      expect(
        File('docs/google_play_data_safety_notes.md').existsSync(),
        isTrue,
      );
      expect(File('docs/feature_matrix_verification.md').existsSync(), isTrue);
    });

    test(
      'privacy policy discloses RevenueCat and avoids profile photo claim',
      () {
        final privacy = File('store/privacy_policy.html').readAsStringSync();
        expect(privacy, contains('RevenueCat'));
        expect(privacy.toLowerCase(), isNot(contains('profil fotografi')));
      },
    );

    test('store listing says panic SOS is Pro-only', () {
      final listing = File('store/play_store_listing_tr.md').readAsStringSync();
      expect(listing, contains('Panik/SOS'));
      expect(listing, contains('KoruBeni Pro'));
      expect(listing, isNot(contains('ücretsiz SOS')));
    });

    test('production-facing legal URLs do not use placeholders', () {
      final constants = File(
        'lib/core/constants/app_constants.dart',
      ).readAsStringSync();
      final dataDeletion = File('store/data_deletion.html').readAsStringSync();

      expect(constants, contains('https://poyrazoncel.github.io/korubeni'));
      expect(constants, isNot(contains('TODO_PUBLIC_ACCOUNT_DELETION_URL')));
      expect(dataDeletion, isNot(contains('TODO_PUBLIC_ACCOUNT_DELETION_URL')));
    });

    test(
      'legal copy does not claim guardian consent or in-app age verification',
      () {
        final privacy = File('store/privacy_policy.html').readAsStringSync();
        final disclosure = File(
          'store/aydinlatma_metni.html',
        ).readAsStringSync();

        expect(privacy, isNot(contains('vasi onay')));
        expect(privacy, isNot(contains('yas dogrulamasi yapilir')));
        expect(disclosure, isNot(contains('veli veya vasi')));
        expect(disclosure, isNot(contains('yaş doğrulaması yapılmaktadır')));
      },
    );
  });
}
