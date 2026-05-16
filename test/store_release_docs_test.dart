import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('store release documentation gates', () {
    const trShort = 'Panik/SOS Pro; konum, sahte çağrı ve siren ücretsiz.';

    test('short descriptions are consistent and within Play limits', () {
      expect(trShort.runes.length <= 80, isTrue);

      final trFiles = [
        File('store/play_store_listing_tr.md'),
        File('store/google_play_listing.md'),
        File('store/STORE_LISTING_COPY_PASTE.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/release_checklist.md'),
      ];

      for (final file in trFiles) {
        expect(file.readAsStringSync(), contains(trShort), reason: file.path);
      }
    });

    test('first Play release is documented as Turkish-only', () {
      final publicPlayDocs = [
        File('store/google_play_listing.md'),
        File('store/STORE_LISTING_COPY_PASTE.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/PLAY_CONSOLE_CHECKLIST.md'),
        File('store/release_checklist.md'),
      ].map((file) => file.readAsStringSync()).join('\n');

      expect(publicPlayDocs, contains('Turkish-only'));
      expect(publicPlayDocs, isNot(contains('Use English as an additional')));
      expect(publicPlayDocs, isNot(contains('## EN (English)')));
      expect(publicPlayDocs, isNot(contains('TR/EN copy')));

      final enReference = File(
        'store/play_store_listing_en.md',
      ).readAsStringSync();
      expect(enReference, contains('Internal English Copy Reference'));
      expect(enReference, contains('Do not paste this file into Play Console'));
    });

    test('store icon and screenshot source of truth are hardened', () {
      final docs = [
        File('store/release_checklist.md'),
        File('store/PLAY_CONSOLE_CHECKLIST.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/screenshots/README.md'),
        File('store/screenshots/android/README.md'),
        File('docs/release_risks.md'),
        File('scripts/setup_play_release.sh'),
      ].map((file) => file.readAsStringSync()).join('\n');

      expect(docs, isNot(contains('1024x1024')));
      expect(docs, contains('512x512'));
      expect(docs, contains('1024x500'));
      expect(docs, contains('store/screenshots/android/final/'));
      expect(docs, contains('no real phone numbers'));
      expect(docs, contains('no sensitive map coordinates'));
    });

    test('manual gates are not marked complete in repo docs', () {
      final release = File('store/release_checklist.md').readAsStringSync();
      final billing = File(
        'store/BILLING_RELEASE_CHECKLIST.md',
      ).readAsStringSync();
      final qa = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();

      expect(release, contains('Production submission is NOT READY'));
      expect(release, contains('PLAY_CONSOLE'));
      expect(release, contains('REVENUECAT'));
      expect(release, contains('SIGNING'));
      expect(release, contains('NEEDS_OPERATOR_ACTION'));
      expect(release, contains('NEEDS_REAL_DEVICE_TEST'));
      expect(billing, contains('PLAY_CONSOLE'));
      expect(billing, contains('REVENUECAT'));
      expect(billing, contains('NOT_RUN'));
      expect(
        billing,
        isNot(
          contains(
            '| BILL-12 | Monthly purchase tested with license tester | PASS |',
          ),
        ),
      );
      expect(qa, contains('Emulator output, adb-only output'));
      expect(
        qa,
        contains(
          '| Gate | Device | Android version | Build version | Track | Preconditions | Scenario | Steps | Expected | Actual | Pass/Fail | Evidence file | Tester | Date | Notes |',
        ),
      );
      expect(qa, contains('Android 13'));
      expect(qa, contains('Notification allowed'));
      expect(qa, contains('CALL_PHONE denied ACTION_DIAL fallback'));
      expect(qa, contains('No-offering fallback'));
      expect(qa, isNot(contains('| PASS |')));
    });

    test('operator handoff matrix has owners, evidence and mandatory gates', () {
      final release = File('store/release_checklist.md').readAsStringSync();

      expect(release, contains('## Final Operator Handoff Matrix'));
      expect(
        release,
        contains(
          '| Item | Status | Owner | Where to perform | Done criteria | Evidence to save | Gate |',
        ),
      );

      for (final item in [
        'Signed AAB with production secrets',
        'Data Safety form',
        'Content Rating questionnaire',
        'Target Audience',
        'Foreground service declaration',
        'Exact alarm declaration or rationale',
        'Battery optimization reviewer note',
        'CALL_PHONE reviewer note',
        'Privacy policy URL',
        'Terms URL',
        'Data deletion URL',
        'Google Play monthly subscription product',
        'Google Play annual subscription product',
        'RevenueCat entitlement `KoruBeni Pro`',
        'RevenueCat current offering',
        'License tester setup',
        'Billing runtime validation',
        'Android 13 physical QA',
        'Android 14 physical QA',
        'Screenshot PII review',
        'Feature graphic and final store assets',
        'Closed testing production-access requirement',
        'iOS / App Store readiness',
        'Pre-launch report review',
        'Android vitals monitoring plan',
      ]) {
        expect(release, contains(item), reason: item);
      }

      expect(release, contains('PLAY_CONSOLE'));
      expect(release, contains('REVENUECAT'));
      expect(release, contains('SIGNING'));
      expect(release, contains('NEEDS_OPERATOR_ACTION'));
      expect(release, contains('NEEDS_REAL_DEVICE_TEST'));
      expect(release, contains('Evidence to save'));
    });

    test('Data Safety and closed testing are track/account dependent', () {
      final docs = [
        File('store/DATA_SAFETY_FORM.md'),
        File('store/PLAY_CONSOLE_CHECKLIST.md'),
        File('store/INTERNAL_TESTING_GUIDE.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/release_checklist.md'),
      ].map((file) => file.readAsStringSync()).join('\n');

      expect(docs, contains('internal testing may be exempt'));
      expect(docs, contains('closed/open/production'));
      expect(docs, contains('production access screen'));
      expect(docs, contains('12 opted-in testers / 14 continuous days'));
      expect(docs, contains('Legal/privacy docs must still'));
    });

    test('CI appbundle smoke is explicitly non-release provenance', () {
      final ci = File('.github/workflows/ci.yml').readAsStringSync();
      final billing = File(
        'store/BILLING_RELEASE_CHECKLIST.md',
      ).readAsStringSync();
      final release = File('store/release_checklist.md').readAsStringSync();

      expect(ci, contains('NON_RELEASE_SMOKE'));
      expect(ci, contains('NON_RELEASE_SMOKE_REVENUECAT_KEY'));
      expect(ci, contains('must not be uploaded'));
      expect(billing, contains('NON_RELEASE_SMOKE'));
      expect(release, contains('NON_RELEASE_SMOKE'));
    });
  });
}
