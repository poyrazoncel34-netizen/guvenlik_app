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

    expect(receiver, contains('tokenFromIntent(intent) ?: return'));
    expect(receiver, contains('claimAndDispatch(token)'));
    expect(receiver, isNot(contains('.schedule(')));
    expect(coordinator, contains('finalDeadlineMs = finalDeadline'));
    expect(coordinator, contains('alarmScheduler.schedule(preparing)'));
    expect(coordinator, contains('store.write(armed)'));
  });
}
