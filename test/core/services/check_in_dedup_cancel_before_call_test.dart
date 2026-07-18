import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression contract for the former zero-call race: the old implementation
/// cancelled the native backup, then ran DB/log/haptic work, and only then
/// attempted a Dart call. Any intermediate failure could leave no dispatcher.
void main() {
  late String triggerBody;

  setUpAll(() {
    final source = File(
      'lib/core/services/check_in_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _triggerEmergency()');
    final end = source.indexOf('static String resolvePrimaryNumber', start);
    expect(start, isNot(-1));
    triggerBody = source.substring(start, end);
  });

  test('native coordinator dispatch is the first external side effect', () {
    final dispatch = triggerBody.indexOf('dispatchEmergencySession');
    expect(dispatch, isNot(-1));
    for (final nonCritical in <String>[
      'ActivityService.logEvent',
      'HapticService.emergencyTriggered',
      'NotificationService.instance.showEmergencyAlert',
      'navigator.push',
    ]) {
      final index = triggerBody.indexOf(nonCritical);
      expect(index, isNot(-1), reason: '$nonCritical must remain wired');
      expect(
        dispatch < index,
        isTrue,
        reason: '$nonCritical cannot create a zero-dispatch failure path.',
      );
    }
  });

  test('expiry does not cancel or call through a second Dart authority', () {
    expect(triggerBody, isNot(contains('cancelCheckIn')));
    expect(triggerBody, isNot(contains('didCheckInAlarmFire')));
    expect(triggerBody, isNot(contains('CallService.startEmergencyCall')));
  });

  test('Unknown dispatch is not converted into terminal success/failure', () {
    final unknown = triggerBody.indexOf('if (dispatch.isUnknown)');
    final clear = triggerBody.indexOf('_clearLocalProjection');
    expect(unknown, isNot(-1));
    expect(clear, greaterThan(unknown));
    final earlyBlock = triggerBody.substring(unknown, clear);
    expect(earlyBlock, contains('return;'));
  });
}
