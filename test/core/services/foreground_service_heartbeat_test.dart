import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S7: Foreground service heartbeat timer callback must be wrapped in try-catch.
/// If notificationsPlugin.show throws, an unhandled exception in the background
/// isolate crashes the entire service.
void main() {
  test('foreground service heartbeat timer should have error handling', () {
    final source = File(
      'lib/core/services/foreground_service.dart',
    ).readAsStringSync();

    // Find the heartbeat timer section (Timer.periodic)
    final timerIndex = source.indexOf('Timer.periodic');
    expect(timerIndex, isNot(-1), reason: 'heartbeat timer must exist');

    // The timer callback should contain try-catch for error resilience
    final afterTimer = source.substring(timerIndex);
    final timerEnd = afterTimer.indexOf('});');
    final timerBody = afterTimer.substring(0, timerEnd);

    expect(
      timerBody.contains('try'),
      isTrue,
      reason:
          'Heartbeat timer callback must be wrapped in try-catch — unhandled '
          'exception in background isolate crashes the foreground service',
    );
  });
}
