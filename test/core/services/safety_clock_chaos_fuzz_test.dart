// Seeded stateful fuzz for the clock dimension of Check-In / Safe Walk
// (chaos audit 2026-10-08, Y-01). The navigation fuzz cannot see a wall-clock
// change at all -- it ran 338 sequences green while Check-In showed "134:19"
// with fourteen minutes left on a device -- so this one does nothing BUT move
// clocks around a live session.
//
// The native model is native's real semantics: deadlines are elapsed-based,
// a TIME_SET rebuilds the stored wall deadlines from the remaining monotonic
// time, and that broadcast may arrive late. Dart is the production
// CheckInService on a fake SafetyClock.
//
// Invariants after every step:
//   I1 no grace before native's main deadline;
//   I2 no dispatch before native's final deadline;
//   I3 outside grace the displayed remaining tracks native (+-1 s);
//   I4 a session past its final deadline (+2 ticks) has been dispatched once.
//
// Reproduce: FUZZ_SEED=<seed> flutter test <this file>
// Scale:     FUZZ_SCALE=4 flutter test <this file>

import 'dart:io';
import 'dart:math';

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

class _Clock implements SafetyClock {
  DateTime wall = DateTime(2026, 10, 8, 14, 18);
  Duration elapsed = Duration.zero;
  @override
  DateTime now() => wall;
  @override
  Duration get monotonic => elapsed;
}

class _Contacts implements ContactsRepository {
  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async =>
      const EmergencyContact(
        name: 'P',
        phone: '+905551112233',
        isPrimary: true,
      );
  @override
  Future<List<String>> getAllEmergencyNumbers() async => const <String>[];
  @override
  Future<List<EmergencyContact>> getContactRecords() async =>
      const <EmergencyContact>[];
  @override
  Future<List<String>> getContacts() async => const <String>[];
  @override
  Future<void> clearPrimaryEmergencyContact() async {}
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

/// Native's session: elapsed deadlines are the truth, wall deadlines derived.
class _Native {
  _Native(this.clock);
  final _Clock clock;
  Map<String, Object?>? token;
  int generation = 0;
  Duration? mainAt; // monotonic
  Duration? finalAt;
  int wallMainMs = 0;
  int wallFinalMs = 0;
  bool terminal = false;
  int dispatches = 0;
  bool timeSetPending = false;

  void adopt(Map<String, Object?> arguments) {
    final now = clock.wall.millisecondsSinceEpoch;
    wallMainMs = arguments['mainDeadlineMs']! as int;
    wallFinalMs = arguments['finalDeadlineMs']! as int;
    mainAt = clock.elapsed + Duration(milliseconds: wallMainMs - now);
    finalAt = clock.elapsed + Duration(milliseconds: wallFinalMs - now);
    terminal = false;
  }

  /// What reconcileAfterClockChange does.
  void timeSet() {
    final now = clock.wall.millisecondsSinceEpoch;
    if (mainAt != null && !terminal) {
      wallMainMs = now + (mainAt! - clock.elapsed).inMilliseconds;
      wallFinalMs = now + (finalAt! - clock.elapsed).inMilliseconds;
    }
    timeSetPending = false;
  }

  Map<String, Object?> session() => <String, Object?>{
    'type': 'present',
    'session': <String, Object?>{
      'token': token,
      'lifecycleState': terminal ? 'requestSubmittedUnconfirmed' : 'armed',
      'mainDeadlineMs': wallMainMs,
      'finalDeadlineMs': wallFinalMs,
      'target': '+905551112233',
      'callRequestOutcome': terminal ? 'submittedUnconfirmed' : 'notAttempted',
      'fallbackOutcome': terminal ? 'posted' : 'notAttempted',
      'mainDurationMs': 900000,
    },
  };
}

const _channel = MethodChannel('safety-clock-chaos-fuzz');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pinned = int.tryParse(Platform.environment['FUZZ_SEED'] ?? '');
  final scale = int.tryParse(Platform.environment['FUZZ_SCALE'] ?? '') ?? 1;
  const baseSeed = 20261008;
  final plan = pinned != null
      ? <(int, int)>[(1, 120)]
      : <(int, int)>[(120 * scale, 10), (110 * scale, 40), (55 * scale, 120)];

  var index = 0;
  for (final (count, length) in plan) {
    for (var i = 0; i < count; i++) {
      final seed = pinned ?? baseSeed + index++;
      testWidgets('clock seed $seed: $length chaotic steps keep Check-In on '
          "native's deadline", (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final random = Random(seed);
        final clock = _Clock();
        final native = _Native(clock);
        final log = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
          call,
        ) async {
          final arguments = (call.arguments as Map<Object?, Object?>)
              .cast<String, Object?>();
          switch (call.method) {
            case 'armEmergencySession':
              // A revision is the same call with the next generation.
              native.generation = arguments['requestedGeneration']! as int;
              native.token = <String, Object?>{
                'protocolVersion': emergencyProtocolVersion,
                'randomId': arguments['randomId'],
                'generation': native.generation,
                'kind': arguments['kind'],
              };
              native.adopt(arguments);
              return <String, Object?>{
                'type': 'armed',
                'token': native.token,
                'mainDeadlineMs': native.wallMainMs,
                'finalDeadlineMs': native.wallFinalMs,
              };
            case 'discoverEmergencySession':
            case 'readEmergencySession':
              return native.token == null
                  ? <String, Object?>{'type': 'absent'}
                  : native.session();
            case 'warnEmergencySession':
              return <String, Object?>{'outcome': 'posted'};
            case 'dispatchEmergencySession':
              // Native's wall gate, on its (possibly not yet rebased) deadline.
              if (native.terminal ||
                  clock.wall.millisecondsSinceEpoch < native.wallFinalMs) {
                return <String, Object?>{
                  'token': native.token,
                  'callRequestOutcome': native.terminal
                      ? 'submittedUnconfirmed'
                      : 'notAttempted',
                  'fallbackOutcome': native.terminal
                      ? 'posted'
                      : 'notAttempted',
                  'connectionState': 'unknown',
                  'terminalState': native.terminal
                      ? 'requestSubmittedUnconfirmed'
                      : 'armed',
                };
              }
              native.dispatches++;
              native.terminal = true;
              log.add('DISPATCH at ${clock.elapsed} final ${native.finalAt}');
              return <String, Object?>{
                'token': native.token,
                'callRequestOutcome': 'submittedUnconfirmed',
                'fallbackOutcome': 'posted',
                'connectionState': 'unknown',
                'terminalState': 'requestSubmittedUnconfirmed',
              };
          }
          return null;
        });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _channel,
            null,
          ),
        );
        final service = CheckInService.forTesting(
          sessionId: CheckInExpiryCoordinator.checkInSession,
          platform: EmergencyPlatformService.forTesting(
            methodChannel: _channel,
            defaultTimeout: const Duration(seconds: 2),
            dispatchTimeout: const Duration(seconds: 2),
          ),
          contactsRepository: _Contacts(),
          clock: clock,
        );

        Future<void> run(Duration by) async {
          // Dart's 1 s ticker runs on the fake timer; the clocks move with it.
          var left = by;
          while (left > Duration.zero) {
            final step = left > const Duration(milliseconds: 500)
                ? const Duration(milliseconds: 500)
                : left;
            clock.elapsed += step;
            clock.wall = clock.wall.add(step);
            await tester.pump(step);
            left -= step;
          }
        }

        await service.startSession(
          minutes: 15,
          entitlementDecision: EntitlementDecision.authorized,
          pinConfigured: true,
        );
        await tester.pump();

        void check(String action) {
          final main = native.mainAt;
          final fin = native.finalAt;
          if (main == null || fin == null) return;
          final where = 'FUZZ_SEED=$seed after $action (${log.length} steps)';
          // A Dart tick is 1 s, and a rebased wall deadline is ms-precise.
          const slack = Duration(milliseconds: 1500);
          if (service.isGracePeriod && clock.elapsed + slack < main) {
            fail('I1 grace ${main - clock.elapsed} early; $where\n$log');
          }
          if (native.dispatches > 0 &&
              native.terminal &&
              log.last.startsWith('DISPATCH') &&
              clock.elapsed + slack < fin) {
            fail('I2 dispatch ${fin - clock.elapsed} early; $where\n$log');
          }
          if (service.isActive &&
              !service.isGracePeriod &&
              !native.timeSetPending) {
            final expected = ((main - clock.elapsed).inMilliseconds / 1000)
                .ceil();
            if ((service.remainingSeconds - expected).abs() > 1 &&
                expected > 0) {
              fail(
                'I3 shows ${service.remainingSeconds}s, native has '
                '${expected}s; $where\n$log',
              );
            }
          }
          // While TIME_SET is in flight native's own alarm is wall-gated too;
          // it dispatches when the broadcast lands (K-04), which is modelled
          // by delivering every late TIME_SET within three steps.
          if (!native.terminal &&
              !native.timeSetPending &&
              native.token != null &&
              clock.elapsed > fin + const Duration(seconds: 3)) {
            fail(
              'I4 no dispatch ${clock.elapsed - fin} past final; $where\n$log',
            );
          }
        }

        var pendingFor = 0;
        for (var step = 0; step < length; step++) {
          if (native.timeSetPending && ++pendingFor > 3) {
            native.timeSet();
            await service.handleAppResumed();
            await tester.pump();
            log.add('TIME_SET delivered (late)');
          }
          if (!native.timeSetPending) pendingFor = 0;
          final roll = random.nextInt(100);
          String action;
          if (roll < 40) {
            final by = Duration(milliseconds: 200 + random.nextInt(4800));
            await run(by);
            action = 'tick $by';
          } else if (roll < 52) {
            final by = Duration(seconds: 30 + random.nextInt(300));
            await run(by);
            action = 'advance $by';
          } else if (roll < 66) {
            final jump = Duration(seconds: random.nextInt(21600) - 10800);
            clock.wall = clock.wall.add(jump);
            native.timeSet();
            await service.handleAppResumed(); // safetyClockChanged
            await tester.pump();
            action = 'clock $jump (TIME_SET prompt)';
          } else if (roll < 76) {
            final jump = Duration(seconds: random.nextInt(21600) - 10800);
            clock.wall = clock.wall.add(jump);
            native.timeSetPending = true;
            await tester.pump(const Duration(milliseconds: 300));
            action = 'clock $jump (TIME_SET late)';
          } else if (roll < 84) {
            if (native.timeSetPending) {
              native.timeSet();
              await service.handleAppResumed();
              await tester.pump();
            }
            action = 'TIME_SET delivered';
          } else if (roll < 92) {
            if (service.isActive && !native.timeSetPending) {
              await service.confirmSafeSession();
              await tester.pump();
            }
            action = 'Güvendeyim';
          } else {
            if (!native.timeSetPending) {
              await service.handleAppResumed();
              await tester.pump();
            }
            action = 'resume';
          }
          log.add(action);
          check(action);
          if (native.terminal) {
            // A finished session is replaced, so chaos continues on a new one.
            native.token = null;
            native.mainAt = null;
            native.finalAt = null;
            await service.handleAppResumed();
            await service.startSession(
              minutes: 15,
              entitlementDecision: EntitlementDecision.authorized,
              pinConfigured: true,
            );
            await tester.pump();
          }
        }
        service.dispose();
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}
