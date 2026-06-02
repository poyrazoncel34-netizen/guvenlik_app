import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Check-in expiry coordinator wiring', () {
    test('safe_walk_screen delegates expiry to the shared controller', () {
      // SPEC §6: safe-walk no longer runs its own timer / opens CountdownScreen
      // on expiry — it uses the shared CheckInService.safeWalk session
      // controller (60s grace + native primary-only backup).
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();

      expect(source, contains('CheckInService.safeWalk'));
      expect(
        source.contains('CountdownScreen'),
        isFalse,
        reason: 'Safe-walk expiry must not open the panic CountdownScreen.',
      );
      expect(
        source.contains("await _controller.start("),
        isTrue,
        reason: 'Safe-walk must start the shared session controller.',
      );
    });

    test('CheckInService claims expiry before emergency trigger work', () {
      final source = File(
        'lib/core/services/check_in_service.dart',
      ).readAsStringSync();

      final triggerIdx = source.indexOf('Future<void> _triggerEmergency()');
      final claimIdx = source.indexOf('tryClaim', triggerIdx);
      final logIdx = source.indexOf('ActivityService.logEvent', triggerIdx);

      expect(claimIdx, isNot(-1));
      expect(logIdx, isNot(-1));
      expect(
        claimIdx < logIdx,
        isTrue,
        reason: 'Check-in expiry must claim before side effects.',
      );
    });

    test('EmergencyTriggerHost routes both sessions through the controller', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('Future<void> _handleCheckInExpired({String? sessionId})'),
      );
      // Session-aware controller resolution (check-in vs safe-walk).
      expect(source, contains('_controllerFor'));
      expect(source, contains('CheckInExpiryCoordinator.safeWalkSession'));
      expect(source, contains('CheckInService.safeWalk'));
      expect(source, contains('handleNativeExpired'));
    });
  });
}
