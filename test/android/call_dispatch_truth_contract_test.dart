import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const kotlinBase =
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency';

  test('Telecom request is recorded as submitted but never connected', () {
    final runtime = File(
      '$kotlinBase/AndroidEmergencySessionRuntime.kt',
    ).readAsStringSync();
    final models = File(
      '$kotlinBase/EmergencySessionModels.kt',
    ).readAsStringSync();

    expect(runtime, contains('telecom.placeCall('));
    expect(runtime, contains('CallRequestOutcome.SUBMITTED_UNCONFIRMED'));
    expect(models, contains('ConnectionState.UNKNOWN'));
    expect(runtime, isNot(contains('connected')));
  });

  test('MethodChannel dispatch uses the typed native coordinator', () {
    final handler = File(
      '$kotlinBase/EmergencyPlatformHandler.kt',
    ).readAsStringSync();

    expect(handler, contains('"dispatchEmergencySession"'));
    expect(handler, contains('.claimAndDispatch(token)'));
    expect(handler, contains('"executeEmergencyNative",'));
    expect(handler, contains('-> result.notImplemented()'));
  });

  test('Dart result model never labels a request as confirmed', () {
    final model = File(
      'lib/core/services/emergency_session_contract.dart',
    ).readAsStringSync();

    expect(model, contains('submittedUnconfirmed'));
    expect(model, contains("String get connectionState => 'unknown'"));
    expect(model, isNot(contains("connectionState => 'connected'")));
  });

  test('background receivers use the same token claim and typed outcomes', () {
    for (final name in [
      'CountdownAlarmReceiver.kt',
      'CheckInAlarmReceiver.kt',
    ]) {
      final receiver = File('$kotlinBase/$name').readAsStringSync();
      expect(receiver, contains('.claimAndDispatch(token)'));
      expect(receiver, contains('dispatch.callRequestOutcome'));
      expect(receiver, contains('dispatch.fallbackOutcome'));
      expect(receiver, isNot(contains('startActivity(')));
    }
  });

  test(
    'actionable fallback precedes Telecom and keeps target out of intents',
    () {
      final coordinator = File(
        '$kotlinBase/EmergencySessionCoordinator.kt',
      ).readAsStringSync();
      final runtime = File(
        '$kotlinBase/AndroidEmergencySessionRuntime.kt',
      ).readAsStringSync();

      final fallback = coordinator.indexOf('fallbackPoster.post(');
      final call = coordinator.indexOf('callRequester.requestCall(');
      expect(fallback, greaterThanOrEqualTo(0));
      expect(call, greaterThan(fallback));
      expect(runtime, isNot(contains('EXTRA_TARGET')));
    },
  );

  test('emergency alerts do not expose sensitive copy on the lock screen', () {
    final helper = File(
      '$kotlinBase/EmergencyNotificationHelper.kt',
    ).readAsStringSync();

    expect(helper, contains('NotificationCompat.VISIBILITY_PRIVATE'));
    expect(helper, isNot(contains('NotificationCompat.VISIBILITY_PUBLIC')));
  });
}
