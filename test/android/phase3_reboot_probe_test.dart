import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File(
    'scripts/phase3_emulator_reboot_probe.sh',
  ).readAsStringSync();

  test('phase-3 reboot probe is emulator-only and exercises a real reboot', () {
    expect(script, contains('ro.kernel.qemu'));
    expect(script, contains('refusing non-emulator device'));
    expect(script, contains('emu avd name'));
    expect(script, contains('reboot'));
    expect(script, contains('wait-for-device'));
    expect(script, contains('am wait-for-broadcast-idle'));
    expect(script, contains('phase3Probe'));
    expect(script, contains('OK (1 test)'));
    expect(script, contains('make_boot_eligible_after_instrumentation'));
    expect(script, isNot(contains('cmd package unstop')));
    expect(script, contains('input keyevent KEYCODE_HOME'));
    expect(script, contains('cmd package wait-for-handler'));
    expect(script, contains('--timeout 10000'));
    expect(script, contains('package_help'));
    expect(script, contains('*"wait-for-handler"*'));
    expect(script, contains('cmd package help 2>&1 || true'));
    expect(script, contains('PACKAGE_STATE_FLUSH_SECONDS'));
    expect(script, contains('stopped=false'));
    expect(script, contains('notLaunched=false'));
    expect(script, contains('shell sync'));
    expect(script, contains('git status --porcelain'));
    expect(script, contains('PHASE3_EVIDENCE_OUTPUT'));
    expect(script, contains('write_phase3_emulator_evidence.py'));
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

  test(
    'phase-3 evidence writer emits source-bound emulator-only evidence',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'phase3-emulator-evidence-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final output = File('${temp.path}/evidence.json');

      final result = await Process.run('python3', [
        'scripts/write_phase3_emulator_evidence.py',
        '--output',
        output.path,
        '--git-commit',
        '1' * 40,
        '--git-tree',
        '2' * 40,
        '--app-apk-sha256',
        '3' * 64,
        '--test-apk-sha256',
        '4' * 64,
        '--serial',
        'emulator-5554',
        '--avd-name',
        'Medium_Phone_API_36.1',
        '--api-level',
        '36',
        '--android-release',
        '16',
        '--abi',
        'arm64-v8a',
        '--manufacturer',
        'Google',
        '--model',
        'sdk_gphone64_arm64',
        '--build-fingerprint',
        'google/sdk_gphone64_arm64/test:userdebug/test-keys',
        '--page-size-bytes',
        '4096',
        '--started-at-utc',
        '2026-07-19T10:00:00Z',
        '--finished-at-utc',
        '2026-07-19T10:03:00Z',
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final payload = jsonDecode(await output.readAsString()) as Map;
      expect(payload['schemaVersion'], 1);
      expect(payload['evidenceType'], 'android_direct_boot_reboot_probe');
      expect(payload['status'], 'PASS_EMULATOR_ONLY');
      expect(payload['candidateBound'], isFalse);
      expect((payload['source'] as Map)['gitCommit'], '1' * 40);
      expect((payload['source'] as Map)['clean'], isTrue);
      expect((payload['device'] as Map)['apiLevel'], 36);
      expect((payload['device'] as Map)['pageSizeBytes'], 4096);
      expect((payload['execution'] as Map)['realReboot'], isTrue);
      expect((payload['execution'] as Map)['packagesRemoved'], isTrue);
      expect(payload['limitations'], contains('NOT_PHYSICAL_DEVICE_EVIDENCE'));
      expect(payload['limitations'], contains('NOT_PRODUCTION_AAB_EVIDENCE'));
    },
  );

  test('phase-3 evidence writer rejects malformed source hashes', () async {
    final temp = await Directory.systemTemp.createTemp(
      'phase3-invalid-evidence-',
    );
    addTearDown(() => temp.delete(recursive: true));

    final result = await Process.run('python3', [
      'scripts/write_phase3_emulator_evidence.py',
      '--output',
      '${temp.path}/evidence.json',
      '--git-commit',
      'dirty',
      '--git-tree',
      '2' * 40,
      '--app-apk-sha256',
      '3' * 64,
      '--test-apk-sha256',
      '4' * 64,
      '--serial',
      'emulator-5554',
      '--avd-name',
      'test',
      '--api-level',
      '36',
      '--android-release',
      '16',
      '--abi',
      'arm64-v8a',
      '--manufacturer',
      'Google',
      '--model',
      'test',
      '--build-fingerprint',
      'test/fingerprint',
      '--page-size-bytes',
      '4096',
      '--started-at-utc',
      '2026-07-19T10:00:00Z',
      '--finished-at-utc',
      '2026-07-19T10:03:00Z',
    ]);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('git-commit'));
  });
}
