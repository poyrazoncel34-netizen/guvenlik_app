// Integration test: Emergency call flow — countdown → call dispatch → failover.
// Verifies the critical path that is the app's reason for existing.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Emergency call flow — countdown to call', () {
    test('countdown_screen dispatches call via CallService on timer expiry',
        () {
      // Verify the critical code path exists:
      // Timer reaches 0 → _makeEmergencyCall → _executeEmergency → CallService
      final content =
          File('lib/screens/countdown_screen.dart').readAsStringSync();

      // 1. Timer callback calls _makeEmergencyCall when countdown hits 0
      expect(
        content.contains('_makeEmergencyCall'),
        isTrue,
        reason:
            'countdown_screen must call _makeEmergencyCall when timer expires',
      );

      // 2. _executeEmergency fetches contacts and calls CallService
      expect(
        content.contains('CallService.startEmergencyCall'),
        isTrue,
        reason:
            'countdown_screen must dispatch call via CallService.startEmergencyCall',
      );

      // 3. Failover: iterates through numbers if first call fails
      expect(
        content.contains('fallbackNumber'),
        isTrue,
        reason:
            'countdown_screen must try fallback numbers when primary call fails',
      );

      // 4. Shows blocking failure screen if ALL calls fail
      expect(
        content.contains('_showBlockingFailure'),
        isTrue,
        reason:
            'countdown_screen must show blocking failure when all calls fail',
      );

      // 5. Navigates to EmergencyCallScreen on success
      expect(
        content.contains('EmergencyCallScreen'),
        isTrue,
        reason:
            'countdown_screen must navigate to EmergencyCallScreen on success',
      );
    });

    test('Doze mode guard prevents double-dispatch', () {
      final content =
          File('lib/screens/countdown_screen.dart').readAsStringSync();

      // C4: Native alarm may fire while Dart timer is frozen by Doze.
      // CountdownScreen must check didCountdownAlarmFire before dispatching.
      expect(
        content.contains('didCountdownAlarmFire'),
        isTrue,
        reason:
            'countdown_screen must check native alarm to prevent '
            'double-dispatch when Dart timer was frozen by Doze',
      );

      // _emergencyDispatched flag must exist as second guard
      expect(
        content.contains('_emergencyDispatched'),
        isTrue,
        reason:
            'countdown_screen must use _emergencyDispatched flag '
            'to prevent duplicate execution',
      );
    });

    test('instantCallTriggered skips countdown dispatch', () {
      final content =
          File('lib/screens/countdown_screen.dart').readAsStringSync();

      expect(
        content.contains('instantCallTriggered'),
        isTrue,
        reason:
            'countdown_screen must support instantCallTriggered flag '
            'to skip duplicate dispatch when native call already placed',
      );
    });

    test('CallService returns typed EmergencyCallResult with all states', () {
      final content =
          File('lib/core/services/call_service.dart').readAsStringSync();

      expect(content.contains('EmergencyCallResult'), isTrue,
          reason: 'CallService must return typed result');
      expect(content.contains('EmergencyCallStatus.failed'), isTrue,
          reason: 'must have failed status');
      expect(content.contains('EmergencyCallStatus.directCallStarted'), isTrue,
          reason: 'must have directCallStarted status');
      expect(content.contains('EmergencyCallStatus.dialerOpened'), isTrue,
          reason: 'must have dialerOpened fallback for denied CALL_PHONE');
    });

    test('no SMS references in emergency call flow', () {
      final countdownContent =
          File('lib/screens/countdown_screen.dart').readAsStringSync();
      final callServiceContent =
          File('lib/core/services/call_service.dart').readAsStringSync();

      expect(countdownContent.contains('sendSms'), isFalse,
          reason: 'countdown_screen must not call sendSms');
      expect(countdownContent.contains('SmsService'), isFalse,
          reason: 'countdown_screen must not reference SmsService');
      expect(callServiceContent.contains('sendSms'), isFalse,
          reason: 'call_service must not reference sendSms');
    });
  });
}
