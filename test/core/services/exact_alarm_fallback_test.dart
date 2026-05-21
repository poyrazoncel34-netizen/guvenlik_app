// CheckInScheduler.scheduleAlarm must fall back to inexact alarms
// when canScheduleExactAlarms is false (Android 14+ user opt-in).
// Without this, setExactAndAllowWhileIdle throws SecurityException.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SCHEDULE_EXACT_ALARM fallback', () {
    test(
      'scheduleAlarm must check canScheduleExactAlarms before using setExact',
      () {
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
        expect(scheduleAlarmMethod, contains('catch (e: SecurityException)'));
        expect(scheduleAlarmMethod, contains('scheduleInexactAlarm'));
        expect(scheduleAlarmMethod, contains('setAndAllowWhileIdle'));
      },
    );

    test('countdown backup alarm also catches exact alarm races', () {
      final content = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmScheduler.kt',
      ).readAsStringSync();

      expect(content, contains('canScheduleExactAlarms'));
      expect(content, contains('catch (e: SecurityException)'));
      expect(content, contains('scheduleInexactAlarm'));
      expect(content, contains('setAndAllowWhileIdle'));
    });

    test('required degraded exact alarm copy exists in both locales', () {
      final en = File('assets/translations/en-US.json').readAsStringSync();
      final tr = File('assets/translations/tr-TR.json').readAsStringSync();

      expect(
        en,
        contains(
          'Exact alarm access improves safety timer reliability. Without it, timers may be delayed.',
        ),
      );
      expect(
        tr,
        contains(
          'Kesin alarm izni güvenlik zamanlayıcılarının zamanında çalışmasına yardımcı olur. Bu izin verilmezse zamanlayıcılar gecikebilir.',
        ),
      );
    });
  });
}
