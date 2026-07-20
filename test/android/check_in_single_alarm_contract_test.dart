import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check-in receiver only claims the tokenized final-deadline alarm', () {
    final receiver = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
      'CheckInAlarmReceiver.kt',
    ).readAsStringSync();
    final coordinator = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
      'EmergencySessionCoordinator.kt',
    ).readAsStringSync();

    expect(
      receiver,
      contains('AndroidEmergencySessionAlarmScheduler.tokenFromIntent(intent)'),
    );
    expect(receiver, contains('?: return@run'));
    expect(receiver, contains('claimAndDispatch(token)'));
    expect(receiver, isNot(contains('.schedule(')));
    expect(coordinator, contains('finalDeadlineMs = finalDeadline'));
    expect(coordinator, contains('scheduleBestEffort(preparing)'));
    expect(coordinator, contains('private fun scheduleBestEffort'));
    expect(coordinator, contains('store.write(armed)'));
  });
}
