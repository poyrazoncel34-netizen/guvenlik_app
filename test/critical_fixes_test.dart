import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // C1 — Dynamic PIN length
  test('CountdownScreen: PIN limit is not hard-coded to 4', () {
    final source =
        File('lib/screens/countdown_screen.dart').readAsStringSync();
    expect(
      source.contains('_pin.length < 4'),
      isFalse,
      reason:
          'Hard-coded limit of 4 breaks cancellation for 5/6-digit PINs. '
          'Use _correctPin?.length ?? 4 instead.',
    );
  });

  // C2 — Foreground service type
  test('ForegroundService: uses specialUse type, not dataSync', () {
    final source =
        File('lib/core/services/foreground_service.dart').readAsStringSync();
    expect(
      source.contains('AndroidForegroundType.dataSync'),
      isFalse,
      reason:
          'dataSync conflicts with the manifest specialUse declaration and '
          'throws InvalidForegroundServiceTypeException on Android 14+.',
    );
  });

  // C4 — Volume listener registered exactly once
  test('EmergencyTriggerHost: startListening is not called before loadPreference', () {
    final source =
        File('lib/core/widgets/emergency_trigger_host.dart').readAsStringSync();
    final loadPrefOffset = source.indexOf('loadPreference');
    final firstStartListeningOffset = source.indexOf('startListening');
    expect(
      loadPrefOffset,
      lessThan(firstStartListeningOffset),
      reason:
          'loadPreference() must appear before startListening() so the '
          'enabled flag is known before the listener is registered.',
    );
  });

  // C3 — Exact alarm permission guard
  test('CheckInScheduler: provides setAndAllowWhileIdle fallback when exact alarm denied', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt',
    ).readAsStringSync();
    // The fix requires a safe fallback: when canScheduleExactAlarms() returns
    // false, the scheduler must call setAndAllowWhileIdle (inexact but safe)
    // so the alarm is never silently dropped.
    expect(
      source.contains('setAndAllowWhileIdle'),
      isTrue,
      reason:
          'scheduleAlarm must fall back to setAndAllowWhileIdle when '
          'canScheduleExactAlarms() returns false on Android 12+, '
          'otherwise the alarm is silently lost and check-in never triggers.',
    );
  });
}
