import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeContactsRepository implements ContactsRepository {
  _FakeContactsRepository(this.primary);

  EmergencyContact? primary;

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;

  @override
  Future<List<String>> getAllEmergencyNumbers() async {
    final current = primary;
    return current == null ? const <String>[] : <String>[current.phone];
  }

  @override
  Future<void> clearPrimaryEmergencyContact() async => primary = null;

  @override
  Future<List<EmergencyContact>> getContactRecords() async {
    final current = primary;
    return current == null
        ? const <EmergencyContact>[]
        : <EmergencyContact>[current];
  }

  @override
  Future<List<String>> getContacts() => getAllEmergencyNumbers();

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

  const channel = MethodChannel('check_in_typed_session_test');
  late _FakeContactsRepository contacts;
  late EmergencyPlatformService platform;
  late CheckInService service;
  late bool serviceDisposed;

  Map<String, Object?> armedResponse(
    MethodCall call, {
    int generation = 1,
    int? mainDeadlineMs,
    int? finalDeadlineMs,
  }) {
    final arguments = call.arguments as Map<Object?, Object?>;
    return <String, Object?>{
      'type': 'armed',
      'token': <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'randomId': arguments['randomId'],
        'generation': generation,
        'kind': arguments['kind'],
      },
      'mainDeadlineMs': mainDeadlineMs ?? arguments['mainDeadlineMs'],
      'finalDeadlineMs': finalDeadlineMs ?? arguments['finalDeadlineMs'],
    };
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    contacts = _FakeContactsRepository(
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
    service = CheckInService.forTesting(
      sessionId: CheckInExpiryCoordinator.checkInSession,
      platform: platform,
      contactsRepository: contacts,
    );
    serviceDisposed = false;
  });

  tearDown(() {
    if (!serviceDisposed) service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final kind in [EmergencySessionKind.checkIn, EmergencySessionKind.safeWalk]) {
    for (final blob in ['missing', 'corrupt', 'stale']) {
      test('${kind.name} discovers native session with $blob projection', () async {
        final token = SessionToken(protocolVersion: 1, randomId: 'native-session', generation: 2, kind: kind);
        final key = kind == EmergencySessionKind.safeWalk ? 'safe_walk_state_v2' : 'check_in_state_v2';
        final prefs = await SharedPreferences.getInstance();
        if (blob != 'missing') await prefs.setString(key, blob == 'corrupt' ? '{broken' : '{"totalSeconds":300,"token":{"protocolVersion":1,"randomId":"native-session","generation":1,"kind":"${kind.wireName}"}}');
        service.dispose();
        service = CheckInService.forTesting(sessionId: kind == EmergencySessionKind.safeWalk ? CheckInExpiryCoordinator.safeWalkSession : CheckInExpiryCoordinator.checkInSession, platform: platform, contactsRepository: contacts);
        final methods = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'cancelEmergencySession') {
            expect((call.arguments as Map)['token'], token.toMap());
            return {'type':'cancelled', 'token':token.toMap()};
          }
          return {'type':'present', 'session': {'token':token.toMap(), 'lifecycleState':'armed', 'mainDeadlineMs':DateTime.now().add(const Duration(minutes:5)).millisecondsSinceEpoch, 'finalDeadlineMs':DateTime.now().add(const Duration(minutes:6)).millisecondsSinceEpoch, 'target':'+905551112233', 'callRequestOutcome':'notAttempted', 'fallbackOutcome':'notAttempted'}};
        });
        await service.initialize();
        expect(service.sessionToken, token);
        expect(service.isActive, isTrue);
        expect((await service.stopSession())!.isConfirmedCancelled, isTrue);
        expect(methods, isNot(contains('armEmergencySession')));
        expect(methods, isNot(contains('dispatchEmergencySession')));
      });
    }
  }

  for (final kind in [EmergencySessionKind.checkIn, EmergencySessionKind.safeWalk]) {
    test('${kind.name} lost arm response survives restart without rearming', () async {
      Map<String, Object?>? accepted;
      var armCount = 0;
      var readable = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'armEmergencySession') {
          armCount++;
          accepted = armedResponse(call);
          throw PlatformException(code: 'lost_response');
        }
        if (!readable) return {'type': 'unknown'};
        if (call.method == 'cancelEmergencySession') {
          expect((call.arguments as Map)['token'], accepted!['token']);
          return {'type': 'cancelled', 'token': accepted!['token']};
        }
        return {'type': 'present', 'session': {
          'token': accepted!['token'], 'lifecycleState': 'armed',
          'mainDeadlineMs': accepted!['mainDeadlineMs'],
          'finalDeadlineMs': accepted!['finalDeadlineMs'],
          'target': '+905551112233', 'callRequestOutcome': 'notAttempted',
          'fallbackOutcome': 'notAttempted',
        }};
      });
      CheckInService create() => CheckInService.forTesting(
        sessionId: kind == EmergencySessionKind.safeWalk
            ? CheckInExpiryCoordinator.safeWalkSession : CheckInExpiryCoordinator.checkInSession,
        platform: platform, contactsRepository: contacts);
      service.dispose();
      service = create();
      final result = await service.startSession(minutes: 5,
          entitlementDecision: EntitlementDecision.authorized, pinConfigured: true);
      expect(result, isA<ArmUnknown>());
      final uncertain = service.sessionToken;
      expect(uncertain, isNotNull);
      await service.handleAppResumed();
      expect(service.sessionToken, uncertain);
      service.dispose();
      contacts.primary = const EmergencyContact(name: 'Changed', phone: '+905559999999', isPrimary: true);
      readable = true;
      service = create();
      await service.initialize();
      expect(service.sessionToken, uncertain);
      expect(service.isActive, isTrue);
      expect((await service.stopSession())!.isConfirmedCancelled, isTrue);
      expect(armCount, 1);
    });
  }

  test('restore timeout preserves token and persisted projection', () async {
    var unknown = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'armEmergencySession') return armedResponse(call);
      if (unknown) return {'type':'unknown'};
      return null;
    });
    await service.startSession(minutes:5, entitlementDecision:EntitlementDecision.authorized, pinConfigured:true);
    final token = service.sessionToken;
    final prefs = await SharedPreferences.getInstance();
    final blob = prefs.getString('check_in_state_v2');
    unknown = true;
    await service.handleAppResumed();
    expect(service.sessionToken, token);
    expect(prefs.getString('check_in_state_v2'), blob);
  });

  test('false arm ack preserves uncertain token without activating projection', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => <String, Object?>{'scheduled': true},
        );

    final result = await service.startSession(
      minutes: 5,
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
    );

    expect(result, isA<ArmUnknown>());
    expect(service.isActive, isFalse);
    expect(service.sessionToken, isNotNull);
    expect(service.nativeScheduleDegraded, isTrue);
  });

  test(
    'overlapping mutations are rejected instead of racing projections',
    () async {
      final pending = Completer<Object?>();
      late MethodCall armCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            armCall = call;
            return pending.future;
          });

      final first = service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      await Future<void>.delayed(Duration.zero);
      final overlapping = await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );

      expect(overlapping, isA<ArmRejected>());
      expect((overlapping as ArmRejected).reasonCode, 'operationInProgress');
      pending.complete(armedResponse(armCall));
      expect(await first, isA<Armed>());
    },
  );

  test(
    'dispose is lifecycle cleanup and never sends native cancellation',
    () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            return armedResponse(call);
          });

      final result = await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      expect(result, isA<Armed>());

      service.dispose();
      serviceDisposed = true;
      await Future<void>.delayed(Duration.zero);

      expect(methods, <String>['armEmergencySession']);
    },
  );

  test(
    'cancel timeout with armed snapshot keeps local session active',
    () async {
      final never = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'armEmergencySession') {
              return armedResponse(call);
            }
            if (call.method == 'cancelEmergencySession') return never.future;
            if (call.method == 'readEmergencySession') {
              final token = service.sessionToken!;
              return <String, Object?>{
                'type': 'present',
                'session': <String, Object?>{
                  'token': token.toMap(),
                  'lifecycleState': 'armed',
                  'mainDeadlineMs': service.endAt!.millisecondsSinceEpoch,
                  'finalDeadlineMs': service.endAt!
                      .add(const Duration(minutes: 1))
                      .millisecondsSinceEpoch,
                  'target': '+905551112233',
                  'callRequestOutcome': 'notAttempted',
                  'fallbackOutcome': 'notAttempted',
                },
              };
            }
            return null;
          });
      await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );

      final result = await service.stopSession();

      expect(result, isA<SessionCancelUnknown>());
      expect(service.isActive, isTrue);
      expect(service.sessionToken, isNotNull);
    },
  );

  test('non-monotonic revision cannot replace current generation', () async {
    var armCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'armEmergencySession') {
            armCount++;
            return armedResponse(call, generation: 1);
          }
          return null;
        });
    await service.startSession(
      minutes: 5,
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
    );
    final originalToken = service.sessionToken;
    final originalDeadline = service.endAt;

    final result = await service.confirmSafeSession();

    expect(armCount, 2);
    expect(result, isA<ArmUnknown>());
    expect(service.sessionToken, originalToken);
    expect(service.endAt, originalDeadline);
  });

  test(
    'target snapshot survives contact mutation and dispatch precedes local work',
    () async {
      final calls = <MethodCall>[];
      var generation = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'armEmergencySession') {
              generation++;
              return armedResponse(call, generation: generation);
            }
            if (call.method == 'dispatchEmergencySession') {
              return <String, Object?>{
                'token': service.sessionToken!.toMap(),
                'callRequestOutcome': 'submittedUnconfirmed',
                'fallbackOutcome': 'posted',
                'connectionState': 'unknown',
                'terminalState': 'requestSubmittedUnconfirmed',
              };
            }
            return null;
          });
      await service.startSession(
        minutes: 5,
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );
      contacts.primary = const EmergencyContact(
        name: 'Değişen',
        phone: '+90 555 999 88 77',
        isPrimary: true,
      );

      final revision = await service.confirmSafeSession();
      expect(revision, isA<Armed>());
      await service.handleNativeExpired();

      final arms = calls
          .where((call) => call.method == 'armEmergencySession')
          .toList();
      expect(arms, hasLength(2));
      expect(
        (arms[0].arguments as Map<Object?, Object?>)['target'],
        '+905551112233',
      );
      expect(
        (arms[1].arguments as Map<Object?, Object?>)['target'],
        '+905551112233',
      );
      expect(calls.last.method, 'dispatchEmergencySession');
    },
  );
}
