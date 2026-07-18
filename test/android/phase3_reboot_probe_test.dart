import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File(
    'scripts/phase3_emulator_reboot_probe.sh',
  ).readAsStringSync();

  test('phase-3 reboot probe is emulator-only and exercises a real reboot', () {
    expect(script, contains('ro.kernel.qemu'));
    expect(script, contains('refusing non-emulator device'));
    expect(script, contains('reboot'));
    expect(script, contains('wait-for-device'));
    expect(script, contains('am wait-for-broadcast-idle'));
    expect(script, contains('phase3Probe'));
    expect(script, contains('OK (1 test)'));
    expect(script, contains('cmd package unstop'));
    expect(script, contains('--user current'));
    expect(script, contains('cmd package wait-for-handler'));
    expect(script, contains('--timeout 10000'));
  });

  test('reboot probe persists a bounded emulator-only typed session', () {
    final probe = File(
      'android/app/src/androidTest/kotlin/com/poyrazoncel/korubeni/emergency/Phase3RebootProbeTest.kt',
    ).readAsStringSync();

    expect(probe, contains('target = "0000000"'));
    expect(probe, isNot(contains('+90')));
    expect(probe, contains('now + 1_800_000L'));
    expect(probe, contains('EmergencySessionEnvelope('));
    expect(probe, contains('DeviceProtectedEmergencySessionStore(context)'));
    expect(
      probe,
      contains('elapsedRealtimeDeadlineMs > SystemClock.elapsedRealtime()'),
    );
    expect(script, contains('trap cleanup EXIT'));
    expect(script, contains('PHASE3_CONFIRM_EPHEMERAL_AVD'));
  });
}
