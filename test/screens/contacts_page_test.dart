import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactsPage._pickContactFromDevice', () {
    test('asks for permission when picking contact', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('askForPermission: false'), isFalse,
          reason: 'Must use askForPermission: true so READ_CONTACTS is requested before reading the selected contact');
    });

    test('normalizes phone number from picker before passing to addContact', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('normalizePhoneNumber('), isTrue,
          reason: '_pickContactFromDevice must normalize the phone number before calling addContact');
    });
  });

  group('ContactsPage._pickContactFromDevice catch block', () {
    test('handles PlatformException separately from generic errors', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('on PlatformException'), isTrue,
          reason: '_pickContactFromDevice must catch PlatformException to distinguish permission errors from generic errors');
    });
  });

  group('ContactsPage quick dial section', () {
    test('quick dial section is not shown in contacts page', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('_buildQuickDialSection()'), isFalse,
          reason: 'Quick dial (kırmızı 112 bölümü) contacts page\'den kaldırılmalı');
    });
  });

  group('ContactsPage manual entry phone field', () {
    test('phone TextField has maxLength of 16', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('maxLength: 16'), isTrue,
          reason: 'Phone TextField must limit input to 16 chars (+ and up to 15 digits)');
    });

    test('rejects phone numbers with fewer than 7 digits', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('digitsOnly.length < 7'), isTrue,
          reason: 'Save callback must reject numbers with fewer than 7 digits');
    });
  });
}
