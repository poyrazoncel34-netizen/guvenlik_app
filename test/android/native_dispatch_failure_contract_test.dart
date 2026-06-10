import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// FRESH_AUDIT_2026-06-10 F1 source contract: the native receivers must read
/// the EmergencyExecutor dispatch result. The alarm-fired dedup flag may be
/// written ONLY after a successful dispatch, and a failed dispatch must
/// surface a manual-call notification instead of being silently swallowed.
void main() {
  final base = Directory.current.path.endsWith('test')
      ? Directory.current.parent.path
      : Directory.current.path;

  final ktBase = '$base/android/app/src/main/kotlin/com/poyrazoncel/korubeni';

  group('F1: native dispatch failure is never silent', () {
    test('CountdownAlarmReceiver sets fired flag only after dispatch', () {
      final source = File(
        '$ktBase/emergency/CountdownAlarmReceiver.kt',
      ).readAsStringSync();

      expect(
        source.contains('"failed"'),
        isTrue,
        reason: 'Receiver must inspect the executor status for failure',
      );

      final dispatchIndex = source.indexOf('executeEmergency(');
      final firedWriteIndex = source.indexOf(
        'putBoolean(EmergencyPrefs.KEY_COUNTDOWN_ALARM_FIRED, true)',
      );
      expect(dispatchIndex, isNot(-1));
      expect(
        firedWriteIndex,
        isNot(-1),
        reason: 'Successful dispatch must still set the dedup flag',
      );
      expect(
        firedWriteIndex > dispatchIndex,
        isTrue,
        reason:
            'Fired flag must be written AFTER the dispatch outcome is '
            'known, never before (a failed call must not poison Dart dedup)',
      );
      expect(
        source.contains('dispatchFailed'),
        isTrue,
        reason: 'Failure path must post the manual-call notification copy',
      );
    });

    test('CheckInAlarmReceiver splits deactivate from fired-flag write', () {
      final source = File(
        '$ktBase/emergency/CheckInAlarmReceiver.kt',
      ).readAsStringSync();

      expect(
        source.contains('markAlarmFiredAndDeactivate'),
        isFalse,
        reason:
            'Pre-dispatch fired-flag write must be gone: it suppressed '
            'the Dart retry + fail-safe when the native call failed',
      );
      expect(source, contains('deactivateForEscalation'));
      expect(source, contains('markAlarmFired('));
      expect(source, contains('"failed"'));
      expect(
        source.contains('dispatchFailed'),
        isTrue,
        reason:
            'Failure path must use the manual-call copy, not the '
            'misleading "timer ended" success copy',
      );
    });

    test('CheckInScheduler boot-restore uses the same failure contract', () {
      final source = File(
        '$ktBase/emergency/CheckInScheduler.kt',
      ).readAsStringSync();

      expect(source.contains('markAlarmFiredAndDeactivate'), isFalse);
      expect(source, contains('deactivateForEscalation'));
      expect(source, contains('fun markAlarmFired('));
      expect(source, contains('dispatchFailed'));
    });

    test('CountdownAlarmReceiver failure tap opens the dialer directly', () {
      final source = File(
        '$ktBase/emergency/CountdownAlarmReceiver.kt',
      ).readAsStringSync();
      expect(
        source.contains('buildDialPendingIntent'),
        isTrue,
        reason:
            'Failure notification tap must open the dialer pre-filled — '
            'an app-launch intent would hit the PIN gate first',
      );
    });

    test('check-in and safe-walk alerts use session-scoped ids', () {
      final receiver = File(
        '$ktBase/emergency/CheckInAlarmReceiver.kt',
      ).readAsStringSync();
      final scheduler = File(
        '$ktBase/emergency/CheckInScheduler.kt',
      ).readAsStringSync();
      final helper = File(
        '$ktBase/emergency/EmergencyNotificationHelper.kt',
      ).readAsStringSync();

      expect(helper, contains('SAFE_WALK_NOTIFICATION_ID = 7305'));
      expect(scheduler, contains('fun notificationIdFor('));
      expect(
        receiver.contains('notificationIdFor('),
        isTrue,
        reason:
            'Receiver must resolve the alert id per session so '
            'overlapping check-in + safe-walk failures never clobber',
      );
      expect(
        receiver.contains('CHECK_IN_NOTIFICATION_ID,'),
        isFalse,
        reason: 'No hardcoded shared alert id may remain in the receiver',
      );
    });

    test('NativeNotificationText carries TR+EN manual-call copy', () {
      final source = File(
        '$ktBase/emergency/NativeNotificationText.kt',
      ).readAsStringSync();

      expect(source, contains('dispatchFailed'));
      expect(
        source.contains('{number}'),
        isTrue,
        reason: 'Manual-call body must embed the primary number placeholder',
      );
      expect(source, contains('Acil arama başlatılamadı'));
      expect(source, contains('Emergency call could not be started'));
    });
  });
  group('F1: Dart resume half of the chain (source contract)', () {
    late String makeCallBody;
    late String executeBody;

    setUpAll(() {
      final source = File(
        '$base/lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      final makeStart = source.indexOf('Future<void> _makeEmergencyCall()');
      final execStart = source.indexOf('Future<void> _executeEmergency()');
      final execEnd = source.indexOf('Future<void> _showBlockingFailure(');
      expect(makeStart, isNot(-1));
      expect(execStart, isNot(-1));
      expect(execEnd, isNot(-1));
      makeCallBody = source.substring(makeStart, execStart);
      executeBody = source.substring(execStart, execEnd);
    });

    test('alarmFired guard returns before any Dart dispatch', () {
      final guardIdx = makeCallBody.indexOf('if (alarmFired)');
      final dispatchIdx = makeCallBody.indexOf('_executeEmergency()');
      expect(guardIdx, isNot(-1));
      expect(dispatchIdx, isNot(-1));
      final returnIdx = makeCallBody.indexOf('return;', guardIdx);
      expect(returnIdx, isNot(-1));
      expect(
        returnIdx < dispatchIdx,
        isTrue,
        reason: 'fired=true must short-circuit BEFORE the Dart dispatch',
      );
    });

    test('non-fired path reaches the Dart dispatch (retry on flag=false)', () {
      // With the F1 fix the native side leaves the flag false on a failed
      // dispatch; the resumed Dart isolate must then run its own dispatch.
      expect(
        makeCallBody.contains('await _executeEmergency()'),
        isTrue,
        reason:
            'flag=false path must reach _executeEmergency (failover + '
            'blocking fail-safe live there)',
      );
    });

    test('isFailed result triggers the blocking fail-safe', () {
      final failedIdx = executeBody.indexOf('callResult.isFailed');
      expect(failedIdx, isNot(-1));
      final failSafeIdx = executeBody.indexOf(
        '_showBlockingFailure',
        failedIdx,
      );
      expect(
        failSafeIdx,
        isNot(-1),
        reason: 'total failure must surface the blocking manual-call dialog',
      );
    });
  });
}
