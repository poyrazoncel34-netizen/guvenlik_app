import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/constants/legal_texts.dart';
import 'package:guvenlik_app/core/constants/feature_access_matrix.dart';
import 'package:guvenlik_app/core/constants/legal_constants.dart';

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
      'privacy policy discloses RevenueCat and avoids stale profile photo claim',
      () {
        final privacy = File('store/privacy_policy.html').readAsStringSync();
        final disclosure = File(
          'store/aydinlatma_metni.html',
        ).readAsStringSync().toLowerCase();
        final publishedDisclosure = File(
          '.gh-pages-publish/aydinlatma.html',
        ).readAsStringSync().toLowerCase();
        final playForms = [
          File('store/DATA_SAFETY_FORM.md'),
          File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
          File('docs/play_console_declarations.md'),
        ].map((file) => file.readAsStringSync().toLowerCase()).join('\n');
        final englishPrivacy = File(
          'store/privacy_policy_en.html',
        ).readAsStringSync().toLowerCase();
        final legalTexts = File(
          'lib/constants/legal_texts.dart',
        ).readAsStringSync().toLowerCase();

        expect(privacy, contains('RevenueCat'));
        expect(privacy.toLowerCase(), isNot(contains('profil fotografi')));
        expect(disclosure, isNot(contains('profil fotoğrafı')));
        expect(publishedDisclosure, isNot(contains('profil fotoğrafı')));
        expect(publishedDisclosure, contains('sahte çağrı avatarı'));
        expect(publishedDisclosure, contains('teknik ağ isteği'));
        expect(playForms, isNot(contains('profile/fake-call avatar')));
        expect(playForms, contains('fake-call avatar'));
        expect(englishPrivacy, isNot(contains('profile photo')));
        expect(englishPrivacy, contains('optional fake call avatar'));
        expect(legalTexts, isNot(contains('profil fotoğrafı')));
        expect(legalTexts, contains('sahte çağrı avatarı'));
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

    test('KVKK inventory avoids stale crash biometric and transfer claims', () {
      final inventory = File(
        'docs/kvkk_veri_isleme_envanteri.md',
      ).readAsStringSync().toLowerCase();
      final verbis = File(
        'docs/verbis_muafiyet_notu.md',
      ).readAsStringSync().toLowerCase();
      final combined = '$inventory\n$verbis';

      expect(combined, isNot(contains('sentry')));
      expect(combined, isNot(contains('dsn')));
      expect(combined, contains('biyometrik kilit devre dış'));
      expect(combined, contains('google play billing'));
      expect(combined, contains('revenuecat'));
      expect(combined, contains('openstreetmap'));
      expect(
        combined,
        isNot(contains('hiçbir üçüncü tarafa veri aktarımı yapılmaz')),
      );
      expect(combined, isNot(contains('sıfır veri aktarımı')));
    });

    test('privacy docs disclose provider network behavior conservatively', () {
      final disclosure = File(
        'store/aydinlatma_metni.html',
      ).readAsStringSync().toLowerCase();
      final appStoreReference = File(
        'store/app_store_privacy_labels.md',
      ).readAsStringSync().toLowerCase();

      expect(disclosure, contains('openstreetmap'));
      expect(disclosure, contains('teknik ağ isteği'));
      expect(disclosure, isNot(contains('kişisel veri aktarımı gerçekleşmez')));
      expect(appStoreReference, contains('eski planlama referansıdır'));
      expect(appStoreReference, contains('not_applicable / future_scope'));
      expect(appStoreReference, contains('google play billing / revenuecat'));
      expect(appStoreReference, contains('openstreetmap'));
      expect(
        appStoreReference,
        isNot(contains('üçüncü taraflarla paylaşılmaz')),
      );
    });

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

    test('runtime legal constants match canonical legal text versions', () {
      expect(LegalConstants.termsVersion, LegalTexts.termsVersion);
      expect(LegalConstants.kvkkDisclosureVersion, LegalTexts.kvkkVersion);
      expect(LegalConstants.consentFormVersion, LegalTexts.kvkkVersion);
      expect(LegalConstants.privacyPolicyVersion, LegalTexts.kvkkVersion);
      expect(LegalConstants.lastUpdated, '2026-05-21');

      final disclosure = File('store/aydinlatma_metni.html').readAsStringSync();
      final publishedDisclosure = File(
        '.gh-pages-publish/aydinlatma.html',
      ).readAsStringSync();
      expect(disclosure, contains('Sürüm 3.1.1'));
      expect(disclosure, contains('21 Mayıs 2026'));
      expect(publishedDisclosure, contains('Sürüm 3.1.1'));
      expect(publishedDisclosure, contains('21 Mayıs 2026'));
    });

    test('stale Firebase FCM and resource monitor claims are cleaned', () {
      final userProfile = File(
        'lib/domain/models/user_profile.dart',
      ).readAsStringSync();
      final crashShim = File(
        'lib/core/utils/crashlytics_test_helper.dart',
      ).readAsStringSync();
      final resourceMonitor = File(
        'lib/core/services/resource_monitor_service.dart',
      ).readAsStringSync();

      expect(userProfile, isNot(contains('Firestore')));
      expect(userProfile, isNot(contains('fcmToken')));
      expect(userProfile, contains('Offline-first'));
      expect(crashShim, contains('Compatibility shim'));
      expect(crashShim, contains('no remote logging'));
      expect(resourceMonitor, isNot(contains('NOT implemented')));
      expect(resourceMonitor, contains('Memory usage is unavailable'));
    });
  });
}
