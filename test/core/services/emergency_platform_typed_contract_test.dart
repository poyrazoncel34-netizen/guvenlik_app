import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('emergency_platform_typed_contract_test');
  late EmergencyPlatformService service;

  SessionToken token({int generation = 1}) => SessionToken(
    protocolVersion: emergencyProtocolVersion,
    randomId: '0123456789abcdef0123456789abcdef',
    generation: generation,
    kind: EmergencySessionKind.checkIn,
  );

  Map<String, Object?> presentSession({
    required SessionToken sessionToken,
    required String state,
    String callOutcome = 'notAttempted',
    String fallbackOutcome = 'notAttempted',
  }) => <String, Object?>{
    'type': 'present',
    'session': <String, Object?>{
      'token': sessionToken.toMap(),
      'lifecycleState': state,
      'mainDeadlineMs': 4102444800000,
      'finalDeadlineMs': 4102444860000,
      'target': '+905551234567',
      'callRequestOutcome': callOutcome,
      'fallbackOutcome': fallbackOutcome,
    },
  };

  setUp(() {
    service = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 20),
      dispatchTimeout: const Duration(milliseconds: 20),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('false legacy arm acknowledgement is Unknown, never Armed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'armEmergencySession');
          return <String, Object?>{'scheduled': true, 'exact': true};
        });

    final result = await service.armEmergencySession(
      kind: EmergencySessionKind.checkIn,
      mainDeadline: DateTime(2100),
      finalDeadline: DateTime(2100).add(const Duration(minutes: 1)),
      target: '+90 555 123 45 67',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: token().randomId,
    );

    expect(result, isA<ArmUnknown>());
    expect(result.isArmed, isFalse);
  });

  test('arm command carries protocol and normalizes target', () async {
    late Map<Object?, Object?> arguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          arguments = call.arguments as Map<Object?, Object?>;
          final returnedToken = token();
          return <String, Object?>{
            'type': 'armed',
            'token': returnedToken.toMap(),
            'mainDeadlineMs': 4102444800000,
            'finalDeadlineMs': 4102444860000,
          };
        });

    final result = await service.armEmergencySession(
      kind: EmergencySessionKind.checkIn,
      mainDeadline: DateTime.fromMillisecondsSinceEpoch(4102444800000),
      finalDeadline: DateTime.fromMillisecondsSinceEpoch(4102444860000),
      target: '+90 (555) 123 45 67',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: token().randomId,
    );

    expect(result, isA<Armed>());
    expect(arguments['protocolVersion'], emergencyProtocolVersion);
    expect(arguments['kind'], 'checkIn');
    expect(arguments['requestedGeneration'], 1);
    expect(arguments['target'], '+905551234567');
    expect(arguments['entitlementDecision'], 'authorized');
  });

  test('malicious target is rejected before the platform channel', () async {
    var invocationCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          invocationCount += 1;
          return null;
        });

    final result = await service.armEmergencySession(
      kind: EmergencySessionKind.checkIn,
      mainDeadline: DateTime.fromMillisecondsSinceEpoch(4102444800000),
      finalDeadline: DateTime.fromMillisecondsSinceEpoch(4102444860000),
      target: 'tel:+905551234567',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: token().randomId,
    );

    expect(result, isA<ArmRejected>());
    expect((result as ArmRejected).reasonCode, 'invalidTarget');
    expect(invocationCount, 0);
  });

  test('armed response without its token and deadlines is Unknown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{'type': 'armed'},
        );

    final result = await service.armEmergencySession(
      kind: EmergencySessionKind.checkIn,
      mainDeadline: DateTime.fromMillisecondsSinceEpoch(4102444800000),
      finalDeadline: DateTime.fromMillisecondsSinceEpoch(4102444860000),
      target: '+905551234567',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: token().randomId,
    );

    expect(result, isA<ArmUnknown>());
    expect(result.isArmed, isFalse);
  });

  test('armed response for another random id is Unknown', () async {
    const wrong = SessionToken(
      protocolVersion: emergencyProtocolVersion,
      randomId: 'ffffffffffffffffffffffffffffffff',
      generation: 1,
      kind: EmergencySessionKind.checkIn,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'type': 'armed',
            'token': wrong.toMap(),
            'mainDeadlineMs': 4102444800000,
            'finalDeadlineMs': 4102444860000,
          },
        );

    final result = await service.armEmergencySession(
      kind: EmergencySessionKind.checkIn,
      mainDeadline: DateTime.fromMillisecondsSinceEpoch(4102444800000),
      finalDeadline: DateTime.fromMillisecondsSinceEpoch(4102444860000),
      target: '+905551234567',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: token().randomId,
    );

    expect(result, isA<ArmUnknown>());
  });

  test('revision requests and accepts only the next generation', () async {
    final current = token(generation: 3);
    late Map<Object?, Object?> arguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          arguments = call.arguments as Map<Object?, Object?>;
          final revised = token(generation: 4);
          return <String, Object?>{
            'type': 'armed',
            'token': revised.toMap(),
            'mainDeadlineMs': arguments['mainDeadlineMs'],
            'finalDeadlineMs': arguments['finalDeadlineMs'],
          };
        });

    final result = await service.reviseEmergencySession(
      token: current,
      mainDeadline: DateTime.fromMillisecondsSinceEpoch(4102444800000),
      finalDeadline: DateTime.fromMillisecondsSinceEpoch(4102444860000),
      targetSnapshot: '+905551234567',
    );

    expect(result, isA<Armed>());
    expect(arguments['requestedGeneration'], 4);
    expect(result.token?.generation, 4);
  });

  test('cancel timeout plus armed snapshot remains Unknown', () async {
    final never = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'cancelEmergencySession') return never.future;
          if (call.method == 'readEmergencySession') {
            return presentSession(sessionToken: token(), state: 'armed');
          }
          return null;
        });

    final result = await service.cancelEmergencySession(token());

    expect(result, isA<SessionCancelUnknown>());
    expect(result.isConfirmedCancelled, isFalse);
  });

  test(
    'cancel timeout reconciles a durable tombstone as already cancelled',
    () async {
      final never = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelEmergencySession') return never.future;
            if (call.method == 'readEmergencySession') {
              return presentSession(sessionToken: token(), state: 'cancelled');
            }
            return null;
          });

      final result = await service.cancelEmergencySession(token());

      expect(result, isA<SessionAlreadyCancelled>());
      expect(result.isConfirmedCancelled, isTrue);
    },
  );

  test('stale token is typed and never presented as cancelled', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'type': 'stale',
            'token': token().toMap(),
          },
        );

    final result = await service.cancelEmergencySession(token());

    expect(result, isA<SessionCancelStale>());
    expect(result.isConfirmedCancelled, isFalse);
  });

  test('cancelled response without matching token remains Unknown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{'type': 'cancelled'},
        );

    final result = await service.cancelEmergencySession(token());

    expect(result, isA<SessionCancelUnknown>());
    expect(result.isConfirmedCancelled, isFalse);
  });

  test(
    'dispatch timeout reconciles submitted request without claiming connection',
    () async {
      final never = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'dispatchEmergencySession') return never.future;
            if (call.method == 'readEmergencySession') {
              return presentSession(
                sessionToken: token(),
                state: 'requestSubmittedUnconfirmed',
                callOutcome: 'submittedUnconfirmed',
                fallbackOutcome: 'posted',
              );
            }
            return null;
          });

      final result = await service.dispatchEmergencySession(
        token: token(),
        source: 'dartTest',
      );

      expect(result.isReconciled, isTrue);
      expect(result.requestWasSubmitted, isTrue);
      expect(result.hasActionableFallback, isTrue);
      expect(result.connectionState, 'unknown');
    },
  );

  test('claimed with no recorded side effect remains Unknown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'token': token().toMap(),
            'callRequestOutcome': 'notAttempted',
            'fallbackOutcome': 'notAttempted',
            'connectionState': 'unknown',
            'terminalState': 'claimed',
          },
        );

    final result = await service.dispatchEmergencySession(
      token: token(),
      source: 'dartTest',
    );

    expect(result.isUnknown, isTrue);
    expect(result.requestWasSubmitted, isFalse);
  });

  test('dispatch response for another generation remains Unknown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'token': token(generation: 2).toMap(),
            'callRequestOutcome': 'submittedUnconfirmed',
            'fallbackOutcome': 'posted',
            'connectionState': 'unknown',
            'terminalState': 'requestSubmittedUnconfirmed',
          },
        );

    final result = await service.dispatchEmergencySession(
      token: token(),
      source: 'dartTest',
    );

    expect(result.isUnknown, isTrue);
    expect(result.requestWasSubmitted, isFalse);
  });

  test('present snapshot for another random id is not accepted', () async {
    const wrong = SessionToken(
      protocolVersion: emergencyProtocolVersion,
      randomId: 'ffffffffffffffffffffffffffffffff',
      generation: 1,
      kind: EmergencySessionKind.checkIn,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => presentSession(sessionToken: wrong, state: 'armed'),
        );

    final snapshot = await service.readEmergencySession(token());

    expect(snapshot.status, SessionReadStatus.unknown);
    expect(snapshot.isPresent, isFalse);
  });
}
