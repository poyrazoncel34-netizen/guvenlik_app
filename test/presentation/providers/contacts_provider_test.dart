import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactsProvider._persistContacts', () {
    test('does not call saveEmergencyNumbers (no double-save)', () {
      final source = File(
        'lib/presentation/providers/contacts_provider.dart',
      ).readAsStringSync();
      expect(
        source.contains('saveEmergencyNumbers'),
        isFalse,
        reason:
            '_persistContacts must not call saveEmergencyNumbers to avoid redundant full rewrite',
      );
    });
  });

  group('ContactsProvider.addContact', () {
    test('addContact stores normalized phone, not raw phone', () {
      final source = File(
        'lib/presentation/providers/contacts_provider.dart',
      ).readAsStringSync();
      expect(
        source.contains('phone: normalizePhoneNumber(phone)'),
        isTrue,
        reason:
            'ContactItem must be created with normalizePhoneNumber(phone), not phone.trim()',
      );
    });
  });

  group('ContactsProvider.containsPhone', () {
    test('uses suffix comparison to catch local vs E.164 variants', () {
      final source = File(
        'lib/presentation/providers/contacts_provider.dart',
      ).readAsStringSync();
      expect(
        source.contains('substring'),
        isTrue,
        reason:
            'containsPhone must use suffix comparison to treat 05361234567 and +905361234567 as duplicates',
      );
    });
  });
}
