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
        // Sozlesme aynasi buraya v4 calismasinda eklendi: taranmiyordu, oysa
        // kullanicinin ve Play incelemecisinin actigi yayimlanmis sayfa bu.
        File('store/kullanim_sartlari.html'),
        // Yayimlanan aynalar da taranir: store/ duzeltilip mirror
        // senkronlanmazsa kullaniciya giden metin eski kalir.
        ...Directory('.gh-pages-publish')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.html')),
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
        // --- SONUC VAADI (v4) -------------------------------------------
        // Sozlesme Madde 3.2 hicbir sonuc taahhut etmiyor. Magaza metni
        // TKHK m.61 uyarinca sozlesmenin PARCASI oldugu icin, orada verilen
        // bir sonuc vaadi sozlesmedeki reddi gecersiz kilar: mahkeme
        // celiskiyi tuketici lehine yorumlar.
        'sizi korur',
        'seni korur',
        'güvende olursunuz',
        'güvende tutar',
        'keeps you safe',
        'will protect you',
        'polisi arar',
        'polise bildirir',
        'calls the police',
        'notifies the police',
        // --- DEVLET BAGLANTISI IMASI (v4) --------------------------------
        // Play "Requirements for apps that communicate government
        // information": resmi acil numaralardan bahseden uygulamalar bu
        // politikaya tabi ve bagli OLMADIKLARINI acikca belirtmeli.
        'resmi acil servis uygulaması',
        'official emergency service app',
        'kades ile entegre',
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

    test('acil numaradan bahseden her kamuya acik metin bagimsizlik beyani tasir', () {
      // Google Play, resmi acil servis numaralarindan (112, 911 vb.) bahseden
      // uygulamalari "apps that communicate government information" politikasi
      // kapsamina aliyor ve bagli olmayan uygulamalar icin sunu sart kosuyor:
      // "Make it clear that the app doesn't represent a government or
      // political entity."
      //
      // Bu kapi eklenmeden once store/google_play_listing.md 112'den
      // bahsediyor ama hicbir bagimsizlik beyani tasimiyordu.
      final files = [
        File('store/play_store_listing_tr.md'),
        File('store/play_store_listing_en.md'),
        File('store/google_play_listing.md'),
        File('store/kullanim_sartlari.html'),
      ];
      // Yuzeyler ayni seyi farkli soyluyor; herhangi biri yeterli.
      const acceptedNotices = [
        'bağımsız bir uygulamadır',
        'is an independent application',
        'bunlara bağlı değildir',
        'is not connected to any of them',
      ];

      final violations = <String>[];
      for (final file in files) {
        final text = file.readAsStringSync();
        if (!text.contains('112')) continue;
        final lower = text.toLowerCase();
        final hasNotice =
            acceptedNotices.any((n) => lower.contains(n.toLowerCase()));
        if (!hasNotice) violations.add(file.path);
      }

      expect(
        violations,
        isEmpty,
        reason: 'Acil numaradan bahsedip bagimsizlik beyani tasimayan metin: '
            '${violations.join(", ")}',
      );
    });
  });
}
