import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public Dart safety surface exposes only typed coordinator methods', () {
    final source = File(
      'lib/core/services/emergency_platform_service.dart',
    ).readAsStringSync();

    for (final typedMethod in [
      'Future<ArmResult> armEmergencySession',
      'Future<ArmResult> reviseEmergencySession',
      'Future<CancelResult> cancelEmergencySession',
      'Future<SessionSnapshot> readEmergencySession',
      'Future<DispatchResult> dispatchEmergencySession',
      'Future<CapabilitySnapshot> getEmergencyCapabilities',
      'Future<WipeResult> wipeEmergencySessions',
    ]) {
      expect(source, contains(typedMethod));
    }

    for (final retiredMethod in [
      'Future<bool> scheduleCheckIn',
      'Future<bool> didCheckInAlarmFire',
      'getCheckInDeadlineState(',
      'Future<void> cancelCheckIn',
      'Future<void> clearEmergencyPrefs',
      'executeEmergencyNative(',
      'scheduleCountdownAlarm(',
      'Future<void> cancelCountdownAlarm',
      'didCountdownAlarmFire(',
    ]) {
      expect(source, isNot(contains(retiredMethod)));
    }
  });
}
