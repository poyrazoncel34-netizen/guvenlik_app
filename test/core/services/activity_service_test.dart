import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S4: activity_events table must have a retention policy to prevent unbounded
/// growth. The logEvent method should clean up old rows after insert.
void main() {
  test('ActivityService.logEvent should enforce retention limit', () {
    final source = File(
      'lib/core/services/activity_service.dart',
    ).readAsStringSync();

    // After inserting, should delete excess rows beyond retention limit
    expect(
      source.contains('DELETE FROM activity_events'),
      isTrue,
      reason:
          'ActivityService.logEvent must enforce a retention limit by deleting '
          'old rows — unbounded growth will exhaust storage over months',
    );
  });
}
