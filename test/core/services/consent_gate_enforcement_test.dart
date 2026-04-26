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
