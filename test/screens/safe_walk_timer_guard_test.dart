import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RACE-3: _onTimerExpired must have re-entry guard to prevent
/// double emergency trigger from timer + native grace alarm race.
void main() {
  test('safe_walk_screen should have _timerExpiredHandled guard', () {
    final source = File('lib/screens/safe_walk_screen.dart').readAsStringSync();

    expect(source.contains('_timerExpiredHandled'), isTrue,
        reason: 'Must have _timerExpiredHandled guard to prevent double trigger');
  });
}
