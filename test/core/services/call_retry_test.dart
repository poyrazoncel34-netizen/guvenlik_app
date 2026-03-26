import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 1: CallService must have a retry method that uses phone state
/// verification to confirm calls actually connected.
void main() {
  test('CallService should have startEmergencyCallWithRetry method', () {
    final source = File('lib/core/services/call_service.dart').readAsStringSync();

    expect(
      source.contains('startEmergencyCallWithRetry'),
      isTrue,
      reason: 'CallService must have retry method for call guarantee system',
    );

    // Must subscribe to phone state for verification
    expect(
      source.contains('phoneStates'),
      isTrue,
      reason: 'Call retry must use phone state stream for call verification',
    );

    // Must have retry loop
    expect(
      source.contains('maxRetries') || source.contains('attempt'),
      isTrue,
      reason: 'Call retry must track attempt count',
    );
  });
}
