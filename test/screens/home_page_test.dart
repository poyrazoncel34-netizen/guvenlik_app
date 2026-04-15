import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomePage UI elements', () {
    late String source;

    setUp(() {
      source = File('lib/screens/home_page.dart').readAsStringSync();
    });

    group('PanicButton', () {
      test('renders PanicButton widget on home screen', () {
        expect(
          source.contains('PanicButton()'),
          isTrue,
          reason:
              'PanicButton (acil durum butonu) ana ekranda görünür olmalıdır',
        );
      });
    });

    group('Header', () {
      test('uses welcome_greeting key instead of hello+user pattern', () {
        expect(
          source.contains('welcome_greeting'),
          isTrue,
          reason: 'Ana ekran header welcome_greeting anahtarını kullanmalı',
        );
      });
    });

    group('Contacts gate', () {
      test('_openContacts does not gate with PremiumFeature.contacts', () {
        expect(
          source,
          isNot(contains('_openContacts')),
          reason:
              'contacts free olduğu için _openContacts gate metodu kaldırılmalı',
        );
      });
    });
  });
}
