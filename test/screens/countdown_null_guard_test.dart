import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E1: CountdownScreen timer callback must not force-unwrap _startTime.
/// If _startTime is null when the callback fires, the app crashes.
void main() {
  test('countdown timer should not force-unwrap _startTime', () {
    final source = File(
      'lib/screens/countdown_screen.dart',
    ).readAsStringSync();

    // _startTime! is a dangerous force unwrap in the timer callback
    expect(
      source.contains('_startTime!'),
      isFalse,
      reason:
          'CountdownScreen must not force-unwrap _startTime — use null check '
          'guard instead to prevent crash if timer fires after disposal',
    );
  });
}
