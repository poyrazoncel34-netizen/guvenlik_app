// Y-01 (chaos audit 2026-10-08): with Check-In on screen, a +1 h wall-clock
// change made the Dart projection show "Süre doldu! … EK SÜRE 00:00" while the
// native session (rebased by TIME_SET) still had 879 s to run; a -2 h change
// showed "134:19" with 857 s left (API 35 emulator). Native alarms are
// ELAPSED_REALTIME, so only the Dart projection was wrong -- and wrong in the
// direction that makes a user miss the real deadline.


import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClock implements SafetyClock {
  DateTime wall = DateTime(2026, 10, 8, 14, 18);
  Duration elapsed = Duration.zero;

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => elapsed;

  void advance(Duration by) {
    wall = wall.add(by);
    elapsed += by;
  }
}

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

  const channel = MethodChannel('check_in_wall_clock_change_test');
  late _FakeClock clock;
  late List<String> calls;
  late CheckInService service;
  // What native holds: its wall deadlines, rebased on TIME_SET.
  late int nativeMainMs;
  late int nativeFinalMs;
  Map<String, Object?>? token;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    clock = _FakeClock();
    calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          final arguments = (call.arguments as Map<Object?, Object?>)
              .cast<String, Object?>();
          switch (call.method) {
            case 'armEmergencySession':
              nativeMainMs = arguments['mainDeadlineMs']! as int;
              nativeFinalMs = arguments['finalDeadlineMs']! as int;
              token = <String, Object?>{
                'protocolVersion': emergencyProtocolVersion,
                'randomId': arguments['randomId'],
                'generation': 1,
                'kind': arguments['kind'],
              };
              return <String, Object?>{
                'type': 'armed',
                'token': token,
                'mainDeadlineMs': nativeMainMs,
                'finalDeadlineMs': nativeFinalMs,
              };
            case 'discoverEmergencySession':
            case 'readEmergencySession':
              return <String, Object?>{
                'type': 'present',
                'session': <String, Object?>{
                  'token': token,
                  'lifecycleState': 'armed',
                  'mainDeadlineMs': nativeMainMs,
                  'finalDeadlineMs': nativeFinalMs,
                  'target': '+905551112233',
                  'callRequestOutcome': 'notAttempted',
                  'fallbackOutcome': 'notAttempted',
                  'mainDurationMs': 900000,
                },
              };
            case 'warnEmergencySession':
              return <String, Object?>{'outcome': 'posted'};
            case 'dispatchEmergencySession':
              return <String, Object?>{
                'token': token,
                'callRequestOutcome': 'submittedUnconfirmed',
                'fallbackOutcome': 'posted',
                'connectionState': 'unknown',
                'terminalState': 'requestSubmittedUnconfirmed',
              };
          }
          return null;
        });
    service = CheckInService.forTesting(
      sessionId: CheckInExpiryCoordinator.checkInSession,
      platform: EmergencyPlatformService.forTesting(
        methodChannel: channel,
        defaultTimeout: const Duration(milliseconds: 200),
        dispatchTimeout: const Duration(milliseconds: 200),
      ),
      contactsRepository: _FakeContactsRepository(
        const EmergencyContact(
          name: 'Birincil',
          phone: '+905551112233',
          isPrimary: true,
        ),
      ),
      clock: clock,
    );
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> start() async {
    final result = await service.startSession(
      minutes: 15,
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
    );
    expect(result, isA<Armed>());
    expect(service.remainingSeconds, 900);
  }

  /// One real ticker period.
  Future<void> tick() =>
      Future<void>.delayed(const Duration(milliseconds: 1100));

  /// What native's TIME_SET reconcile does: same remaining time, new wall.
  void nativeRebase(Duration jump) {
    nativeMainMs += jump.inMilliseconds;
    nativeFinalMs += jump.inMilliseconds;
  }

  for (final jump in <Duration>[
    const Duration(hours: 1),
    const Duration(hours: -2),
  ]) {
    final label = jump.isNegative ? 'backward' : 'forward';
    test('a $label wall-clock change before native rebases neither expires '
        'nor stretches the session', () async {
      await start();
      clock.advance(const Duration(seconds: 1));
      clock.wall = clock.wall.add(jump);
      await tick();

      expect(service.isGracePeriod, isFalse);
      expect(service.remainingSeconds, 899);
      expect(calls, isNot(contains('warnEmergencySession')));
      expect(calls, isNot(contains('dispatchEmergencySession')));
    });

    test('after a $label change the rebased native deadline is adopted '
        'without moving the remaining time', () async {
      await start();
      clock.advance(const Duration(seconds: 1));
      clock.wall = clock.wall.add(jump);
      nativeRebase(jump);
      // safetyClockChanged -> the host re-reads both controllers.
      await service.handleAppResumed();
      await tick();

      expect(service.isGracePeriod, isFalse);
      expect(service.remainingSeconds, 899);
      expect(calls, isNot(contains('dispatchEmergencySession')));
    });
  }

  test('without a clock change the grace window and the single dispatch '
      'still follow the monotonic deadline', () async {
    await start();
    clock.advance(const Duration(seconds: 900));
    await tick();
    expect(service.isGracePeriod, isTrue);
    expect(service.remainingSeconds, 60);
    expect(calls, isNot(contains('dispatchEmergencySession')));

    clock.advance(const Duration(seconds: 60));
    await tick();
    await tick();
    expect(calls.where((m) => m == 'dispatchEmergencySession').length, 1);
  });
}
