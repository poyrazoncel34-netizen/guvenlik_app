import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactsPage._pickContactFromDevice', () {
    test('uses the permissionless native picker (no READ_CONTACTS)', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source,
        contains("_contactsPickerChannel.invokeMethod"),
        reason:
            'Release contract: pick via the native ACTION_PICK channel, which '
            'needs no READ_CONTACTS permission.',
      );
      expect(
        source.contains('fluttercontactpicker_plus'),
        isFalse,
        reason: 'The old READ_CONTACTS-gated picker plugin must be dropped.',
      );
      expect(
        source.contains('READ_CONTACTS'),
        isFalse,
        reason: 'The app must never reference the READ_CONTACTS permission.',
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
      expect(
        source,
        contains('LengthLimitingTextInputFormatter'),
        reason: 'Manual phone input must be bounded before validation.',
      );
    });
  });

  group('ContactsPage._pickContactFromDevice catch block', () {
    test('handles channel PlatformException without crashing', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(
        source.contains('on PlatformException'),
        isTrue,
        reason:
            '_pickContactFromDevice must catch channel PlatformExceptions and '
            'surface a friendly failure instead of crashing.',
      );
      expect(
        source.contains('contacts_picker_failed'),
        isTrue,
        reason: 'A channel error must show the generic picker-failed message.',
      );
    });

    test('treats picker cancel as a handled no-op', () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      // Cancel / no-number now comes back as a null parse result, not an
      // exception — the method returns quietly.
      expect(source.contains('parsePickedPhoneContact'), isTrue);
      expect(
        source.contains('if (picked == null)'),
        isTrue,
        reason: 'A cancelled pick must be a quiet early return, not a failure.',
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
