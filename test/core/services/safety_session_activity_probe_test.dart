import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/safety_session_activity_probe.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No native panic session — the default for every pre-existing case here.
Future<SessionSnapshot> _noPanicSession() async =>
    const SessionSnapshot(status: SessionReadStatus.absent);

Future<SessionSnapshot> Function() _panicIn(
  EmergencySessionLifecycle lifecycleState, {
  SessionReadStatus status = SessionReadStatus.present,
}) => () async => SessionSnapshot(status: status, lifecycleState: lifecycleState);

Future<SharedPreferences> _loaderWith(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports no session when neither projection is persisted', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActiveSession(), isFalse);
  });

  test('detects an active check-in projection', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () => _loaderWith(<String, Object>{
        'check_in_state_v2': '{"active":true,"totalSeconds":600}',
      }),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  test('detects an active safe-walk projection', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () => _loaderWith(<String, Object>{
        'safe_walk_state_v2': '{"active":true,"totalSeconds":900}',
      }),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  test('an explicitly inactive projection does not block reset', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () => _loaderWith(<String, Object>{
        'check_in_state_v2': '{"active":false}',
      }),
    );

    expect(await probe.hasActiveSession(), isFalse);
  });

  test('an unparsable projection fails closed', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () => _loaderWith(<String, Object>{
        'safe_walk_state_v2': 'not-json',
      }),
    );

    expect(
      await probe.hasActiveSession(),
      isTrue,
      reason:
          'A corrupt blob is not proof that nothing is armed; refusing a '
          'destructive pre-auth reset is the recoverable outcome.',
    );
  });

  test('a storage failure fails closed', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () =>
          Future<SharedPreferences>.error(Exception('storage unavailable')),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  test('probe covers every session key CheckInService can write', () {
    expect(
      SafetySessionActivityProbe.sessionStateKeys,
      containsAll(<String>['check_in_state_v2', 'safe_walk_state_v2']),
    );
  });

  // ---------------------------------------------------------------------
  // A live PANIC countdown has no SharedPreferences projection. Before this
  // was covered, the probe answered "no session" while a countdown was ARMED,
  // and both pre-auth reset paths (forgot-PIN, bootstrap recovery) would wipe
  // it -- `EmergencySessionCoordinator.wipe()` refuses only CLAIMED and
  // CANCELS PREPARING/ARMED. That is a duress-model failure, not a nicety.
  // ---------------------------------------------------------------------

  test('an ARMED panic countdown blocks reset even with no projection', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _panicIn(EmergencySessionLifecycle.armed),
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActivePanicSession(), isTrue);
    expect(
      await probe.hasActiveSession(),
      isTrue,
      reason: 'an attacker without the PIN must not be able to silence a '
          'running SOS through a local reset',
    );
  });

  test('a PREPARING panic session also blocks reset', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _panicIn(EmergencySessionLifecycle.preparing),
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  test('a CLAIMED panic session blocks reset', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _panicIn(EmergencySessionLifecycle.claimed),
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  // The negative control: without these, "always true" would pass every case
  // above while permanently bricking the user's own recovery path.
  test('a finished panic session does not block reset', () async {
    for (final finished in <EmergencySessionLifecycle>[
      EmergencySessionLifecycle.cancelled,
      EmergencySessionLifecycle.requestSubmittedUnconfirmed,
      EmergencySessionLifecycle.manualActionRequired,
      EmergencySessionLifecycle.requestFailed,
      EmergencySessionLifecycle.absent,
    ]) {
      final probe = SafetySessionActivityProbe(
        panicDiscovery: _panicIn(finished),
        preferencesLoader: () => _loaderWith(<String, Object>{}),
      );

      expect(
        await probe.hasActiveSession(),
        isFalse,
        reason: '$finished is not a running session',
      );
    }
  });

  test('an absent panic slot does not block reset', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: _noPanicSession,
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActiveSession(), isFalse);
  });

  test('an unreadable panic slot fails closed', () async {
    for (final status in <SessionReadStatus>[
      SessionReadStatus.unknown,
      SessionReadStatus.corrupted,
    ]) {
      final probe = SafetySessionActivityProbe(
        panicDiscovery: _panicIn(
          EmergencySessionLifecycle.unknown,
          status: status,
        ),
        preferencesLoader: () => _loaderWith(<String, Object>{}),
      );

      expect(
        await probe.hasActiveSession(),
        isTrue,
        reason: '$status is not proof that nothing is armed',
      );
    }
  });

  test('a throwing panic discovery fails closed', () async {
    final probe = SafetySessionActivityProbe(
      panicDiscovery: () async => throw const FormatException('native down'),
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });
}
