import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E6: CheckInScheduler.restoreAfterBoot should emit a corruption event when
/// deadlineMs <= 0 instead of silently cancelling the check-in timer.
void main() {
  test('restoreAfterBoot should emit event on corrupted deadline', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt',
    ).readAsStringSync();

    // Find the deadlineMs <= 0 branch
    final deadlineCheck = source.indexOf('deadlineMs <= 0L');
    expect(deadlineCheck, isNot(-1));

    // After this check, before cancel, should emit a corruption event
    final afterCheck = source.substring(deadlineCheck, deadlineCheck + 200);
    expect(
      afterCheck.contains('checkInCorrupted') || afterCheck.contains('Corrupted'),
      isTrue,
      reason:
          'restoreAfterBoot must emit a corruption event when deadlineMs <= 0 '
          'so the Dart side knows the check-in was lost due to data corruption',
    );
  });
}
