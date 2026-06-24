import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-contract guard ([[emergency-flow-test-convention]]): the 4 emergency
/// read points and the native method-channel argument must keep reading the
/// Dart-resolved contact, and ContactService must be the single source (no DB
/// writes), with no biometrics / 112 synthesis introduced.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('panic button pre-check still reads getAllEmergencyNumbers', () {
    final src = read('lib/widgets/panic_button.dart');
    expect(src.contains('ContactService.getAllEmergencyNumbers()'), isTrue);
  });

  test(
    'countdown screen reads contacts and passes primaryNumber to native',
    () {
      final src = read('lib/screens/countdown_screen.dart');
      expect(src.contains('getAllEmergencyNumbers()'), isTrue);
      expect(src.contains('getPrimaryEmergencyContact()'), isTrue);
      expect(src.contains('scheduleCountdownAlarm('), isTrue);
      expect(src.contains('primaryNumber:'), isTrue);
    },
  );

  test('check-in and safe-walk still read getAllEmergencyNumbers', () {
    expect(
      read(
        'lib/core/services/check_in_service.dart',
      ).contains('getAllEmergencyNumbers()'),
      isTrue,
    );
    expect(
      read(
        'lib/screens/safe_walk_screen.dart',
      ).contains('getAllEmergencyNumbers()'),
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

  test(
    'native AlarmManager backup channel layer is untouched by this change',
    () {
      final src = read('lib/core/services/emergency_platform_service.dart');
      expect(
        src.contains('primaryNumber'),
        isTrue,
        reason: 'method-channel argument contract preserved',
      );
    },
  );
}
