import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 4C: EmergencyPlatformService must have executeEmergencyNative binding.
void main() {
  test(
    'EmergencyPlatformService should have executeEmergencyNative method',
    () {
      final source = File(
        'lib/core/services/emergency_platform_service.dart',
      ).readAsStringSync();

      expect(
        source.contains('executeEmergencyNative'),
        isTrue,
        reason: 'Must have Flutter binding for native emergency executor',
      );
    },
  );
}
