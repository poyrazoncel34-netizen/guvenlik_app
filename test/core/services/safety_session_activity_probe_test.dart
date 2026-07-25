import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/safety_session_activity_probe.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _loaderWith(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports no session when neither projection is persisted', () async {
    final probe = SafetySessionActivityProbe(
      preferencesLoader: () => _loaderWith(<String, Object>{}),
    );

    expect(await probe.hasActiveSession(), isFalse);
  });

  test('detects an active check-in projection', () async {
    final probe = SafetySessionActivityProbe(
      preferencesLoader: () => _loaderWith(<String, Object>{
        'check_in_state_v2': '{"active":true,"totalSeconds":600}',
      }),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  test('detects an active safe-walk projection', () async {
    final probe = SafetySessionActivityProbe(
      preferencesLoader: () => _loaderWith(<String, Object>{
        'safe_walk_state_v2': '{"active":true,"totalSeconds":900}',
      }),
    );

    expect(await probe.hasActiveSession(), isTrue);
  });

  test('an explicitly inactive projection does not block reset', () async {
    final probe = SafetySessionActivityProbe(
      preferencesLoader: () => _loaderWith(<String, Object>{
        'check_in_state_v2': '{"active":false}',
      }),
    );

    expect(await probe.hasActiveSession(), isFalse);
  });

  test('an unparsable projection fails closed', () async {
    final probe = SafetySessionActivityProbe(
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
}
