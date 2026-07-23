import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Contacts implements ContactsRepository {
  _Contacts([this.primary]);

  EmergencyContact? primary;

  @override
  Future<void> clearPrimaryEmergencyContact() async => primary = null;

  @override
  Future<List<String>> getAllEmergencyNumbers() async =>
      primary == null ? const <String>[] : <String>[primary!.phone];

  @override
  Future<List<EmergencyContact>> getContactRecords() async => primary == null
      ? const <EmergencyContact>[]
      : <EmergencyContact>[primary!];

  @override
  Future<List<String>> getContacts() => getAllEmergencyNumbers();

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;

  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {
    primary = contacts.isEmpty ? null : contacts.first;
  }

  @override
  Future<void> saveContacts(List<String> numbers) async {
    primary = numbers.isEmpty
        ? null
        : EmergencyContact(name: 'Kişi', phone: numbers.first, isPrimary: true);
  }

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) =>
      saveContacts(numbers);

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    primary = EmergencyContact(name: name, phone: phone, isPrimary: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('check_in_service_behavior_matrix_test');
  const fixedToken = SessionToken(
    protocolVersion: emergencyProtocolVersion,
    randomId: '0123456789abcdef0123456789abcdef',
    generation: 1,
    kind: EmergencySessionKind.checkIn,
  );
  late _Contacts contacts;
  late EmergencyPlatformService platform;
  late CheckInService service;
  late bool disposed;

  Map<String, Object?> armedResponse(MethodCall call) {
    final arguments = call.arguments as Map<Object?, Object?>;
    return <String, Object?>{
      'type': 'armed',
      'token': <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'randomId': arguments['randomId'],
        'generation': arguments['requestedGeneration'],
        'kind': arguments['kind'],
      },
      'mainDeadlineMs': arguments['mainDeadlineMs'],
      'finalDeadlineMs': arguments['finalDeadlineMs'],
    };
  }

  Map<String, Object?> present({
    SessionToken token = fixedToken,
    String state = 'armed',
    required DateTime mainDeadline,
    required DateTime finalDeadline,
    String target = '+905551112233',
    String callOutcome = 'notAttempted',
    String fallbackOutcome = 'notAttempted',
  }) => <String, Object?>{
    'type': 'present',
    'session': <String, Object?>{
      'token': token.toMap(),
      'lifecycleState': state,
      'mainDeadlineMs': mainDeadline.millisecondsSinceEpoch,
      'finalDeadlineMs': finalDeadline.millisecondsSinceEpoch,
      'target': target,
      'callRequestOutcome': callOutcome,
      'fallbackOutcome': fallbackOutcome,
    },
  };

  Map<String, Object?> dispatch({
    SessionToken token = fixedToken,
    String callOutcome = 'submittedUnconfirmed',
    String fallbackOutcome = 'posted',
    String terminalState = 'requestSubmittedUnconfirmed',
  }) => <String, Object?>{
    'token': token.toMap(),
    'callRequestOutcome': callOutcome,
    'fallbackOutcome': fallbackOutcome,
    'connectionState': 'unknown',
    'terminalState': terminalState,
  };

  Map<String, Object?> persistedProjection({
    SessionToken token = fixedToken,
    int totalSeconds = 300,
  }) => <String, Object?>{
    'active': true,
    'totalSeconds': totalSeconds,
    'endAt': DateTime.now().toIso8601String(),
    'graceEndAt': DateTime.now()
        .add(const Duration(minutes: 1))
        .toIso8601String(),
    'token': token.toMap(),
  };

  CheckInService makeService({
    String sessionId = CheckInExpiryCoordinator.checkInSession,
    bool sideEffectsEnabled = false,
    bool Function()? contactsConsentAllowed,
  }) => CheckInService.forTesting(
    sessionId: sessionId,
    platform: platform,
    contactsRepository: contacts,
    contactsConsentAllowed: contactsConsentAllowed ?? () => true,
    sideEffectsEnabled: sideEffectsEnabled,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    contacts = _Contacts(
      const EmergencyContact(
        name: 'Birincil',
        phone: '+90 555 111 22 33',
        isPrimary: true,
      ),
    );
    platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 20),
      dispatchTimeout: const Duration(milliseconds: 20),
    );
    service = makeService();
    disposed = false;
  });

  tearDown(() {
    if (!disposed) service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'inactive and invalid requests are rejected without native mutation',
    () async {
      var methodCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls++;
            return <String, Object?>{
              'type': 'rejected',
              'reasonCode': 'notReady',
            };
          });

      final invalidDuration = await service.startSession(
        minutes: 0,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      expect((invalidDuration as ArmRejected).reasonCode, 'invalidDuration');

      contacts.primary = null;
      final missingTarget = await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      expect(
        (missingTarget as ArmRejected).reasonCode,
        'callableTargetMissing',
      );
      expect(methodCalls, 0);
      expect((await service.confirmSafeSession()), isA<ArmRejected>());
      expect(await service.stopSession(), isNull);
      await service.handleNativeGraceStarted();
      await service.handleNativeExpired();

      contacts.primary = const EmergencyContact(
        name: 'Birincil',
        phone: '+905551112233',
        isPrimary: true,
      );
      // Compatibility boundary must remain fail-closed for unmigrated callers.
      // ignore: deprecated_member_use_from_same_package
      expect(await service.start(5), isFalse);
      expect(methodCalls, 1);
    },
  );

  test(
    'withdrawn contact consent blocks a new arm before native mutation',
    () async {
      service.dispose();
      disposed = true;
      service = makeService(contactsConsentAllowed: () => false);
      disposed = false;
      var methodCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls++;
            return armedResponse(call);
          });

      final result = await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );

      expect((result as ArmRejected).reasonCode, 'contactConsentRequired');
      expect(methodCalls, 0);
      expect(service.isActive, isFalse);
    },
  );

  test(
    'authoritative wipe clears persisted and in-memory projection',
    () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'armEmergencySession') {
              return armedResponse(call);
            }
            return null;
          });
      expect(
        await service.startSession(
          minutes: 5,
          entitlementDecision: EntitlementDecision.authorized,
          pinConfigured: true,
        ),
        isA<Armed>(),
      );
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('check_in_state_v2'), isTrue);

      expect(await service.clearAfterAuthoritativeNativeWipe(), isTrue);

      prefs = await SharedPreferences.getInstance();
      expect(service.isActive, isFalse);
      expect(service.sessionToken, isNull);
      expect(prefs.containsKey('check_in_state_v2'), isFalse);
      expect(methods, isNot(contains('cancelEmergencySession')));
    },
  );

  test(
    'safe-walk start, duplicate start and confirmed stop run side effects safely',
    () async {
      service.dispose();
      disposed = true;
      service = makeService(
        sessionId: CheckInExpiryCoordinator.safeWalkSession,
        sideEffectsEnabled: true,
      );
      disposed = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'armEmergencySession') {
              return armedResponse(call);
            }
            if (call.method == 'cancelEmergencySession') {
              return <String, Object?>{
                'type': 'cancelled',
                'token': service.sessionToken!.toMap(),
              };
            }
            return null;
          });

      expect(
        (await service.startSession(
          minutes: 1,
          entitlementDecision: EntitlementDecision.authorized,
          pinConfigured: true,
        )),
        isA<Armed>(),
      );
      expect(service.isActive, isTrue);
      final duplicate = await service.startSession(
        minutes: 1,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      expect((duplicate as ArmRejected).reasonCode, 'sessionAlreadyActive');

      // Exercise the legacy boundary while asserting the typed result.
      // ignore: deprecated_member_use_from_same_package
      final cancelled = await service.stop();
      expect(cancelled, isA<SessionCancelled>());
      expect(service.isActive, isFalse);
    },
  );

  test(
    'post-dispatch side effects remain best effort and cannot undo native truth',
    () async {
      service.dispose();
      disposed = true;
      service = makeService(sideEffectsEnabled: true);
      disposed = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'armEmergencySession') {
              return armedResponse(call);
            }
            if (call.method == 'dispatchEmergencySession') {
              return dispatch(token: service.sessionToken!);
            }
            return null;
          });

      final started = await service.startSession(
        minutes: 1,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      expect(started, isA<Armed>());
      expect(service.lastArmResult, same(started));
      expect(service.lastCancelResult, isNull);
      expect(service.nativeScheduleDegraded, isFalse);

      final revised = await service.confirmSafeSession();
      expect(revised, isA<Armed>());
      expect(service.sessionToken?.generation, 2);

      await service.handleNativeExpired();

      expect(service.isActive, isFalse);
      expect(service.sessionToken, isNull);
    },
  );

  test(
    'overlapping confirm and stop mutations cannot race the generation',
    () async {
      var armCount = 0;
      final revision = Completer<Object?>();
      late MethodCall revisionCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'armEmergencySession') {
              armCount++;
              if (armCount == 1) return armedResponse(call);
              revisionCall = call;
              return revision.future;
            }
            if (call.method == 'cancelEmergencySession') {
              return <String, Object?>{
                'type': 'cancelled',
                'token': service.sessionToken!.toMap(),
              };
            }
            return null;
          });
      await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );

      // Exercise the compatibility alias; generation safety is still typed.
      // ignore: deprecated_member_use_from_same_package
      final firstRevision = service.confirmSafe();
      await Future<void>.delayed(Duration.zero);
      final overlappingRevision = await service.confirmSafeSession();
      final overlappingStop = await service.stopSession();
      expect(
        (overlappingRevision as ArmRejected).reasonCode,
        'operationInProgress',
      );
      expect(
        (overlappingStop as SessionCancelUnknown).reasonCode,
        'operationInProgress',
      );

      revision.complete(armedResponse(revisionCall));
      expect(await firstRevision, isA<Armed>());
      expect(service.sessionToken?.generation, 2);
      expect(await service.stopSession(), isA<SessionCancelled>());
    },
  );

  test('initialize clears legacy, corrupt and tokenless projections', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readEmergencySessionByKind') {
            return <String, Object?>{'type': 'absent'};
          }
          return null;
        });
    SharedPreferences.setMockInitialValues(<String, Object>{
      'check_in_active': true,
      'check_in_total_seconds': 30,
      'check_in_end_at': 'legacy',
      'check_in_grace_end_at': 'legacy',
    });
    await service.initialize();
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('check_in_active'), isFalse);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'check_in_state_v2': '{corrupt',
    });
    final corruptService = makeService();
    await corruptService.handleAppResumed();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('check_in_state_v2'), isFalse);
    corruptService.dispose();

    SharedPreferences.setMockInitialValues(<String, Object>{
      'check_in_state_v2': jsonEncode(<String, Object?>{
        'active': true,
        'totalSeconds': 0,
        'token': fixedToken.toMap(),
      }),
    });
    final tokenlessService = makeService();
    await tokenlessService.initialize();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('check_in_state_v2'), isFalse);
    tokenlessService.dispose();
  });

  test(
    'restore projects only a native ARMED session with future deadline',
    () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'check_in_state_v2': jsonEncode(persistedProjection()),
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => present(
              mainDeadline: now.add(const Duration(minutes: 4)),
              finalDeadline: now.add(const Duration(minutes: 5)),
            ),
          );

      await service.initialize();

      expect(service.isActive, isTrue);
      expect(service.isGracePeriod, isFalse);
      expect(service.remainingSeconds, greaterThan(0));
      expect(service.totalSeconds, 300);
    },
  );

  test(
    'missing Dart projection discovers and exposes a native ARMED session',
    () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'readEmergencySessionByKind') {
              return present(
                mainDeadline: now.add(const Duration(minutes: 4)),
                finalDeadline: now.add(const Duration(minutes: 5)),
              );
            }
            return null;
          });

      await service.initialize();

      expect(methods, <String>['readEmergencySessionByKind']);
      expect(service.isActive, isTrue);
      expect(service.sessionToken, fixedToken);
      expect(service.remainingSeconds, greaterThan(0));
    },
  );

  test(
    'unknown native discovery blocks start and revision until reconciliation',
    () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'readEmergencySessionByKind') {
              return <String, Object?>{
                'type': 'unknown',
                'reasonCode': 'nativeReadUnavailable',
              };
            }
            return null;
          });

      await service.initialize();
      expect(service.reconciliationPending, isTrue);
      expect(service.isActive, isFalse);

      final start = await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      final revision = await service.confirmSafeSession();

      expect((start as ArmRejected).reasonCode, 'reconciliationPending');
      expect((revision as ArmRejected).reasonCode, 'reconciliationPending');
      expect(methods, <String>['readEmergencySessionByKind']);
    },
  );

  test(
    'discovered claimed authority remains pending and cannot be re-armed',
    () async {
      final now = DateTime.now();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'readEmergencySessionByKind') {
              return present(
                state: 'claimed',
                mainDeadline: now.add(const Duration(minutes: 4)),
                finalDeadline: now.add(const Duration(minutes: 5)),
              );
            }
            fail('No native mutation is allowed while claim is unresolved');
          });

      await service.initialize();

      expect(service.isActive, isFalse);
      expect(service.sessionToken, fixedToken);
      expect(service.reconciliationPending, isTrue);
      final start = await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      expect((start as ArmRejected).reasonCode, 'reconciliationPending');
    },
  );

  test('discovered terminal authority clears every local projection', () async {
    final now = DateTime.now();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => present(
            state: 'cancelled',
            mainDeadline: now.subtract(const Duration(minutes: 2)),
            finalDeadline: now.subtract(const Duration(minutes: 1)),
          ),
        );

    await service.initialize();

    expect(service.isActive, isFalse);
    expect(service.sessionToken, isNull);
    expect(service.reconciliationPending, isFalse);
  });

  test(
    'unknown native read cannot activate an invalid persisted clock projection',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'check_in_state_v2': jsonEncode(<String, Object?>{
          'active': true,
          'totalSeconds': 300,
          'endAt': 'not-a-deadline',
          'graceEndAt': 'also-not-a-deadline',
          'token': fixedToken.toMap(),
        }),
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => <String, Object?>{
              'type': 'unknown',
              'reasonCode': 'nativeReadUnavailable',
            },
          );

      await service.initialize();

      expect(service.isActive, isFalse);
      expect(service.sessionToken, fixedToken);
      expect(service.reconciliationPending, isTrue);
    },
  );

  test('authoritative wipe stops best-effort foreground ownership', () async {
    service.dispose();
    disposed = true;
    service = makeService(sideEffectsEnabled: true);
    disposed = false;

    expect(await service.clearAfterAuthoritativeNativeWipe(), isTrue);
    expect(service.isActive, isFalse);
    expect(service.sessionToken, isNull);
  });

  test(
    'unknown native read preserves a cancellable local projection',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'check_in_state_v2': jsonEncode(persistedProjection()),
      });
      final never = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'readEmergencySession') return never.future;
            return null;
          });

      await service.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(service.isActive, isTrue);
      expect(service.sessionToken, fixedToken);
      expect(prefs.containsKey('check_in_state_v2'), isTrue);
    },
  );

  test('restore refuses terminal and non-armed native projections', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'check_in_state_v2': jsonEncode(persistedProjection()),
    });
    var state = 'claimed';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => present(
            state: state,
            mainDeadline: now.add(const Duration(minutes: 4)),
            finalDeadline: now.add(const Duration(minutes: 5)),
          ),
        );

    await service.initialize();
    expect(service.isActive, isFalse);
    expect(service.sessionToken, fixedToken);

    state = 'cancelled';
    final terminalService = makeService();
    await terminalService.initialize();
    expect(terminalService.isActive, isFalse);
    expect(terminalService.sessionToken, isNull);
    terminalService.dispose();
  });

  test(
    'native grace reconciliation and unknown dispatch preserve authority',
    () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'check_in_state_v2': jsonEncode(persistedProjection()),
      });
      var dispatchMode = 'unknown';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'readEmergencySession') {
              return present(
                mainDeadline: now.subtract(const Duration(seconds: 5)),
                finalDeadline: now.add(const Duration(seconds: 40)),
              );
            }
            if (call.method == 'dispatchEmergencySession') {
              if (dispatchMode == 'unknown') {
                return dispatch(
                  callOutcome: 'notAttempted',
                  fallbackOutcome: 'notAttempted',
                  terminalState: 'claimed',
                );
              }
              return dispatch(
                callOutcome: 'notAttempted',
                fallbackOutcome: 'notAttempted',
                terminalState: 'cancelled',
              );
            }
            return null;
          });

      await service.initialize();
      expect(service.isGracePeriod, isTrue);
      await service.handleNativeGraceStarted();
      expect(service.isGracePeriod, isTrue);

      await service.handleNativeExpired();
      expect(service.isActive, isTrue);
      dispatchMode = 'cancelled';
      await service.handleNativeExpired();
      expect(service.isActive, isFalse);
    },
  );

  test(
    'expired restore dispatches before clearing the local projection',
    () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'check_in_state_v2': jsonEncode(persistedProjection()),
      });
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'readEmergencySession') {
              return present(
                mainDeadline: now.subtract(const Duration(minutes: 2)),
                finalDeadline: now.subtract(const Duration(minutes: 1)),
              );
            }
            if (call.method == 'dispatchEmergencySession') {
              return dispatch(
                callOutcome: 'failed',
                fallbackOutcome: 'posted',
                terminalState: 'manualActionRequired',
              );
            }
            return null;
          });

      await service.initialize();

      expect(methods, <String>[
        'readEmergencySession',
        'dispatchEmergencySession',
      ]);
      expect(service.isActive, isFalse);
    },
  );

  test(
    'concurrent expiry callbacks produce one Dart dispatch request',
    () async {
      final pendingDispatch = Completer<Object?>();
      var dispatchCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'armEmergencySession') {
              return armedResponse(call);
            }
            if (call.method == 'dispatchEmergencySession') {
              dispatchCalls++;
              return pendingDispatch.future;
            }
            return null;
          });
      await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      final activeToken = service.sessionToken!;

      final first = service.handleNativeExpired();
      await Future<void>.delayed(Duration.zero);
      await service.handleNativeExpired();
      expect(dispatchCalls, 1);
      pendingDispatch.complete(dispatch(token: activeToken));
      await first;
      expect(service.isActive, isFalse);
    },
  );

  test('main ticker enters grace without changing native generation', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'check_in_state_v2': jsonEncode(persistedProjection()),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => present(
            mainDeadline: now.add(const Duration(milliseconds: 1100)),
            finalDeadline: now.add(const Duration(seconds: 30)),
          ),
        );

    await service.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 1250));

    expect(service.isGracePeriod, isTrue);
    expect(service.sessionToken, fixedToken);
  });
}
