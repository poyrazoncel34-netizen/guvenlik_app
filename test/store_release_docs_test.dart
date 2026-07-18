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
        File('docs/play-console-checklist.md'),
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
      expect(publicPlayDocs, isNot(contains('(EN listing:')));

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
      expect(qa, contains('API 29'));
      expect(qa, contains('API 36'));
      expect(qa, contains('Samsung'));
      expect(qa, contains('Xiaomi'));
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
        'Signed AAB with pinned upload identity',
        'Data Safety form',
        'KVKK cross-border transfer mechanism for RevenueCat',
        'Content Rating questionnaire',
        'Target Audience',
        'Foreground service absence',
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
        'API 29 boundary-phone QA',
        'API 36 / 16 KB Pixel QA',
        'Samsung + Xiaomi OEM QA',
        'Dual-SIM + low-memory coverage',
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
      expect(release, contains('no FGS permission/service'));
      expect(release, contains('stale `specialUse` Console draft is removed'));
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
      expect(ci, contains('--flavor smoke'));
      expect(ci, contains('--dart-define=ENV=ci_smoke'));
      expect(ci, contains('.smoke application ID'));
      expect(ci, contains('must not be uploaded'));
      expect(billing, contains('NON_RELEASE_SMOKE'));
      expect(release, contains('NON_RELEASE_SMOKE'));
    });

    test('production rollout runbook has first-release and incident truth', () {
      final runbook = File(
        'store/PRODUCTION_ROLLOUT_RUNBOOK.md',
      ).readAsStringSync();
      final release = File('store/release_checklist.md').readAsStringSync();

      expect(runbook, contains("not a track's first"));
      expect(runbook, contains('cannot be halted back to a previous release'));
      expect(runbook, contains('5% → 20% → 50% → 100%'));
      expect(runbook, contains('does not remove the bad version from devices'));
      expect(runbook, contains('One confirmed P0 is enough'));
      expect(runbook, contains('`No data available` means'));
      expect(runbook, contains('1.09%'));
      expect(runbook, contains('0.47%'));
      expect(runbook, contains('0.50%'));
      expect(runbook, contains('0.20%'));
      expect(runbook, contains('explicit local-log export only'));
      expect(release, contains('PRODUCTION_ROLLOUT_RUNBOOK.md'));
      expect(release, contains('first production release cannot use staged'));
    });

    test('live legal routes have a repeatable HTTPS drift gate', () {
      final script = File(
        'scripts/verify_live_legal_urls.sh',
      ).readAsStringSync();
      final evidence = File(
        'docs/qa/phase5-live-legal-url-evidence-2026-07-18.md',
      ).readAsStringSync();
      final release = File('store/release_checklist.md').readAsStringSync();

      for (final route in [
        '/privacy_policy.html',
        '/kullanim_sartlari.html',
        '/kullanim_sartlari',
        '/aydinlatma.html',
        '/aydinlatma',
        '/data_deletion.html',
      ]) {
        expect(script, contains(route), reason: route);
      }
      expect(script, contains("--proto '=https'"));
      expect(script, contains('--fail'));
      expect(script, contains('cmp -s'));
      expect(script, isNot(contains('--insecure')));
      expect(evidence, contains('byte-for-byte identical'));
      expect(evidence, contains('HTTP 200'));
      expect(release, contains('disclosure text alone is not treated'));
      expect(release, contains('LIVE_VERIFIED'));
    });

    test(
      'store asset evidence passes PII but keeps candidate mismatch open',
      () {
        final evidence = File(
          'docs/qa/phase5-store-assets-evidence-2026-07-18.md',
        ).readAsStringSync();
        final release = File('store/release_checklist.md').readAsStringSync();

        expect(evidence, contains('PASS_REPO_VISUAL_PII'));
        expect(evidence, contains('37.42200, -122.08400'));
        expect(evidence, contains('Sürüm 1.0.0 (Build 1)'));
        expect(evidence, contains('versionCode=10000'));
        expect(evidence, contains('NEEDS_OPERATOR_ACTION'));
        expect(release, contains('signed-candidate recapture/exception'));
        expect(release, contains('owner masked-icon/visual approval'));
      },
    );
  });
}
