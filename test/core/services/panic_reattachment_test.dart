// A-11 (chaos audit 2026-10-08, reproduced on an API 35 emulator): a panic
// countdown's process was killed at T+2; reopening showed the splash and the
// unlock screen but no countdown, and native called at the deadline (10:17:48)
// -- the user never got the PIN-cancel surface back for the time that was left.
// Native still held the session ARMED; the UI simply never asked.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/panic_reattachment.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';

class _FakeClock implements SafetyClock {
  DateTime wall = DateTime(2026, 10, 8, 10, 17, 40);

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => Duration.zero;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('panic-reattachment-test');
  final clock = _FakeClock();
  late Map<String, Object?>? reply;
  late List<MethodCall> calls;

  final token = <String, Object?>{
    'protocolVersion': emergencyProtocolVersion,
    'randomId': 'countdown-1791443857000-42',
    'generation': 1,
    'kind': 'panic',
  };

  Map<String, Object?> present(String lifecycle, DateTime deadline) =>
      <String, Object?>{
        'type': 'present',
        'session': <String, Object?>{
          'token': token,
          'lifecycleState': lifecycle,
          'mainDeadlineMs': deadline.millisecondsSinceEpoch,
          'finalDeadlineMs': deadline.millisecondsSinceEpoch,
          'target': '05551234567',
          'callRequestOutcome': 'notAttempted',
          'fallbackOutcome': 'notAttempted',
          'mainDurationMs': 10000,
        },
      };

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<PanicReattachment?> discover() => PanicReattachment.discover(
    EmergencyPlatformService.forTesting(methodChannel: channel),
    clock: clock,
  );

  test('an ARMED panic with time left is adopted as it is', () async {
    final deadline = clock.wall.add(const Duration(seconds: 8));
    reply = present('armed', deadline);

    final session = await discover();

    expect(session, isNotNull);
    expect(session!.armed.sessionToken.randomId, token['randomId']);
    expect(session.armed.finalDeadline, deadline);
    expect(session.target, '05551234567');
    expect(calls.map((c) => c.method), <String>['discoverEmergencySession']);
    expect(
      (calls.single.arguments as Map<Object?, Object?>)['kind'],
      EmergencySessionKind.panic.wireName,
    );
  });

  test('nothing is re-shown once the deadline has passed', () async {
    reply = present('armed', clock.wall.subtract(const Duration(seconds: 1)));
    expect(await discover(), isNull);
  });

  for (final state in <String>[
    'claimed',
    'requestSubmittedUnconfirmed',
    'cancelled',
  ]) {
    test('a $state session is not re-shown', () async {
      reply = present(state, clock.wall.add(const Duration(seconds: 8)));
      expect(await discover(), isNull);
    });
  }

  test('an absent or unreadable slot is not re-shown', () async {
    reply = <String, Object?>{'type': 'absent'};
    expect(await discover(), isNull);
    reply = null;
    expect(await discover(), isNull);
  });
}
