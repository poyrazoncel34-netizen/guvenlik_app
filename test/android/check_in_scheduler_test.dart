import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed scheduler guards exact access and still arms inexact backup', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
      'AndroidEmergencySessionRuntime.kt',
    ).readAsStringSync();
    final scheduler = source.substring(
      source.indexOf('class AndroidEmergencySessionAlarmScheduler'),
    );

    expect(scheduler, contains('manager.canScheduleExactAlarms()'));
    expect(scheduler, contains('catch (_: SecurityException)'));
    expect(scheduler, contains('setExactAndAllowWhileIdle'));
    expect(scheduler, contains('setAndAllowWhileIdle'));
    expect(
      scheduler,
      contains('AlarmScheduleResult(exactAccepted, inexactAccepted)'),
    );
  });
}
