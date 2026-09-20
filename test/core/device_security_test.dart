// Structural guards for the root/jailbreak probe. The BEHAVIOUR (what each
// failure mode classifies as) lives in
// test/core/security/device_security_service_test.dart, which drives the real
// platform channel. This file only pins the things a behavioural test cannot
// see: that the probe still exists, that it keeps its OEM crash guard, and
// that no catch branch is allowed to invent a clean verdict.
//
// It replaces an earlier version that asserted `source.contains('try')` and
// `source.contains('isCompromised')`. Those passed for the defective code too:
// the old implementation had a try/catch, and its catch returned `false`.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/services/device_security_service.dart',
  ).readAsStringSync();
  // Comments in this file quote the defect on purpose; only code counts.
  final code = source.replaceAll(RegExp(r'//[^\n]*'), '');

  test('the probe exists and is three-valued', () {
    expect(
      File('lib/services/device_security_service.dart').existsSync(),
      isTrue,
    );
    expect(
      code,
      contains('enum DeviceIntegrity { clean, compromised, unknown }'),
      reason:
          'a boolean cannot distinguish "not rooted" from "could not tell", '
          'which is the whole of A-017',
    );
    expect(code, contains('Future<DeviceIntegrity> checkIntegrity()'));
  });

  test('startup still cannot be crashed by an OEM probe failure', () {
    // The original catch-everything existed for a real reason: this runs on
    // the splash path. Losing that guard would trade a fail-open for a crash.
    expect(code, contains('try {'));
    expect(code, contains('} on Exception {'));
    expect(code, contains('} on Error {'));
  });

  test('no failure branch may return a clean verdict', () {
    // The exact regression, stated as a rule rather than a keyword: the only
    // place `clean` may be produced is the branch that actually read `false`
    // from the platform.
    final cleanReturns = RegExp(
      r'return\s+DeviceIntegrity\.clean',
    ).allMatches(code).length;
    expect(
      cleanReturns,
      0,
      reason:
          'DeviceIntegrity.clean must only be reachable from the ternary on '
          'the platform reply, never from a `return` inside a catch',
    );
    expect(
      code,
      contains('raw ? DeviceIntegrity.compromised : DeviceIntegrity.clean'),
      reason: 'the single place a verdict is derived from the real reply',
    );
  });

  test('the plugin init contract is still honoured', () {
    // checkIntegrity reads the safe_device channel directly (the plugin's own
    // getter swallows errors into `false`), so it must still perform the
    // one-shot init the plugin would have done.
    expect(code, contains('SafeDevice.ensureInitiated()'));
    expect(code, contains("MethodChannel('safe_device')"));
    expect(code, contains("invokeMethod<bool>('isJailBroken')"));
  });

  test('a failed probe is recorded, not silently dropped', () {
    expect(code, contains('LocalWarningCode.deviceIntegrityUnknown'));
  });

  test('splash_screen acts on the typed verdict', () {
    final splash = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(splash, contains('DeviceSecurityService().checkIntegrity()'));
    expect(
      splash,
      contains('integrity == DeviceIntegrity.compromised'),
      reason:
          'the warning dialog belongs to `compromised` only; `unknown` is '
          'recorded, not turned into an accusation',
    );
  });
}
