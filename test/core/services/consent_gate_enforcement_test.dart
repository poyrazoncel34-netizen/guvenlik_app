import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finding 1 (CRITICAL): the consent management UI promises that revoking
/// consent disables the related feature, but feature flows previously did
/// not consult ConsentGateService. This test enforces the first piece of
/// that contract: a requireConsent(...) gate must exist on the service.
void main() {
  test(
    'ConsentGateService exposes a requireConsent gate at feature entry points',
    () {
      final source = File(
        'lib/core/services/consent_gate_service.dart',
      ).readAsStringSync();
      expect(
        source.contains('requireConsent'),
        isTrue,
        reason:
            'ConsentGateService must expose requireConsent(...) so feature '
            'entry points can enforce consent before doing related '
            'processing.',
      );
      expect(
        source.contains('consent_gate_blocked'),
        isTrue,
        reason:
            'requireConsent must surface the localized consent_gate_blocked '
            'message when consent is missing.',
      );
    },
  );

  test('home_page.dart gates location and fake-call entry on consent', () {
    final source = File('lib/screens/home_page.dart').readAsStringSync();
    expect(
      source.contains('ConsentGateService.requireConsent'),
      isTrue,
      reason:
          'home_page.dart must call ConsentGateService.requireConsent for '
          'location and fake-call entry points.',
    );
    expect(source.contains('ConsentRecord.typeLocation'), isTrue);
    expect(source.contains('ConsentRecord.typeFakeCall'), isTrue);
  });

  test('unified onboarding consent records fake-call consent', () {
    final source = File(
      'lib/screens/legal/unified_consent_screen.dart',
    ).readAsStringSync();
    expect(source, contains('bool _consentFakeCall'));
    expect(source, contains('ConsentRecord.typeFakeCall'));
    expect(source, contains('_consentFakeCall'));
    expect(source, contains("'legal_consent_fake_call'.tr()"));
    expect(source, contains("'legal_consent_fake_call_sub'.tr()"));
  });

  test('withdrawn fake-call consent blocks before opening fake-call sheet', () {
    final source = File('lib/screens/home_page.dart').readAsStringSync();
    final methodStart = source.indexOf('void _showFakeCallDelayOptions()');
    final gateIndex = source.indexOf(
      'ConsentGateService.requireConsent',
      methodStart,
    );
    final fakeCallConsentIndex = source.indexOf(
      'ConsentRecord.typeFakeCall',
      methodStart,
    );
    final sheetIndex = source.indexOf('showModalBottomSheet', methodStart);

    expect(methodStart, isNot(-1));
    expect(gateIndex, isNot(-1));
    expect(fakeCallConsentIndex, isNot(-1));
    expect(sheetIndex, isNot(-1));
    expect(
      gateIndex < sheetIndex && fakeCallConsentIndex < sheetIndex,
      isTrue,
      reason:
          'Fake Call must remain blocked before any UI/action when fake-call '
          'consent has been withdrawn.',
    );
  });

  test('contacts_page.dart gates emergency-contact add on consent', () {
    final source = File('lib/screens/contacts_page.dart').readAsStringSync();
    expect(
      source.contains('ConsentGateService.requireConsent'),
      isTrue,
      reason:
          'contacts_page.dart must gate Add Emergency Contact behind '
          'ConsentGateService.requireConsent.',
    );
    expect(source.contains('ConsentRecord.typeEmergencyContacts'), isTrue);
  });

  test(
    'every contacts add/import path gates before opening add UI or picker',
    () {
      final source = File('lib/screens/contacts_page.dart').readAsStringSync();
      expect(source, contains('bool _requireEmergencyContactConsent()'));
      expect(source, contains('ConsentRecord.typeEmergencyContacts'));

      final sheetStart = source.indexOf('void _showAddContactSheet');
      final sheetGate = source.indexOf(
        '_requireEmergencyContactConsent()',
        sheetStart,
      );
      final sheetOpen = source.indexOf('showModalBottomSheet', sheetStart);
      expect(sheetStart, isNot(-1));
      expect(sheetGate, isNot(-1));
      expect(sheetOpen, isNot(-1));
      expect(sheetGate < sheetOpen, isTrue);

      final pickerStart = source.indexOf('Future<void> _pickContactFromDevice');
      final pickerGate = source.indexOf(
        '_requireEmergencyContactConsent()',
        pickerStart,
      );
      final pickerOpen = source.indexOf(
        "_contactsPickerChannel.invokeMethod",
        pickerStart,
      );
      expect(pickerStart, isNot(-1));
      expect(pickerGate, isNot(-1));
      expect(pickerOpen, isNot(-1));
      expect(
        pickerGate < pickerOpen,
        isTrue,
        reason:
            'Withdrawn emergency-contact consent must block import before the '
            'system picker opens.',
      );
    },
  );

  test('data_deletion_screen.dart is NOT consent-gated', () {
    // KVKK Article 11: users must always be able to delete their data,
    // even if all consents are revoked.
    final source = File(
      'lib/screens/settings_legal/data_deletion_screen.dart',
    ).readAsStringSync();
    expect(
      source.contains('ConsentGateService.requireConsent'),
      isFalse,
      reason:
          'Data deletion must remain accessible regardless of consent state.',
    );
  });

  test('consent_gate_blocked translation exists in TR and EN', () {
    for (final path in [
      'assets/translations/tr-TR.json',
      'assets/translations/en-US.json',
    ]) {
      final json =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(
        json.containsKey('consent_gate_blocked'),
        isTrue,
        reason: '$path must define consent_gate_blocked.',
      );
      expect((json['consent_gate_blocked'] as String).isNotEmpty, isTrue);
    }
  });
}
