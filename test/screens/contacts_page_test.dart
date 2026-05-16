import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactsPage._pickContactFromDevice', () {
    test('does not request READ_CONTACTS when picking a contact', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source,
        contains('askForPermission: false'),
        reason:
            'Release contract: use user-selected picker/manual entry only; do not request READ_CONTACTS.',
      );
      expect(
        source,
        isNot(contains('askForPermission: true')),
        reason: 'The app must not trigger the plugin READ_CONTACTS request.',
      );
    });

    test('normalizes phone number from picker before passing to addContact', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source.contains('normalizePhoneNumber('),
        isTrue,
        reason:
            '_pickContactFromDevice must normalize the phone number before calling addContact',
      );
    });
  });

  group('ContactsPage manual entry', () {
    test('contains manual entry UI and validation path', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source,
        contains('Future<void> _addManualContact'),
        reason:
            'Manual entry is the release-safe fallback when READ_CONTACTS is not requested.',
      );
      expect(source, contains('contacts_manual_phone_label'));
      expect(
        source,
        contains('EmergencyNumberValidator.isCallableEmergencyTarget'),
        reason: 'Manual entries must reject invalid short/random numbers.',
      );
    });
  });

  group('ContactsPage._pickContactFromDevice catch block', () {
    test('handles PlatformException separately from generic errors', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source.contains('on PlatformException'),
        isTrue,
        reason:
            '_pickContactFromDevice must catch PlatformException to distinguish permission errors from generic errors',
      );
      expect(
        source,
        contains('contacts_picker_unavailable_manual'),
        reason:
            'If the no-READ_CONTACTS picker is unavailable, UI must point users to manual entry.',
      );
    });

    test('handles picker cancel separately', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source,
        contains('on UserCancelledPickingException'),
        reason: 'Picker cancel must be a handled no-op, not a failure.',
      );
    });
  });

  group('ContactsPage quick dial section', () {
    test('quick dial section is not shown in contacts page', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source.contains('_buildQuickDialSection()'),
        isFalse,
        reason:
            'Quick dial (kırmızı 112 bölümü) contacts page\'den kaldırılmalı',
      );
    });
  });

  group('ContactsPage remove confirmation', () {
    test('confirms before removing an emergency contact', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      final removeButton = source.indexOf('"contacts_remove".tr()');
      final confirmCall = source.indexOf('_confirmRemoveContact(contact)');
      final removeCall = source.indexOf(
        'provider.removeContact(contact.phone)',
      );

      expect(source, contains('Future<bool> _confirmRemoveContact'));
      expect(source, contains('contacts_remove_confirm_title'));
      expect(source, contains('contacts_remove_confirm_desc'));
      expect(removeButton, isNot(-1));
      expect(confirmCall, isNot(-1));
      expect(removeCall, isNot(-1));
      expect(confirmCall < removeCall, isTrue);
    });
  });
}
