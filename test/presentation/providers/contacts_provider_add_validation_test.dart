import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';

/// D4: invalid / over-length phone numbers must be rejected by addContact on
/// EVERY path (manual, picker, future callers). The reject path returns before
/// any persistence, so it needs no DI.
void main() {
  group('ContactsProvider.addContact validation', () {
    test('rejects an over-length (>15 digit) number and stores nothing',
        () async {
      final provider = ContactsProvider();
      final added = await provider.addContact(
        name: 'Ayşe',
        phone: '1234567890123456789', // 19 digits
      );
      expect(added, isFalse);
      expect(provider.emergencyContacts, isEmpty);
    });

    test('rejects a too-short (<7 digit) number', () async {
      final provider = ContactsProvider();
      expect(
        await provider.addContact(name: 'X', phone: '12345'),
        isFalse,
      );
      expect(provider.emergencyContacts, isEmpty);
    });

    test('rejects empty / junk input', () async {
      final provider = ContactsProvider();
      expect(await provider.addContact(name: 'X', phone: ''), isFalse);
      expect(await provider.addContact(name: 'X', phone: 'abcdef'), isFalse);
      expect(provider.emergencyContacts, isEmpty);
    });
  });
}
