// A-017: the root/jailbreak probe used to answer `false` -- "clean" -- when it
// FAILED. In this app's duress model a rooted device is the one place the
// offline entitlement anchor and local data can be read, so a silent probe
// failure must not be reported as a clean device.
//
// These cases drive the real native-probe MethodChannel with mocked replies,
// so they exercise decoding and classification rather than source text. The
// rule under test: only a reply in which every counted check says `absent`
// may produce `clean`.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/services/device_security_service.dart';

const Map<String, String> allAbsent = <String, String>{
  'suBinary': 'absent',
  'magiskBinary': 'absent',
  'superuserArtifacts': 'absent',
  'pathSuBinary': 'absent',
  'rwSystemMounts': 'absent',
  'testKeys': 'absent',
  'dangerousProps': 'absent',
  'developmentEnvironment': 'absent',
};

Map<String, String> reply(Map<String, String> overrides) => <String, String>{
  ...allAbsent,
  ...overrides,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = DeviceSecurityService.defaultChannel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  Future<DeviceIntegrity> check({Duration? timeout}) => DeviceSecurityService(
    timeout: timeout ?? const Duration(seconds: 3),
  ).checkIntegrity();

  test('the channel is the app-owned probe, not safe_device', () {
    expect(channel.name, 'com.poyrazoncel.korubeni/device_integrity');
  });

  test('every check absent is the only clean', () async {
    mockChannel((call) async => call.method == 'probe' ? allAbsent : null);
    expect(await check(), DeviceIntegrity.clean);
  });

  group('any hard check found is compromised, even in a dev build', () {
    for (final name in DeviceSecurityService.hardChecks) {
      test(name, () async {
        mockChannel(
          (_) async =>
              reply({name: 'found', 'developmentEnvironment': 'found'}),
        );
        expect(await check(), DeviceIntegrity.compromised);
      });
    }
  });

  group('build signals', () {
    for (final name in DeviceSecurityService.buildChecks) {
      test('$name found on a user build is compromised', () async {
        mockChannel((_) async => reply({name: 'found'}));
        expect(await check(), DeviceIntegrity.compromised);
      });
      test('$name found with dev-environment ERROR is compromised', () async {
        mockChannel(
          (_) async =>
              reply({name: 'found', 'developmentEnvironment': 'error'}),
        );
        expect(await check(), DeviceIntegrity.compromised);
      });
      test('$name found on an observed dev build is ignored (safe_device '
          'parity)', () async {
        mockChannel(
          (_) async =>
              reply({name: 'found', 'developmentEnvironment': 'found'}),
        );
        expect(await check(), DeviceIntegrity.clean);
      });
    }
  });

  group('an error in any counted check is unknown, never clean', () {
    for (final name in [
      ...DeviceSecurityService.hardChecks,
      ...DeviceSecurityService.buildChecks,
    ]) {
      test(name, () async {
        mockChannel((_) async => reply({name: 'error'}));
        expect(await check(), DeviceIntegrity.unknown);
      });
    }
    test('dev-environment error alone leaves build checks counted', () async {
      mockChannel(
        (_) async => reply({
          'developmentEnvironment': 'error',
          'dangerousProps': 'error',
        }),
      );
      expect(await check(), DeviceIntegrity.unknown);
    });
    test('a hard-check error stays unknown on a dev build', () async {
      mockChannel(
        (_) async => reply({
          'developmentEnvironment': 'found',
          'rwSystemMounts': 'error',
        }),
      );
      expect(await check(), DeviceIntegrity.unknown);
    });
  });

  group('malformed replies are unknown, never clean', () {
    final cases = <String, Object?>{
      'null': null,
      'bool true (old safe_device shape)': true,
      'bool false (old safe_device shape)': false,
      'string': 'absent',
      'list': <Object>['absent'],
      'empty map': <String, String>{},
      'missing key': Map<String, String>.of(allAbsent)..remove('suBinary'),
      'unknown value': reply({'suBinary': 'no'}),
      'null value': <String, Object?>{...allAbsent, 'magiskBinary': null},
      'bool value': <String, Object?>{...allAbsent, 'rwSystemMounts': false},
      'upper-case value': reply({'testKeys': 'ABSENT'}),
    };
    cases.forEach((label, value) {
      test(label, () async {
        mockChannel((_) async => value);
        expect(await check(), DeviceIntegrity.unknown);
      });
    });
  });

  group('channel failures are unknown, never clean', () {
    test('PlatformException', () async {
      mockChannel((_) async => throw PlatformException(code: 'PROBE_FAILED'));
      expect(await check(), DeviceIntegrity.unknown);
    });
    test('MissingPluginException (no native handler)', () async {
      // No mock registered.
      expect(await check(), DeviceIntegrity.unknown);
    });
    test('notImplemented', () async {
      mockChannel((_) async => throw MissingPluginException());
      expect(await check(), DeviceIntegrity.unknown);
    });
    test('timeout', () async {
      final never = Completer<Object?>();
      mockChannel((_) => never.future);
      expect(
        await check(timeout: const Duration(milliseconds: 50)),
        DeviceIntegrity.unknown,
      );
    });
  });
}
