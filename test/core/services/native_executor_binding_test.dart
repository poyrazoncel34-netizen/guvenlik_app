import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The public Dart bridge exposes only the typed session coordinator surface.
void main() {
  test(
    'EmergencyPlatformService exposes typed arm/read/cancel/dispatch methods',
    () {
      final source = File(
        'lib/core/services/emergency_platform_service.dart',
      ).readAsStringSync();

      expect(source, contains('Future<ArmResult> armEmergencySession'));
      expect(source, contains('Future<SessionSnapshot> readEmergencySession'));
      expect(source, contains('Future<CancelResult> cancelEmergencySession'));
      expect(
        source,
        contains('Future<DispatchResult> dispatchEmergencySession'),
      );
      expect(source, isNot(contains('Future<void> executeEmergencyNative')));
    },
  );
}
