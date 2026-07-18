import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production safety-session call sites', () {
    test('check-in resolves entitlement and PIN before typed arm', () {
      final source = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _startCheckIn');
      final body = source.substring(
        start,
        source.indexOf('Future<void> _confirmSafe', start),
      );

      expect(body, contains('subscription.resolveAccess()'));
      expect(body, contains('PinVerificationService.instance.loadState()'));
      expect(body, contains('_service.startSession('));
      expect(body, contains('entitlementDecision: access.entitlementDecision'));
      expect(body, contains('pinConfigured: pinState == PinState.configured'));
      expect(body, contains('if (result is! Armed)'));
      expect(body, isNot(contains('_service.start(minutes)')));
    });

    test(
      'check-in never reports confirm or stop success without typed ack',
      () {
        final source = File(
          'lib/screens/check_in_screen.dart',
        ).readAsStringSync();
        final confirm = source.substring(
          source.indexOf('Future<void> _confirmSafe'),
          source.indexOf('Future<void> _stopCheckIn'),
        );
        final stop = source.substring(
          source.indexOf('Future<void> _stopCheckIn'),
          source.indexOf('String _formatTime'),
        );

        expect(confirm, contains('confirmSafeSession()'));
        expect(confirm, contains('if (!await _verifySafetyIntent()) return;'));
        expect(
          confirm.indexOf('_verifySafetyIntent'),
          lessThan(confirm.indexOf('confirmSafeSession')),
        );
        expect(confirm, contains('if (result is! Armed)'));
        expect(stop, contains('stopSession()'));
        expect(stop, contains('if (!await _verifySafetyIntent()) return;'));
        expect(
          stop.indexOf('_verifySafetyIntent'),
          lessThan(stop.indexOf('stopSession')),
        );
        expect(stop, contains('!result.isConfirmedCancelled'));
      },
    );

    test('safe walk logs and exits only after confirmed cancellation', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final markSafe = source.substring(
        source.indexOf('Future<void> _markSafe'),
        source.indexOf('Future<bool> _cancelWalk'),
      );
      final exit = source.substring(source.indexOf('void _showExitWarning'));

      expect(markSafe, contains('stopSession()'));
      expect(markSafe, contains('if (!await _verifySafetyIntent()) return;'));
      expect(
        markSafe.indexOf('_verifySafetyIntent'),
        lessThan(markSafe.indexOf('stopSession')),
      );
      expect(markSafe, contains('!result.isConfirmedCancelled'));
      expect(
        markSafe.indexOf('!result.isConfirmedCancelled'),
        lessThan(markSafe.indexOf('ActivityService.logEvent')),
      );
      expect(exit, contains('final cancelled = await _cancelWalk()'));
      expect(exit, contains('if (cancelled) Navigator.pop(context)'));
      final cancel = source.substring(
        source.indexOf('Future<bool> _cancelWalk'),
        source.indexOf('String _formatTime'),
      );
      expect(
        cancel,
        contains('if (!await _verifySafetyIntent()) return false;'),
      );
      expect(
        cancel.indexOf('_verifySafetyIntent'),
        lessThan(cancel.indexOf('stopSession')),
      );
    });

    test('resume lock is never bypassed by an active safety session', () {
      final source = File(
        'lib/core/services/app_lifecycle_handler.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('CheckInService.instance.isActive')));
      expect(source, isNot(contains('CheckInService.instance.isGracePeriod')));
      expect(source, contains('elapsed < lockAfterSeconds'));
      expect(source, contains('AppUnlockScreen('));
    });

    test('panic passes a fresh authorized decision into countdown', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      final open = source.substring(
        source.indexOf('Future<void> _openCountdownScreen'),
        source.indexOf('Future<bool> _hasCallableContact'),
      );

      expect(open, contains('SubscriptionGate.ensureAccess'));
      expect(open, contains('EntitlementDecision.authorized'));
      expect(
        open,
        contains('CountdownScreen(entitlementDecision: entitlementDecision)'),
      );
    });

    test('notification and exact-alarm denial have no start-anyway path', () {
      final checkIn = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      final safeWalk = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final exactGuard = File(
        'lib/core/widgets/exact_alarm_permission_guard.dart',
      ).readAsStringSync();

      expect(
        checkIn,
        isNot(contains('confirmStartSessionWithoutNotifications')),
      );
      expect(
        safeWalk,
        isNot(contains('confirmStartSessionWithoutNotifications')),
      );
      expect(exactGuard, isNot(contains('exact_alarm_degraded_continue')));
      expect(exactGuard, contains('return false;'));
    });
  });
}
