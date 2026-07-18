import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File(
    'scripts/phase3_physical_device_preflight.sh',
  ).readAsStringSync();
  final matrix = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();

  test('physical-device preflight binds evidence to the exact Play build', () {
    expect(script, contains('EXPECTED_VERSION_NAME'));
    expect(script, contains('EXPECTED_VERSION_CODE'));
    expect(script, contains('EXPECTED_APP_SIGNING_SHA256'));
    expect(script, contains('com.android.vending'));
    expect(script, contains('DEBUGGABLE|TEST_ONLY'));
    expect(script, contains('PASS_PREFLIGHT_ONLY'));
    expect(script, contains('Device serial: NOT_RECORDED'));
  });

  test('physical-device preflight refuses emulator evidence', () {
    expect(script, contains('get_prop ro.kernel.qemu'));
    expect(script, contains('refusing emulator target'));
    expect(script, contains(r'[ "$QEMU_FLAG" != "1" ]'));
  });

  test('physical-device preflight contains no runtime mutation command', () {
    const forbiddenCommands = <String>[
      'shell am start',
      'shell am kill',
      'shell am force-stop',
      'shell pm clear',
      'shell reboot',
      ' uninstall ',
      'android.intent.action.CALL',
    ];

    for (final command in forbiddenCommands) {
      expect(script, isNot(contains(command)), reason: command);
    }
  });

  test(
    'real-device matrix requires the preflight without treating it as QA',
    () {
      expect(matrix, contains('phase3_physical_device_preflight.sh'));
      expect(matrix, contains('PASS_PREFLIGHT_ONLY'));
      expect(matrix, contains('does **not** pass any scenario row'));
    },
  );
}
