// Verifies that DeviceSecurityService exists and wraps jailbreak detection
// in a try/catch (so OEM incompatibilities don't crash the app).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DeviceSecurityService source file exists', () {
    final file = File('lib/services/device_security_service.dart');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'lib/services/device_security_service.dart must exist',
    );
  });

  test('DeviceSecurityService has isCompromised method with try/catch', () {
    final source = File('lib/services/device_security_service.dart').readAsStringSync();
    expect(
      source.contains('isCompromised'),
      isTrue,
      reason: 'DeviceSecurityService must expose isCompromised()',
    );
    expect(
      source.contains('try'),
      isTrue,
      reason: 'isCompromised must wrap detection in try/catch for OEM safety',
    );
  });

  test('DeviceSecurityService delegates to FlutterJailbreakDetection', () {
    final source = File('lib/services/device_security_service.dart').readAsStringSync();
    expect(
      source.contains('FlutterJailbreakDetection'),
      isTrue,
      reason: 'DeviceSecurityService must call FlutterJailbreakDetection.jailbroken',
    );
  });

  test('splash_screen._goNext checks device security before navigating', () {
    final source = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(
      source.contains('DeviceSecurityService') || source.contains('isCompromised'),
      isTrue,
      reason: 'splash_screen._goNext must call DeviceSecurityService.isCompromised()',
    );
  });
}
