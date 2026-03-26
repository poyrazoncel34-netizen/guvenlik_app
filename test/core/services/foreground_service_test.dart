import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// C1: Verify foreground service uses specialUse type (not dataSync).
/// Heartbeat timer must have try-catch error handling.
void main() {
  test('foreground service config should use specialUse type', () {
    final source = File('lib/core/services/foreground_service.dart').readAsStringSync();
    expect(source.contains('specialUse'), isTrue,
        reason: 'Must use specialUse foreground service type for Android 15');
  });

  group('ForegroundService heartbeat timer', () {
    test('heartbeat timer callback should have try-catch error handling', () {
      final source = File('lib/core/services/foreground_service.dart').readAsStringSync();
      final heartbeatStart = source.indexOf('heartbeatTimer = Timer.periodic');
      expect(heartbeatStart, isNot(-1), reason: 'heartbeat timer should exist');

      final afterHeartbeat = source.substring(heartbeatStart);
      expect(afterHeartbeat.substring(0, 500), contains('try {'),
          reason: 'heartbeat timer callback must have try-catch for resilience');
    });
  });
}
