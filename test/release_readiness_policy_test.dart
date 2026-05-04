import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/feature_access_matrix.dart';

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

    test('FeatureAccessMatrix keeps panic Pro and contacts/siren free', () {
      expect(FeatureAccessMatrix.entries[PremiumFeature.panic]!.isPro, isTrue);
      expect(
        FeatureAccessMatrix.entries[PremiumFeature.contacts]!.isFree,
        isTrue,
      );
      expect(FeatureAccessMatrix.entries[PremiumFeature.siren]!.isFree, isTrue);
    });

    test('public copy does not claim contacts or siren are Pro-only', () {
      final files = [
        File('store/google_play_listing.md'),
        File('store/play_store_listing_tr.md'),
        File('store/play_store_listing_en.md'),
        File('store/STORE_LISTING_COPY_PASTE.md'),
        File('store/kullanim_sartlari.html'),
        File('.gh-pages-publish/kullanim_sartlari.html'),
        File('docs/play_console_declarations.md'),
      ].where((file) => file.existsSync());

      final violations = <String>[];
      final patterns = [
        RegExp(
          r'(contacts?|kişiler|acil kişi|rehber)[^\n.]{0,80}\bpro\b',
          caseSensitive: false,
        ),
        RegExp(
          r'\bpro\b[^\n.]{0,80}(contacts?|kişiler|acil kişi|rehber)',
          caseSensitive: false,
        ),
        RegExp(r'siren[^\n.]{0,80}\bpro\b', caseSensitive: false),
        RegExp(r'\bpro\b[^\n.]{0,80}siren', caseSensitive: false),
      ];

      for (final file in files) {
        final content = file.readAsStringSync();
        final contentForProOnlyScan = content
            .split('\n')
            .where(
              (line) =>
                  !line.toLowerCase().contains('siren ücretsiz') &&
                  !line.toLowerCase().contains('siren are free'),
            )
            .join('\n');
        for (final pattern in patterns) {
          if (pattern.hasMatch(contentForProOnlyScan)) {
            violations.add('${file.path}:${pattern.pattern}');
          }
        }
      }
      expect(violations, isEmpty);
    });

    test(
      'audio recording and microphone collection are disabled in docs/code',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(manifest, isNot(contains('android.permission.RECORD_AUDIO')));
        expect(
          manifest,
          isNot(contains('android.permission.FOREGROUND_SERVICE_MICROPHONE')),
        );

        final inventory = File(
          'docs/kvkk_veri_isleme_envanteri.md',
        ).readAsStringSync().toLowerCase();
        expect(inventory, contains('devre dış'));
        expect(inventory, contains('record_audio'));
        expect(inventory, isNot(contains('consent_audio')));
        expect(inventory, isNot(contains('delil niteliğinde kayıt')));
      },
    );

    test('production-facing legal URLs do not use placeholders', () {
      final constants = File(
        'lib/core/constants/app_constants.dart',
      ).readAsStringSync();
      final dataDeletion = File('store/data_deletion.html').readAsStringSync();

      expect(
        constants,
        contains('https://poyrazoncel34-netizen.github.io/guvenlik_app'),
      );
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
