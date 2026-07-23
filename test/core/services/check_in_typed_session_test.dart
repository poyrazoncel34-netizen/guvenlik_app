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
      contactsConsentAllowed: () => true,
    );
    serviceDisposed = false;
  });

  tearDown(() {
    if (!serviceDisposed) service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('false arm ack never activates the Dart projection', () async {
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
    expect(service.sessionToken, isNull);
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
