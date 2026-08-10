import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Consent withdrawal has to change behaviour, not just a record.
///
/// The KVKK consent screen let a user withdraw location consent while the OS
/// permission stayed granted. MapPage went straight to the permission helper,
/// so it kept acquiring GPS from a user who had said no. ConsentGateService
/// existed and was wired into four other entry points -- the map was simply
/// not one of them.
void main() {
  test('the map gates location acquisition on consent', () {
    final map = File('lib/screens/map_page.dart').readAsStringSync();
    final gate = File(
      'lib/core/services/location_consent_gate.dart',
    ).readAsStringSync();

    // The gate lives in a service because map_page.dart is on the file-size
    // ratchet; the rule for those files is to extract, not to grow.
    expect(
      map,
      contains('LocationConsentGate.ensureAllowed(context)'),
      reason:
          'Withdrawing location consent must stop location processing, not '
          'only be written to the consent log.',
    );
    expect(gate, contains('ConsentGateService.requireConsent('));
    expect(gate, contains('ConsentRecord.typeLocation'));

    // Consent must be checked BEFORE the OS permission request, and the map
    // must not keep a second, ungated path to the permission helper.
    expect(
      gate.indexOf('ConsentGateService.requireConsent(') <
          gate.indexOf('PermissionHelper.requestLocationPermission'),
      isTrue,
      reason: 'A granted OS permission must not bypass a withdrawn consent.',
    );
    expect(
      map.contains('PermissionHelper.requestLocationPermission'),
      isFalse,
      reason:
          'A direct call here would reopen the ungated path the gate exists '
          'to close.',
    );
  });

  test('the emergency path is not gated on consent', () {
    // ConsentGateService's own contract: an emergency call runs regardless of
    // consent state. If this ever fails, a withdrawn consent could block a
    // panic dispatch, which is the opposite of the intent.
    final countdown = File(
      'lib/screens/countdown_screen.dart',
    ).readAsStringSync();

    expect(
      countdown.contains('ConsentGateService.requireConsent('),
      isFalse,
      reason:
          'Panic / SOS must never be blocked by a consent gate (CLAUDE.md '
          'rule 1: the emergency call flow stands on its own).',
    );
  });
}
