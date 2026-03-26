import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RACE-1: _makeEmergencyCall must have a re-entry guard to prevent
/// double execution when timer fires while orchestrator is still running.
void main() {
  test('countdown_screen should have _emergencyInProgress guard', () {
    final source = File('lib/screens/countdown_screen.dart').readAsStringSync();

    expect(source.contains('_emergencyInProgress'), isTrue,
        reason: 'Must have _emergencyInProgress re-entry guard');
  });
}
