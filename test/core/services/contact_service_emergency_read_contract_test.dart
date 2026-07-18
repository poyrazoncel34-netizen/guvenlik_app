import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-contract guard: each arm path resolves exactly one primary contact,
/// then passes an immutable target to the typed native session authority.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('panic button pre-check resolves one emergency contact', () {
    final src = read('lib/widgets/panic_button.dart');
    expect(src.contains('ContactService.getEmergencyContact()'), isTrue);
  });

  test(
    'countdown screen resolves primary contact and snapshots target at arm',
    () {
      final src = read('lib/screens/countdown_screen.dart');
      expect(src.contains('getPrimaryEmergencyContact()'), isTrue);
      expect(src.contains('armEmergencySession('), isTrue);
      expect(src.contains('target: _armedTargetNumber!'), isTrue);
    },
  );

  test('check-in and safe-walk resolve one emergency contact', () {
    expect(
      read(
        'lib/core/services/check_in_service.dart',
      ).contains('getPrimaryEmergencyContact()'),
      isTrue,
    );
    expect(
      read(
        'lib/screens/safe_walk_screen.dart',
      ).contains('ContactService.getEmergencyContact()'),
      isTrue,
    );
  });

  test(
    'ContactService no longer writes the contacts DB table (single source)',
    () {
      final src = read('lib/core/services/contact_service.dart');
      expect(src.contains("txn.insert('contacts'"), isFalse);
      expect(src.contains("insert('contacts'"), isFalse);
      expect(
        src.contains('emergencyContactsV1'),
        isTrue,
        reason: 'canonical secure-storage key is the source',
      );
    },
  );

  test('no biometrics and no 112 synthesis introduced in ContactService', () {
    final src = read('lib/core/services/contact_service.dart');
    expect(src.contains('local_auth'), isFalse);
    expect(src.contains('turkeyEmergencyNumber'), isFalse);
    expect(src.contains("'112'"), isFalse);
  });

  test('typed native envelope keeps an immutable target argument', () {
    final src = read('lib/core/services/emergency_platform_service.dart');
    expect(
      src.contains(
        "'target': AndroidIntentService.normalizePhoneNumber(target)",
      ),
      isTrue,
    );
  });
}
