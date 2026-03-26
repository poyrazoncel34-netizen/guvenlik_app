import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S6: CheckInScheduler.scheduleAlarm must check canScheduleExactAlarms()
/// before calling setExactAndAllowWhileIdle. On Android 12+, if exact alarm
/// permission is denied, the alarm is silently demoted to inexact.
void main() {
  test('CheckInScheduler.scheduleAlarm should check canScheduleExactAlarms', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt',
    ).readAsStringSync();

    // scheduleAlarm should reference canScheduleExactAlarms before setting alarm
    expect(
      source.contains('canScheduleExactAlarms('),
      isTrue,
      reason: 'CheckInScheduler already has canScheduleExactAlarms method',
    );

    // The scheduleAlarm method should use canScheduleExactAlarms internally
    final scheduleAlarmBody = source.substring(
      source.indexOf('private fun scheduleAlarm'),
    );
    expect(
      scheduleAlarmBody.contains('canScheduleExactAlarms'),
      isTrue,
      reason:
          'scheduleAlarm must check canScheduleExactAlarms() before calling '
          'setExactAndAllowWhileIdle — denied permission causes silent demotion',
    );
  });
}
