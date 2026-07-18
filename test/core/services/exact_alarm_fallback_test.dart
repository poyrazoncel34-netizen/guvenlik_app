import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SCHEDULE_EXACT_ALARM fail-closed contract', () {
    test(
      'one typed scheduler owns exact and independently keyed inexact alarms',
      () {
        final content = File(
          'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
          'AndroidEmergencySessionRuntime.kt',
        ).readAsStringSync();
        final scheduler = content.substring(
          content.indexOf('class AndroidEmergencySessionAlarmScheduler'),
        );

        expect(scheduler, contains('manager.canScheduleExactAlarms()'));
        expect(scheduler, contains('catch (_: SecurityException)'));
        expect(scheduler, contains('setExactAndAllowWhileIdle'));
        expect(scheduler, contains('setAndAllowWhileIdle'));
        expect(scheduler, contains('EXACT_REQUEST_CODE'));
        expect(scheduler, contains('INEXACT_REQUEST_CODE'));
      },
    );

    test('fail-closed exact alarm copy exists in both locales', () {
      final en = File('assets/translations/en-US.json').readAsStringSync();
      final tr = File('assets/translations/tr-TR.json').readAsStringSync();

      expect(
        en,
        contains(
          'This timed action cannot be armed without exact-alarm access.',
        ),
      );
      expect(
        tr,
        contains('Bu zamanlı işlem kesin alarm izni olmadan kurulamaz.'),
      );
    });
  });
}
