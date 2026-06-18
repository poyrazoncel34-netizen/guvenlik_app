import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('public release copy overclaim guard', () {
    test(
      'app translation values do not claim biometric cancel or battery guarantees',
      () {
        final files = [
          File('assets/translations/en-US.json'),
          File('assets/translations/tr-TR.json'),
        ];
        const forbiddenValueFragments = [
          'pin or biometric',
          'pin veya biyometrik',
          'ilk müdahale',
          'first-responder',
          'first responder',
          'location and contacts permissions',
          'konum ve rehber izin',
          'always ready',
          'run seamlessly',
          'sorunsuz çalışacak',
        ];

        final violations = <String>[];
        for (final file in files) {
          final json =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          for (final entry in json.entries) {
            final value = entry.value;
            if (value is! String) continue;
            final normalized = value.toLowerCase();
            for (final fragment in forbiddenValueFragments) {
              if (normalized.contains(fragment)) {
                violations.add('${file.path}:${entry.key}:$fragment');
              }
            }
          }
        }

        expect(violations, isEmpty);
      },
    );

    test('store copy avoids stale public-release claims', () {
      final files = [
        File('store/google_play_listing.md'),
        File('store/play_store_listing_en.md'),
        File('store/play_store_listing_tr.md'),
        File('store/permissions_declaration_notes.md'),
        File('store/google_play_data_safety.md'),
        File('store/privacy_policy.html'),
        File('store/privacy_policy_en.html'),
        File('store/aydinlatma_metni.html'),
        File('store/app_store_privacy_labels.md'),
        File('store/QA_SENARYOLAR.md'),
      ];
      const forbiddenFragments = [
        'ilk müdahale',
        'first-responder',
        'first responder',
        'tüm verileriniz sadece cihazınızda kalır',
        'hiçbir sunucuya veri gönderilmez',
        'tüm verileriniz cihazınızda kalır. hiçbir sunucuya gönderilmez. kvkk uyumlu',
        'verileriniz hic bir ucuncu taraf sunucusuna aktarilmaz',
        'hicbir ucuncu taraf sunucusuna aktarilmaz',
        'no data is transferred to third-party servers',
        'no data is sent to external servers or cloud backends',
        'all sensitive data is encrypted',
        'security first',
        'your safety, one tap away',
        'güvenliğiniz bir dokunuş',
        'en güvenilir yoludur',
        'otomatik arama, yardım çağırmanın',
        'face id / parmak izi ile iptal',
      ];

      final violations = <String>[];
      for (final file in files) {
        final normalized = file.readAsStringSync().toLowerCase();
        for (final fragment in forbiddenFragments) {
          if (normalized.contains(fragment)) {
            violations.add('${file.path}:$fragment');
          }
        }
      }

      expect(violations, isEmpty);
    });
  });
}
