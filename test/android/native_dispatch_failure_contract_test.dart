import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const kotlinBase =
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency';

  group('native dispatch failure is never silent', () {
    test('both alarm receivers enter the same token-scoped claim', () {
      for (final name in [
        'CountdownAlarmReceiver.kt',
        'CheckInAlarmReceiver.kt',
      ]) {
        final source = File('$kotlinBase/$name').readAsStringSync();
        expect(source, contains('.claimAndDispatch(token)'));
        expect(source, contains('dispatch.callRequestOutcome'));
        expect(source, contains('dispatch.fallbackOutcome'));
        expect(source, isNot(contains('KEY_COUNTDOWN_ALARM_FIRED')));
        expect(source, isNot(contains('markAlarmFired')));
      }
    });

    test('fallback is attempted before Telecom and failures are typed', () {
      final source = File(
        '$kotlinBase/EmergencySessionCoordinator.kt',
      ).readAsStringSync();
      final fallbackIndex = source.indexOf('fallbackPoster.post(');
      final callIndex = source.indexOf('callRequester.requestCall(');

      expect(fallbackIndex, isNot(-1));
      expect(callIndex, greaterThan(fallbackIndex));
      expect(source, contains('FallbackOutcome.FAILED'));
      expect(source, contains('CallRequestOutcome.FAILED'));
      expect(source, contains('LifecycleState.REQUEST_FAILED'));
    });

    test(
      'failed terminal commit gets bounded retry only before call submit',
      () {
        final source = File(
          '$kotlinBase/EmergencySessionCoordinator.kt',
        ).readAsStringSync();

        expect(source, contains('retryScheduledInProcess'));
        expect(source, contains('DISPATCH_RETRY_DELAY_MS'));
        expect(source, contains('CallRequestOutcome.SUBMITTED_UNCONFIRMED'));
        expect(source, contains('submittedInProcess'));
      },
    );

    test('fallback tap carries token only and resolves target atomically', () {
      final runtime = File(
        '$kotlinBase/AndroidEmergencySessionRuntime.kt',
      ).readAsStringSync();
      final activity = File(
        '$kotlinBase/EmergencyFallbackDialActivity.kt',
      ).readAsStringSync();
      final coordinator = File(
        '$kotlinBase/EmergencySessionCoordinator.kt',
      ).readAsStringSync();

      expect(runtime, isNot(contains('EXTRA_TARGET')));
      expect(activity, contains('consumeFallbackTarget('));
      expect(coordinator, contains('fun consumeFallbackTarget('));
    });

    test('panic, check-in and safe-walk fallback ids are distinct', () {
      final runtime = File(
        '$kotlinBase/AndroidEmergencySessionRuntime.kt',
      ).readAsStringSync();
      expect(runtime, contains('SessionKind.PANIC'));
      expect(runtime, contains('SessionKind.CHECK_IN'));
      expect(runtime, contains('SessionKind.SAFE_WALK'));
      expect(runtime, contains('COUNTDOWN_DISPATCH_FAILED_NOTIFICATION_ID'));
      expect(runtime, contains('CHECK_IN_NOTIFICATION_ID'));
      expect(runtime, contains('SAFE_WALK_NOTIFICATION_ID'));
    });

    test('manual-call copy is bilingual and never interpolates a number', () {
      final source = File(
        '$kotlinBase/NativeNotificationText.kt',
      ).readAsStringSync();

      expect(source, contains('dispatchFailed'));
      expect(source, isNot(contains('{number}')));
      expect(source, contains('Acil arama başlatılamadı'));
      expect(source, contains('Emergency call could not be started'));
    });
  });

  group('Dart expiry half of the chain', () {
    late String executeBody;

    setUpAll(() {
      final source = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      final executeStart = source.indexOf('Future<void> _executeEmergency()');
      final executeEnd = source.indexOf(
        'Future<void> _showBlockingFailure(',
        executeStart,
      );
      expect(executeStart, isNot(-1));
      expect(executeEnd, isNot(-1));
      executeBody = source.substring(executeStart, executeEnd);
    });

    test('Dart dispatches the same typed token and has no fired flag', () {
      expect(
        executeBody,
        matches(RegExp(r'dispatchEmergencySession\s*\(\s*token:\s*token')),
      );
      expect(executeBody, isNot(contains('didCountdownAlarmFire')));
    });

    test('failed request opens visible dialer before blocking fail-safe', () {
      final dialIndex = executeBody.indexOf('AndroidIntentService.openDialer');
      final failedIndex = executeBody.indexOf('EmergencyCallResult.failed');
      expect(dialIndex, isNot(-1));
      expect(failedIndex, greaterThan(dialIndex));
      expect(executeBody, contains('_showBlockingFailure'));
    });
  });
}
