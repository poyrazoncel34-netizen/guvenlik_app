// CheckInScheduler.scheduleAlarm must fall back to inexact alarms
// when canScheduleExactAlarms is false (Android 14+ user opt-in).
// Without this, setExactAndAllowWhileIdle throws SecurityException.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SCHEDULE_EXACT_ALARM fallback', () {
    test('scheduleAlarm must check canScheduleExactAlarms before using setExact', () {
      final content = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt',
      ).readAsStringSync();

      expect(
        content,
        contains('canScheduleExactAlarms'),
        reason: 'CheckInScheduler already has canScheduleExactAlarms check',
      );

      // The scheduleAlarm function must use canScheduleExactAlarms guard
      // to fall back to inexact alarms when exact alarm permission is denied
      final scheduleAlarmMethod = content.substring(
        content.indexOf('private fun scheduleAlarm'),
      );

      expect(
        scheduleAlarmMethod,
        contains('canScheduleExactAlarms'),
        reason:
            'scheduleAlarm must check canScheduleExactAlarms() and fall back '
            'to setAndAllowWhileIdle when exact alarms are not permitted. '
            'Without this, SecurityException crashes the app on Android 14+.',
      );
    });
  });
}
