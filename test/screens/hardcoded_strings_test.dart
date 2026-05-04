import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings_page.dart has no hardcoded Turkish strings', () {
    test('should not contain hardcoded Turkish UI strings', () {
      final source = File('lib/screens/settings_page.dart').readAsStringSync();
      expect(
        source,
        isNot(contains("'Gizlilik Politikası (Web)'")),
        reason: 'Privacy policy web title should use a localization key',
      );
    });
  });

  group('pin_setup_screen.dart has no hardcoded Turkish strings', () {
    test('tooltip should use localization key not hardcoded Turkish', () {
      final source = File(
        'lib/screens/pin_setup_screen.dart',
      ).readAsStringSync();
      expect(
        source,
        isNot(contains("tooltip: 'Yasal Bilgiler'")),
        reason: 'Legal info tooltip should use a localization key',
      );
    });
  });

  group('release-blocker hardcoded strings are localized', () {
    test('audited user-facing strings are not hardcoded in Dart sources', () {
      final sources = [
        File('lib/core/services/notification_service.dart'),
        File('lib/screens/app_unlock_screen.dart'),
        File('lib/screens/contacts_page.dart'),
        File('lib/screens/settings_legal/data_export_screen.dart'),
        File('lib/screens/settings_detail_page.dart'),
        File('lib/main.dart'),
      ];
      const forbidden = [
        'Sahte çağrı hazır',
        'Sahte çağrı ekranını açmak için dokunun.',
        'Şifremi Unuttum',
        'Onaylamak için SIFIRLA yazın',
        'Verilerimi Dışa Aktar',
        'Kişisel Veri Dışa Aktarımı',
        'KVKK Bilgilendirme',
        'Eklediğiniz kişilerin telefon numaraları yalnızca cihazınızda',
        'Anladım',
        'Uygulama bu ekrani yukleyemedi',
        'KoruBeni güvenlik uygulaması',
        'Acil durumlarda yardım çağırın',
      ];

      final violations = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        for (final text in forbidden) {
          if (source.contains(text)) violations.add('${file.path}:$text');
        }
      }
      expect(violations, isEmpty);
    });
  });
}
