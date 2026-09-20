// A-017: the root/jailbreak probe used to answer `false` -- "clean" -- when it
// FAILED. In this app's duress model a rooted device is the one place the
// offline entitlement anchor and local data can be read, so a silent probe
// failure must not be reported as a clean device.
//
// These cases drive the real `safe_device` platform channel, so they exercise
// the classification rather than asserting on source text. Each failure mode
// below was a `false` before the fix.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/services/device_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('safe_device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  group('DeviceSecurityService.checkIntegrity', () {
    test('a rooted device is compromised', () async {
      mockChannel((call) async => call.method == 'isJailBroken' ? true : null);
      expect(
        await DeviceSecurityService().checkIntegrity(),
        DeviceIntegrity.compromised,
      );
    });

    test('a clean device is clean', () async {
      mockChannel((call) async => call.method == 'isJailBroken' ? false : null);
      expect(
        await DeviceSecurityService().checkIntegrity(),
        DeviceIntegrity.clean,
      );
    });

    test('a throwing platform implementation is unknown, NOT clean', () async {
      mockChannel((call) async {
        if (call.method == 'isJailBroken') {
          throw PlatformException(code: 'OEM_FAILURE');
        }
        return null;
      });
      expect(
        await DeviceSecurityService().checkIntegrity(),
        DeviceIntegrity.unknown,
        reason: 'a probe that threw says nothing about the device',
      );
    });

    test('a null reply is unknown, NOT clean', () async {
      // safe_device casts the reply to `bool` and lets the resulting TypeError
      // fall into its own catch, which returns false. A malformed reply is an
      // absent verdict, not a negative one.
      mockChannel((call) async => null);
      expect(
        await DeviceSecurityService().checkIntegrity(),
        DeviceIntegrity.unknown,
      );
    });

    test('a missing plugin is unknown, NOT clean', () async {
      // No handler registered at all: MissingPluginException. This is the
      // exact shape of "the detector is not there", which used to be
      // indistinguishable from "the device is fine".
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        await DeviceSecurityService().checkIntegrity(),
        DeviceIntegrity.unknown,
      );
    });
  });
}
