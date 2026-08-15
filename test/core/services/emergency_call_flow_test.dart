// Source-contract test: countdown → typed native session dispatch.
// Verifies the critical path that is the app's reason for existing.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Emergency call flow — countdown to call', () {
    test('countdown_screen dispatches native call only on timer expiry', () {
      // Verify the critical code path exists:
      // Timer reaches 0 -> _makeEmergencyCall -> _executeEmergency -> native call.
      final content = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();

      // 1. Timer callback calls _makeEmergencyCall when countdown hits 0
      expect(
        content.contains('_makeEmergencyCall'),
        isTrue,
        reason:
            'countdown_screen must call _makeEmergencyCall when timer expires',
      );

      // 2. _executeEmergency dispatches the already-armed immutable token.
      expect(
        content,
        matches(RegExp(r'dispatchEmergencySession\s*\(\s*token:\s*token')),
        reason:
            'countdown_screen must dispatch the typed native session after expiry',
      );

      // 3. Target failover is forbidden: arming snapshots one immutable target.
      expect(
        content.contains('fallbackNumber'),
        isFalse,
        reason:
            'countdown_screen must not redirect an armed session to another number',
      );

      // 4. Shows blocking failure screen if ALL calls fail
      expect(
        content.contains('EmergencyFailureDialog.show'),
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

    test('Doze mode dedup is owned by the native token claim', () {
      final content = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      final coordinator = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/'
        'EmergencySessionCoordinator.kt',
      ).readAsStringSync();

      // Dart and AlarmManager may race. Both use the same native claim path;
      // stale boolean flags are no longer a second authority.
      expect(
        content,
        matches(RegExp(r'dispatchEmergencySession\s*\(\s*token:\s*token')),
      );
      expect(
        coordinator,
        contains('fun claimAndDispatch(token: SessionToken)'),
      );
      expect(coordinator, contains('current.token != token'));
      expect(coordinator, contains('LifecycleState.CLAIMED'));
      expect(content, isNot(contains('didCountdownAlarmFire')));

      // _emergencyDispatched flag must exist as second guard
      expect(
        content.contains('_emergencyDispatched'),
        isTrue,
        reason:
            'countdown_screen must use _emergencyDispatched flag '
            'to prevent duplicate execution',
      );
    });

    test('instantCallTriggered pre-dispatch path does not exist', () {
      final content = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();

      expect(
        content.contains('instantCallTriggered'),
        isFalse,
        reason:
            'countdown_screen must not support early native call bypass flags',
      );
    });

    test('CallService returns typed EmergencyCallResult with all states', () {
      final content = File(
        'lib/core/services/call_service.dart',
      ).readAsStringSync();

      expect(
        content.contains('EmergencyCallResult'),
        isTrue,
        reason: 'CallService must return typed result',
      );
      expect(
        content.contains('EmergencyCallStatus.failed'),
        isTrue,
        reason: 'must have failed status',
      );
      expect(
        content.contains('EmergencyCallStatus.callRequested'),
        isTrue,
        reason: 'must represent an unconfirmed direct call request',
      );
      expect(
        content.contains('EmergencyCallStatus.dialerRequested'),
        isTrue,
        reason: 'must represent an unconfirmed dialer request',
      );
    });

    test('no SMS references in emergency call flow', () {
      final countdownContent = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      final callServiceContent = File(
        'lib/core/services/call_service.dart',
      ).readAsStringSync();

      expect(
        countdownContent.contains('sendSms'),
        isFalse,
        reason: 'countdown_screen must not call sendSms',
      );
      expect(
        countdownContent.contains('SmsService'),
        isFalse,
        reason: 'countdown_screen must not reference SmsService',
      );
      expect(
        callServiceContent.contains('sendSms'),
        isFalse,
        reason: 'call_service must not reference sendSms',
      );
    });
  });
}
