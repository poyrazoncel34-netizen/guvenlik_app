import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A panic expiry must claim/dispatch through the native coordinator before
/// non-critical Flutter bookkeeping. Alarm cancellation is not a dispatch
/// prerequisite and widget lifecycle is not cancellation authority.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/countdown_screen.dart').readAsStringSync();
  });

  test('dispatch precedes queue, log, haptic and Flutter notification', () {
    final executeStart = source.indexOf('Future<void> _executeEmergency()');
    final executeEnd = source.indexOf(
      'Future<void> _showBlockingFailure',
      executeStart,
    );
    final body = source.substring(executeStart, executeEnd);
    final dispatch = body.indexOf('dispatchEmergencySession');
    expect(dispatch, isNot(-1));
    for (final nonCritical in <String>[
      'OfflineQueueService.instance.enqueue',
      'ActivityService.logEvent',
      'HapticService.emergencyTriggered',
      'NotificationService.instance.showEmergencyAlert',
    ]) {
      expect(
        dispatch < body.indexOf(nonCritical),
        isTrue,
        reason: '$nonCritical must not precede native dispatch.',
      );
    }
  });

  test('panic dispatch path never cancels the native session as cleanup', () {
    final makeCallStart = source.indexOf('Future<void> _makeEmergencyCall()');
    final cancelStart = source.indexOf(
      'Future<void> _cancelCountdownAndExit',
      makeCallStart,
    );
    final dispatchBody = source.substring(makeCallStart, cancelStart);
    expect(dispatchBody, isNot(contains('cancelCountdownAlarm')));
    expect(dispatchBody, isNot(contains('cancelEmergencySession')));
  });
}
