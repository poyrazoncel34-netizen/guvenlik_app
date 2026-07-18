import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed store rejects corrupt deadlines and active targets', () {
    final store = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
      'DeviceProtectedEmergencySessionStore.kt',
    ).readAsStringSync();

    expect(store, contains('finalDeadline < mainDeadline'));
    expect(store, contains('elapsedDeadline < 0L'));
    expect(store, contains('EmergencyTargetValidator.isCallable(target)'));
    expect(store, contains('SessionRead.Corrupted("invalidEnvelope")'));
    expect(store, contains('SessionRead.Corrupted("invalidActiveTarget")'));
    expect(store, contains('catch (_: ClassCastException)'));
  });

  test('interrupted PREPARING session becomes non-dispatching CORRUPTED', () {
    final coordinator = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
      'EmergencySessionCoordinator.kt',
    ).readAsStringSync();
    final preparing = coordinator.substring(
      coordinator.indexOf('LifecycleState.PREPARING ->'),
    );

    expect(preparing, contains('LifecycleState.CORRUPTED'));
    expect(preparing, contains('target = ""'));
    expect(preparing, contains('SchedulingMode.NONE'));
    expect(preparing, contains('cancelAlarmBestEffort(envelope.token)'));
    expect(coordinator, contains('alarmScheduler.cancel(token)'));
    expect(coordinator, contains('catch (_: RuntimeException)'));
  });
}
