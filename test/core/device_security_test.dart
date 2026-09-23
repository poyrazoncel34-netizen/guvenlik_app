// Structural guards for the root/jailbreak probe. The BEHAVIOUR (what each
// reply and failure classifies as) lives in
// test/core/security/device_security_service_test.dart, which drives the real
// platform channel. This file pins what a behavioural test cannot see: that
// safe_device is gone from runtime code, that the Kotlin probe is registered,
// that the OEM crash guard stays, and that no catch invents a clean verdict.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  final source = File(
    'lib/services/device_security_service.dart',
  ).readAsStringSync();
  final code = stripComments(source);

  test('safe_device is not used anywhere in runtime Dart code', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final body = stripComments(entity.readAsStringSync());
      if (body.contains('safe_device') || body.contains('SafeDevice')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A-017: safe_device converts failures into "not rooted" in both '
          'its Dart getter and its native checks',
    );
  });

  test('the app Kotlin code does not call safe_device or RootBeer', () {
    final offenders = <String>[];
    for (final entity in Directory(
      'android/app/src/main/kotlin',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.kt')) continue;
      final body = stripComments(entity.readAsStringSync());
      if (body.contains('xamdesign') || body.contains('rootbeer')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('MainActivity registers the native integrity probe', () {
    final activity = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('DeviceIntegrityChannel.register(messenger)'));
    final channel = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/integrity/'
      'DeviceIntegrityChannel.kt',
    ).readAsStringSync();
    expect(
      channel,
      contains('"com.poyrazoncel.korubeni/device_integrity"'),
      reason: 'must match DeviceSecurityService.defaultChannel',
    );
  });

  test('the probe is three-valued', () {
    expect(
      code,
      contains('enum DeviceIntegrity { clean, compromised, unknown }'),
    );
    expect(code, contains('enum ProbeOutcome { found, absent, error }'));
    expect(code, contains('Future<DeviceIntegrity> checkIntegrity()'));
  });

  test('startup still cannot be crashed by an OEM probe failure', () {
    expect(code, contains('} on Exception {'));
    expect(code, contains('} on Error {'));
    expect(code, contains('.timeout(_timeout)'));
  });

  test('clean is produced in exactly one place', () {
    expect(
      RegExp(r'DeviceIntegrity\.clean').allMatches(code).length,
      1,
      reason:
          'only aggregate() may derive clean, after every counted check '
          'read absent',
    );
  });

  test('a failed probe is recorded, not silently dropped', () {
    expect(code, contains('LocalWarningCode.deviceIntegrityUnknown'));
  });

  test('splash_screen acts on the typed verdict', () {
    final splash = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(splash, contains('DeviceSecurityService().checkIntegrity()'));
    expect(splash, contains('integrity == DeviceIntegrity.compromised'));
  });
}
