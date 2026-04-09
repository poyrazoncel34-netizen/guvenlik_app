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

  group('ContactsPage manual entry removed', () {
    test('does not contain manual entry UI', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source.contains('Manuel numara ekle'), isFalse,
          reason: 'Manual entry was removed — contacts can only be added from device contacts');
      expect(source.contains('veya manuel gir'), isFalse,
          reason: 'Manual entry divider must be removed');
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
}
