// Y-05 / Y-10: the PIN lockout and the resume lock decide "same boot, how long"
// from this one channel reading. It is platform data, so it is validated here:
// a malformed elapsed value is no reading at all, and an implausible boot id
// is dropped rather than compared.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';

const _channel = MethodChannel('read-monotonic-clock-test');
const _bootId = '0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({int elapsedMs, int bootCount, String? bootId})?> readWith(
    Object? Function(MethodCall call) reply, {
    bool supported = true,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => reply(call));
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );
    return EmergencyPlatformService.forTesting(
      methodChannel: _channel,
      supported: supported,
    ).readMonotonicClock();
  }

  test('reads elapsed realtime, BOOT_COUNT and the kernel boot id', () async {
    final reading = await readWith(
      (call) => call.method == 'readMonotonicClock'
          ? <String, Object?>{
              'elapsedRealtimeMs': 123456,
              'bootCount': 7,
              'bootId': _bootId,
            }
          : null,
    );
    expect(reading, (elapsedMs: 123456, bootCount: 7, bootId: _bootId));
  });

  test('an implausible boot id is dropped, the reading is kept', () async {
    for (final bad in <Object?>['', 42, 'x' * 65, null]) {
      final reading = await readWith(
        (_) => <String, Object?>{
          'elapsedRealtimeMs': 5,
          'bootCount': -1,
          'bootId': bad,
        },
      );
      expect(reading, (elapsedMs: 5, bootCount: -1, bootId: null));
    }
  });

  test('a missing or negative elapsed value is no reading', () async {
    expect(await readWith((_) => <String, Object?>{'bootCount': 3}), isNull);
    expect(
      await readWith(
        (_) => <String, Object?>{'elapsedRealtimeMs': -1, 'bootCount': 3},
      ),
      isNull,
    );
    expect(
      await readWith((_) => <String, Object?>{'elapsedRealtimeMs': 9}),
      isNull,
      reason: 'a reading without its boot count cannot be compared',
    );
  });

  test('a failed call or an unsupported platform is no reading', () async {
    expect(
      await readWith((_) => throw PlatformException(code: 'boom')),
      isNull,
    );
    expect(
      await readWith(
        (_) => <String, Object?>{'elapsedRealtimeMs': 1, 'bootCount': 1},
        supported: false,
      ),
      isNull,
    );
  });
}
