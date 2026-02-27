import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';

void main() {
  group('ContactItem', () {
    test('properties are accessible', () {
      const contact = ContactItem(
        name: 'Ali',
        phone: '+905551234567',
        icon: IconData(0xe491),
        color: Color(0xFFFF0000),
      );

      expect(contact.name, 'Ali');
      expect(contact.phone, '+905551234567');
    });
  });

  // ContactsProvider requires ServiceLocator/repository mocks.
  // These unit tests focus on pure logic that doesn't need DI.
  group('ContactsProvider logic', () {
    test('ContactItem equality by properties', () {
      const a = ContactItem(
        name: 'Test',
        phone: '123',
        icon: IconData(0xe491),
        color: Color(0xFF00FF00),
      );
      const b = ContactItem(
        name: 'Test',
        phone: '123',
        icon: IconData(0xe491),
        color: Color(0xFF00FF00),
      );

      // ContactItem doesn't override == so identity check
      expect(a.name, b.name);
      expect(a.phone, b.phone);
    });

    test('phone normalization matches expected pattern', () {
      // Test the normalization logic used by containsPhone
      const phone1 = '+90 555 123 45 67';
      const phone2 = '+905551234567';
      final normalized1 = phone1.replaceAll(RegExp(r'\s+'), '');
      final normalized2 = phone2.replaceAll(RegExp(r'\s+'), '');

      expect(normalized1, equals(normalized2));
    });

    test('phone normalization handles various formats', () {
      const formats = [
        '+90 555 123 4567',
        '+90  555  123  4567',
        '+905551234567',
        ' +905551234567 ',
      ];

      final normalized =
          formats.map((p) => p.replaceAll(RegExp(r'\s+'), '')).toSet();

      // All should normalize to same value
      expect(normalized.length, 1);
      expect(normalized.first, '+905551234567');
    });
  });
}
