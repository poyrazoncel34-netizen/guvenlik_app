import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/check_in_expiry_coordinator.dart';
import 'package:guvenlik_app/core/services/check_in_service.dart';

/// SPEC §6 + §7 ("safe-walk grace eşitliği"): safe-walk uses the SAME shared
/// session controller as check-in — same 60s grace machine, not the old
/// grace=0 immediate-escalation path.
void main() {
  group('Shared session controller', () {
    test('exposes distinct per-session singletons', () {
      expect(
        CheckInService.instance.sessionId,
        CheckInExpiryCoordinator.checkInSession,
      );
      expect(
        CheckInService.safeWalk.sessionId,
        CheckInExpiryCoordinator.safeWalkSession,
      );
      expect(
        identical(CheckInService.instance, CheckInService.safeWalk),
        isFalse,
        reason: 'check-in and safe-walk run concurrently — separate state.',
      );
    });

    test('safe-walk session is idle by default', () {
      expect(CheckInService.safeWalk.isActive, isFalse);
      expect(CheckInService.safeWalk.isGracePeriod, isFalse);
    });

    test('controller schedules the main deadline with a 60s grace window', () {
      final source = File(
        'lib/core/services/check_in_service.dart',
      ).readAsStringSync();
      // Native receives both deadlines in one atomic arm. No second grace
      // reschedule is required at the phase boundary.
      expect(source, contains('finalDeadline: finalDeadline'));
      expect(source, contains('const Duration(seconds: _gracePeriodSeconds)'));
      expect(source, contains('static const int _gracePeriodSeconds = 60;'));
    });

    test('safe-walk screen no longer uses the grace=0 immediate path', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      expect(
        source.contains('Duration.zero'),
        isFalse,
        reason:
            'Safe-walk must not schedule a zero grace (immediate escalate).',
      );
      expect(
        source.contains("phase: 'grace'"),
        isFalse,
        reason:
            'Safe-walk delegates scheduling to the controller (main phase).',
      );
    });
  });
}
