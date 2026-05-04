import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('store release documentation gates', () {
    const trShort = 'Panik/SOS Pro; konum, sahte çağrı ve siren ücretsiz.';
    const enShort =
        'Panic/SOS requires Pro; location, fake call, and siren are free.';

    test('short descriptions are consistent and within Play limits', () {
      expect(trShort.runes.length <= 80, isTrue);
      expect(enShort.runes.length <= 80, isTrue);

      final trFiles = [
        File('store/play_store_listing_tr.md'),
        File('store/google_play_listing.md'),
        File('store/STORE_LISTING_COPY_PASTE.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/release_checklist.md'),
      ];
      final enFiles = [
        File('store/play_store_listing_en.md'),
        File('store/STORE_LISTING_COPY_PASTE.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/release_checklist.md'),
      ];

      for (final file in trFiles) {
        expect(file.readAsStringSync(), contains(trShort), reason: file.path);
      }
      for (final file in enFiles) {
        expect(file.readAsStringSync(), contains(enShort), reason: file.path);
      }
    });

    test('store icon and screenshot source of truth are hardened', () {
      final docs = [
        File('store/release_checklist.md'),
        File('store/PLAY_CONSOLE_CHECKLIST.md'),
        File('store/PLAY_CONSOLE_COPY_PASTE_PACK.md'),
        File('store/screenshots/README.md'),
        File('store/screenshots/android/README.md'),
        File('docs/release_risks.md'),
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
      expect(release, contains('OPERATOR_ACTION'));
      expect(release, contains('NEEDS_REAL_DEVICE_TEST'));
      expect(billing, contains('OPERATOR_ACTION'));
      expect(
        billing,
        isNot(
          contains(
            '| BILL-11 | Monthly purchase tested with license tester | PASS |',
          ),
        ),
      );
      expect(qa, contains('Emulator, adb'));
      expect(qa, contains('| QA-001 |'));
      expect(qa, contains('| QA-035 |'));
      expect(qa, isNot(contains('| PASS |')));
    });
  });
}
