import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('emergency_platform_behavior_matrix_test');
  const eventControlChannel = MethodChannel(
    'com.poyrazoncel.korubeni/emergency_platform/events',
  );
  late EmergencyPlatformService service;

  const token = SessionToken(
    protocolVersion: emergencyProtocolVersion,
    randomId: '0123456789abcdef0123456789abcdef',
    generation: 1,
    kind: EmergencySessionKind.checkIn,
  );
  final mainDeadline = DateTime.fromMillisecondsSinceEpoch(4102444800000);
  final finalDeadline = DateTime.fromMillisecondsSinceEpoch(4102444860000);

  Map<String, Object?> presentSession({
    SessionToken sessionToken = token,
    String state = 'armed',
    Object? mainDeadlineMs = 4102444800000,
    Object? finalDeadlineMs = 4102444860000,
    Object? target = '+905551234567',
    Object? callOutcome = 'notAttempted',
    Object? fallbackOutcome = 'notAttempted',
  }) => <String, Object?>{
    'type': 'present',
    'session': <String, Object?>{
      'token': sessionToken.toMap(),
      'lifecycleState': state,
      'mainDeadlineMs': mainDeadlineMs,
      'finalDeadlineMs': finalDeadlineMs,
      'target': target,
      'callRequestOutcome': callOutcome,
      'fallbackOutcome': fallbackOutcome,
    },
  };

  Map<String, Object?> dispatchResponse({
    SessionToken sessionToken = token,
    Object? callOutcome = 'submittedUnconfirmed',
    Object? fallbackOutcome = 'posted',
    Object? connectionState = 'unknown',
    Object? terminalState = 'requestSubmittedUnconfirmed',
  }) => <String, Object?>{
    'token': sessionToken.toMap(),
    'callRequestOutcome': callOutcome,
    'fallbackOutcome': fallbackOutcome,
    'connectionState': connectionState,
    'terminalState': terminalState,
  };

  Future<ArmResult> arm() => service.armEmergencySession(
    kind: EmergencySessionKind.checkIn,
    mainDeadline: mainDeadline,
    finalDeadline: finalDeadline,
    target: '+90 555 123 45 67',
    entitlementDecision: EntitlementDecision.authorized,
    pinConfigured: true,
    randomId: token.randomId,
  );

  setUp(() {
    service = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 10),
      dispatchTimeout: const Duration(milliseconds: 10),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventControlChannel, null);
  });

  test('unsupported platform fails every safety API closed', () async {
    final unsupported = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      supported: false,
    );

    expect(unsupported.isSupported, isFalse);
    await unsupported.initialize();
    expect(
      await unsupported.armEmergencySession(
        kind: EmergencySessionKind.panic,
        mainDeadline: mainDeadline,
        finalDeadline: finalDeadline,
        target: '+905551234567',
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
        randomId: token.randomId,
      ),
      isA<ArmRejected>(),
    );
    expect(
      await unsupported.cancelEmergencySession(token),
      isA<SessionCancelUnknown>(),
    );
    expect(
      (await unsupported.readEmergencySession(token)).status,
      SessionReadStatus.unknown,
    );
    expect(
      (await unsupported.dispatchEmergencySession(
        token: token,
        source: 'test',
      )).isUnknown,
      isTrue,
    );
    expect(
      (await unsupported.getEmergencyCapabilities(
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
        callableTarget: true,
      )).unattendedSessionReady,
      isFalse,
    );
    expect(await unsupported.wipeEmergencySessions(), WipeResult.unknown);
    expect(await unsupported.consumePendingTrigger(), isNull);
    expect(await unsupported.getDeviceState(), isEmpty);
    expect(await unsupported.readNativeSafetyDiagnostics(), isEmpty);
    expect(await unsupported.canScheduleExactAlarms(), isFalse);
    await unsupported.requestExactAlarmPermission();
    expect(await unsupported.openManufacturerSettings(), isFalse);
    await unsupported.dispose();
  });

  test(
    'native diagnostics export accepts only bounded allowlisted code and time',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'readNativeSafetyDiagnostics');
            return <Object?>[
              <String, Object?>{
                'code': 'boot_receiver_boundary_failure',
                'occurredAtMs': 1234,
                'injected': '+905551234567',
              },
              <String, Object?>{
                'code': 'future_or_attacker_controlled_code',
                'occurredAtMs': 1235,
              },
              <String, Object?>{
                'code': 'clock_receiver_boundary_failure',
                'occurredAtMs': 'not-a-number',
              },
              ...List<Object?>.generate(
                70,
                (index) => <String, Object?>{
                  'code': 'panic_receiver_boundary_failure',
                  'occurredAtMs': 2000 + index,
                },
              ),
            ];
          });

      final events = await service.readNativeSafetyDiagnostics();

      expect(events, hasLength(64));
      expect(events.first, <String, Object?>{
        'code': 'boot_receiver_boundary_failure',
        'occurredAtMs': 1234,
      });
      expect(
        events.first.keys,
        unorderedEquals(<String>['code', 'occurredAtMs']),
      );
      expect(
        events.any((event) => event.values.contains('+905551234567')),
        isFalse,
      );
      expect(
        events.any(
          (event) => event['code'] == 'future_or_attacker_controlled_code',
        ),
        isFalse,
      );
    },
  );

  test('native diagnostics export fails closed on platform errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'storageFailure'),
        );

    expect(await service.readNativeSafetyDiagnostics(), isEmpty);
  });

  test(
    'event initialization is idempotent and forwards mapped events',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(eventControlChannel, (call) async {
            expect(call.method, anyOf('listen', 'cancel'));
            return null;
          });

      await service.initialize();
      await service.initialize();
      final received = service.events.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            eventControlChannel.name,
            const StandardMethodCodec().encodeSuccessEnvelope(
              <Object?, Object?>{1: 'event'},
            ),
            (_) {},
          );

      expect(await received, <String, Object?>{'1': 'event'});
      await service.dispose();
    },
  );

  test('arm timeout reconciles only an exact durable armed snapshot', () async {
    final never = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'armEmergencySession') return never.future;
          if (call.method == 'readEmergencySession') return presentSession();
          return null;
        });

    final result = await arm();

    expect(result, isA<Armed>());
    expect(result.token, token);
  });

  test('arm rejection and malformed deadline responses remain typed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'type': 'rejected',
            'reasonCode': 'notReady',
            'token': token.toMap(),
          },
        );
    final rejected = await arm();
    expect(rejected, isA<ArmRejected>());
    expect((rejected as ArmRejected).reasonCode, 'notReady');
    expect(rejected.rejectedToken, token);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{
            'type': 'armed',
            'token': token.toMap(),
            'mainDeadlineMs': finalDeadline.millisecondsSinceEpoch,
            'finalDeadlineMs': mainDeadline.millisecondsSinceEpoch,
          },
        );
    expect(await arm(), isA<ArmUnknown>());
  });

  test('typed invocation errors preserve uncertainty without leaking details', () async {
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'armEmergencySession') {
            throw PlatformException(
              code: 'CANARY_PRIVATE_PLATFORM_CODE',
              message: 'PIN=8642 phone=+905551112233',
            );
          }
          return <String, Object?>{'type': 'absent'};
        });
    final platformFailure = await arm();
    expect(platformFailure, isA<ArmUnknown>());
    expect((platformFailure as ArmUnknown).reasonCode, 'platformError');
    expect(messages.join('\n'), isNot(contains('CANARY_PRIVATE_PLATFORM_CODE')));
    expect(messages.join('\n'), isNot(contains('8642')));
    expect(messages.join('\n'), isNot(contains('+905551112233')));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'armEmergencySession') throw Exception('boom');
          return <String, Object?>{'type': 'absent'};
        });
    final unexpectedFailure = await arm();
    expect(unexpectedFailure, isA<ArmUnknown>());
    // The Flutter test messenger transports handler exceptions as a platform
    // error envelope; the API must still preserve uncertainty.
    expect((unexpectedFailure as ArmUnknown).reasonCode, 'platformError');
  });

  test('cancel response matrix rejects false cancellation', () async {
    Future<CancelResult> respond(Map<String, Object?> response) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => response);
      return service.cancelEmergencySession(token);
    }

    expect(
      await respond(<String, Object?>{
        'type': 'cancelled',
        'token': token.toMap(),
      }),
      isA<SessionCancelled>(),
    );
    expect(
      await respond(<String, Object?>{
        'type': 'alreadyCancelled',
        'token': token.toMap(),
      }),
      isA<SessionAlreadyCancelled>(),
    );
    final tooLate = await respond(<String, Object?>{
      'type': 'tooLate',
      'token': token.toMap(),
      'terminalState': 'requestFailed',
    });
    expect(tooLate, isA<SessionCancelTooLate>());
    expect(
      (tooLate as SessionCancelTooLate).terminalState,
      EmergencySessionLifecycle.requestFailed,
    );
    expect(
      await respond(<String, Object?>{
        'type': 'tooLate',
        'token': token.toMap(),
        'terminalState': 'cancelled',
      }),
      isA<SessionCancelUnknown>(),
    );
    expect(
      await respond(<String, Object?>{
        'type': 'unexpected',
        'reasonCode': 'nativeUnknown',
        'token': token.toMap(),
      }),
      isA<SessionCancelUnknown>(),
    );
  });

  test(
    'cancel timeout reconciles claimed/terminal but not corrupt state',
    () async {
      final never = Completer<Object?>();
      var state = 'claimed';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelEmergencySession') return never.future;
            return presentSession(state: state);
          });

      expect(
        await service.cancelEmergencySession(token),
        isA<SessionCancelTooLate>(),
      );
      state = 'requestFailed';
      expect(
        await service.cancelEmergencySession(token),
        isA<SessionCancelTooLate>(),
      );
      state = 'corrupted';
      expect(
        await service.cancelEmergencySession(token),
        isA<SessionCancelUnknown>(),
      );
    },
  );

  test(
    'snapshot parser classifies absent, corrupt and malformed records',
    () async {
      Future<SessionSnapshot> respond(Object? response) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => response);
        return service.readEmergencySession(token);
      }

      expect(
        (await respond(<String, Object?>{
          'type': 'absent',
          'reasonCode': 'none',
        })).status,
        SessionReadStatus.absent,
      );
      expect(
        (await respond(<String, Object?>{
          'type': 'corrupted',
          'reasonCode': 'schema',
        })).status,
        SessionReadStatus.corrupted,
      );
      expect(
        (await respond(<String, Object?>{'type': 'future'})).status,
        SessionReadStatus.unknown,
      );
      expect(
        (await respond(<String, Object?>{'type': 'present'})).reasonCode,
        'missingSession',
      );
      expect(
        (await respond(<String, Object?>{
          'type': 'present',
          'session': <String, Object?>{'token': token.toMap()},
        })).reasonCode,
        'malformedSession',
      );
      expect(
        (await respond(presentSession(state: 'unknown'))).reasonCode,
        'malformedSession',
      );
      expect(
        (await respond(presentSession(finalDeadlineMs: 1))).reasonCode,
        'malformedSession',
      );
      expect(
        (await respond(presentSession(target: 123))).reasonCode,
        'malformedSession',
      );

      final present = await respond(
        presentSession(
          callOutcome: 'submitted_unconfirmed',
          fallbackOutcome: 'expired',
        ),
      );
      expect(present.status, SessionReadStatus.present);
      expect(
        present.callRequestOutcome,
        CallRequestOutcome.submittedUnconfirmed,
      );
      expect(present.fallbackOutcome, FallbackOutcome.expired);
    },
  );

  test(
    'read timeout returns an unknown snapshot for the requested token',
    () async {
      final never = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => never.future);

      final snapshot = await service.readEmergencySession(token);

      expect(snapshot.status, SessionReadStatus.unknown);
      expect(snapshot.token, token);
      expect(snapshot.reasonCode, 'timeout');
    },
  );

  test(
    'dispatch parser accepts side-effect truth and rejects false truth',
    () async {
      Future<DispatchResult> respond(Map<String, Object?> response) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => response);
        return service.dispatchEmergencySession(token: token, source: 'test');
      }

      final failed = await respond(
        dispatchResponse(
          callOutcome: 'failed',
          fallbackOutcome: 'expired',
          terminalState: 'requestFailed',
        ),
      );
      expect(failed.isUnknown, isFalse);
      expect(failed.callRequestOutcome, CallRequestOutcome.failed);
      expect(failed.fallbackOutcome, FallbackOutcome.expired);

      final malformed = <Map<String, Object?>>[
        dispatchResponse(connectionState: 'connected'),
        dispatchResponse(terminalState: 'absent'),
        dispatchResponse(callOutcome: 'newOutcome'),
        dispatchResponse(fallbackOutcome: 'newOutcome'),
        dispatchResponse(
          callOutcome: 'notAttempted',
          fallbackOutcome: 'notAttempted',
          terminalState: 'claimed',
        ),
      ];
      for (final response in malformed) {
        expect((await respond(response)).isUnknown, isTrue);
      }
    },
  );

  test('dispatch timeout without durable evidence remains Unknown', () async {
    final never = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'dispatchEmergencySession') return never.future;
          return presentSession();
        });

    final result = await service.dispatchEmergencySession(
      token: token,
      source: 'test',
    );

    expect(result.isUnknown, isTrue);
  });

  test(
    'capability and wipe responses are fully typed and fail closed',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getEmergencyCapabilities') {
              return <String, Object?>{
                'supportedOs': true,
                'telephonyCalling': true,
                'telecomAvailable': true,
                'dialHandlerAvailable': true,
                'exactAlarmGranted': true,
                'notificationsEnabled': true,
                'alertChannelHigh': true,
                'callPermissionGranted': true,
                'pinConfigured': true,
                'callableTarget': true,
                'entitlementDecision': 'authorized',
              };
            }
            return <String, Object?>{'type': 'completed'};
          });
      final capabilities = await service.getEmergencyCapabilities(
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
        callableTarget: true,
      );
      expect(capabilities.unattendedSessionReady, isTrue);
      expect(await service.wipeEmergencySessions(), WipeResult.completed);

      for (final entry in <String, WipeResult>{
        'pending': WipeResult.pending,
        'tooLate': WipeResult.tooLate,
        'future': WipeResult.unknown,
      }.entries) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (call) async => <String, Object?>{'type': entry.key},
            );
        expect(await service.wipeEmergencySessions(), entry.value);
      }
    },
  );

  test('legacy platform helpers contain plugin failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'consumePendingTrigger' => <Object?, Object?>{1: 'trigger'},
            'getDeviceState' => <String, Object?>{'locked': true},
            'canScheduleExactAlarms' => true,
            'openManufacturerSettings' => true,
            _ => null,
          };
        });
    expect(await service.consumePendingTrigger(), <String, Object?>{
      '1': 'trigger',
    });
    expect(await service.getDeviceState(), <String, Object?>{'locked': true});
    expect(await service.canScheduleExactAlarms(), isTrue);
    expect(await service.openManufacturerSettings(), isTrue);
    await service.requestExactAlarmPermission();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'pluginFailure'),
        );
    expect(await service.consumePendingTrigger(), isEmpty);
    expect(await service.getDeviceState(), isEmpty);
    expect(await service.canScheduleExactAlarms(), isFalse);
    expect(await service.openManufacturerSettings(), isFalse);
    await service.requestExactAlarmPermission();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw Exception('unexpected'),
        );
    expect(await service.getDeviceState(), isEmpty);
    expect(await service.canScheduleExactAlarms(), isFalse);
    await service.requestExactAlarmPermission();

    final never = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => never.future);
    expect(await service.getDeviceState(), isEmpty);
    expect(await service.canScheduleExactAlarms(), isFalse);
    await service.requestExactAlarmPermission();
  });
}
