// The Dart projection of a Check-In / Safe Walk session must not ask native
// for a deadline-bound action BEFORE that deadline.
//
// The native coordinator is the authority and it is strict
// (EmergencySessionCoordinator.warn / claimAndDispatch):
//   * warn(grace) is "stale" while wall clock < mainDeadline
//   * claimAndDispatch is notAttempted(ARMED) while wall clock < finalDeadline
//
// The Dart tickers used to compare `Duration.inSeconds`, which TRUNCATES: with
// 0.6 s left it already reads 0. A 1 Hz ticker therefore reached each boundary
// up to a second early, native refused it, and the refusal surfaced as a false
// "warning could not be shown" SnackBar and as an `unknown` dispatch that left
// the Dart side without a result screen.
//
// The fake below enforces the same rules as the Kotlin coordinator and records
// WHEN each call arrived, so the assertions are about timing, not wiring.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Contacts implements ContactsRepository {
  EmergencyContact? primary = const EmergencyContact(
    name: 'Birincil',
    phone: '+90 555 111 22 33',
    isPrimary: true,
  );

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
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {}

  @override
  Future<void> saveContacts(List<String> numbers) async {}

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) async {}

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('check_in_native_deadline_alignment_test');
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const token = SessionToken(
    protocolVersion: emergencyProtocolVersion,
    randomId: 'abcdef0123456789abcdef0123456789',
    generation: 1,
    kind: EmergencySessionKind.checkIn,
  );

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(notificationsChannel, null);
  });

  test(
    'grace warning and final dispatch never reach native before their deadline',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final origin = DateTime.now();
      // Sub-second offsets on purpose: they are exactly what a 1 Hz ticker
      // that truncates to whole seconds gets wrong.
      final mainDeadline = origin.add(const Duration(milliseconds: 1400));
      final finalDeadline = origin.add(const Duration(milliseconds: 2700));

      var claimed = false;
      final earlyWarns = <Duration>[];
      final earlyDispatches = <Duration>[];
      final onTimeWarns = <Duration>[];
      final onTimeDispatches = <Duration>[];

      Map<String, Object?> session() => <String, Object?>{
        'type': 'present',
        'session': <String, Object?>{
          'token': token.toMap(),
          'lifecycleState': claimed ? 'requestSubmittedUnconfirmed' : 'armed',
          'mainDeadlineMs': mainDeadline.millisecondsSinceEpoch,
          'finalDeadlineMs': finalDeadline.millisecondsSinceEpoch,
          'target': '+905551112233',
          'callRequestOutcome': claimed ? 'submittedUnconfirmed' : 'notAttempted',
          'fallbackOutcome': claimed ? 'posted' : 'notAttempted',
        },
      };

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        notificationsChannel,
        (call) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        final now = DateTime.now();
        switch (call.method) {
          case 'discoverEmergencySession':
          case 'readEmergencySession':
            return session();
          case 'warnEmergencySession':
            if (now.isBefore(mainDeadline)) {
              earlyWarns.add(mainDeadline.difference(now));
              return <String, Object?>{'outcome': 'stale'};
            }
            onTimeWarns.add(now.difference(mainDeadline));
            return <String, Object?>{'outcome': 'posted'};
          case 'dispatchEmergencySession':
            if (now.isBefore(finalDeadline)) {
              earlyDispatches.add(finalDeadline.difference(now));
              return <String, Object?>{
                'token': token.toMap(),
                'callRequestOutcome': 'notAttempted',
                'fallbackOutcome': 'notAttempted',
                'connectionState': 'unknown',
                'terminalState': 'armed',
              };
            }
            onTimeDispatches.add(now.difference(finalDeadline));
            claimed = true;
            return <String, Object?>{
              'token': token.toMap(),
              'callRequestOutcome': 'submittedUnconfirmed',
              'fallbackOutcome': 'posted',
              'connectionState': 'unknown',
              'terminalState': 'requestSubmittedUnconfirmed',
            };
          default:
            return null;
        }
      });

      final service = CheckInService.forTesting(
        sessionId: CheckInExpiryCoordinator.checkInSession,
        platform: EmergencyPlatformService.forTesting(
          methodChannel: channel,
          defaultTimeout: const Duration(milliseconds: 200),
          dispatchTimeout: const Duration(milliseconds: 200),
        ),
        contactsRepository: _Contacts(),
        sideEffectsEnabled: true,
      );
      addTearDown(service.dispose);

      // Adopt the native session exactly as a resume or restart does.
      await service.initialize();
      expect(service.isActive, isTrue, reason: 'harness must adopt the session');

      await Future<void>.delayed(const Duration(milliseconds: 4200));

      expect(
        earlyWarns,
        isEmpty,
        reason: 'grace warning reached native before mainDeadline '
            '(early by $earlyWarns) and was refused as stale',
      );
      expect(
        earlyDispatches,
        isEmpty,
        reason: 'final dispatch reached native before finalDeadline '
            '(early by $earlyDispatches) and was refused as notAttempted',
      );
      expect(onTimeWarns, isNotEmpty, reason: 'grace warning must still run');
      expect(onTimeDispatches, isNotEmpty, reason: 'dispatch must still run');
      expect(
        service.graceAlertOutcome?.reachability,
        DispatchReachability.reached,
        reason: 'a warning native actually posted must not be reported to '
            'the user as undelivered',
      );
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'Safe Walk does not report the 120 s pre-warning threshold before native',
    () async {
      // SafeWalkScreen fires postPreWarning when remainingSeconds <= 120;
      // native accepts it only when wall clock >= mainDeadline - 120 s.
      // With 120.6 s left the projection must therefore still read 121.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const safeWalkToken = SessionToken(
        protocolVersion: emergencyProtocolVersion,
        randomId: 'fedcba9876543210fedcba9876543210',
        generation: 1,
        kind: EmergencySessionKind.safeWalk,
      );
      final mainDeadline = DateTime.now().add(
        const Duration(seconds: 120, milliseconds: 600),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'discoverEmergencySession') {
              return <String, Object?>{
                'type': 'present',
                'session': <String, Object?>{
                  'token': safeWalkToken.toMap(),
                  'lifecycleState': 'armed',
                  'mainDeadlineMs': mainDeadline.millisecondsSinceEpoch,
                  'finalDeadlineMs': mainDeadline
                      .add(const Duration(seconds: 60))
                      .millisecondsSinceEpoch,
                  'target': '+905551112233',
                  'callRequestOutcome': 'notAttempted',
                  'fallbackOutcome': 'notAttempted',
                },
              };
            }
            return null;
          });
      final service = CheckInService.forTesting(
        sessionId: CheckInExpiryCoordinator.safeWalkSession,
        platform: EmergencyPlatformService.forTesting(
          methodChannel: channel,
          defaultTimeout: const Duration(milliseconds: 200),
        ),
        contactsRepository: _Contacts(),
      );
      addTearDown(service.dispose);

      await service.initialize();

      expect(service.isActive, isTrue);
      expect(
        service.remainingSeconds,
        121,
        reason:
            '120.6 s left truncated to 120 made the screen post the '
            'pre-warning while native still answered "stale"',
      );
    },
  );
}
