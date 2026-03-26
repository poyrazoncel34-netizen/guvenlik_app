import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForegroundService heartbeat timer', () {
    test('heartbeat timer callback should have try-catch error handling', () {
      final source = File('lib/core/services/foreground_service.dart').readAsStringSync();
      // The heartbeat Timer.periodic async callback must wrap its body in
      // try-catch to prevent unhandled exceptions from killing the timer.
      // Find the heartbeat timer section and verify it has error handling.
      final heartbeatStart = source.indexOf('heartbeatTimer = Timer.periodic');
      expect(heartbeatStart, isNot(-1), reason: 'heartbeat timer should exist');

      // Extract from heartbeat start to the closing of its callback
      final afterHeartbeat = source.substring(heartbeatStart);
      // The callback body should contain try-catch
      expect(afterHeartbeat.substring(0, 500), contains('try {'),
          reason: 'heartbeat timer callback must have try-catch for resilience');
    });
  });
}
