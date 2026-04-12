import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Check-in expiry coordinator wiring', () {
    test('safe_walk_screen claims expiry before opening countdown', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();

      final expiryIdx = source.indexOf('Future<void> _onTimerExpired()');
      final claimIdx = source.indexOf('tryClaim', expiryIdx);
      final countdownIdx = source.indexOf('CountdownScreen', expiryIdx);

      expect(claimIdx, isNot(-1));
      expect(countdownIdx, isNot(-1));
      expect(
        claimIdx < countdownIdx,
        isTrue,
        reason: 'Safe-walk expiry must claim the coordinator first.',
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

    test('EmergencyTriggerHost routes native fallback through coordinator', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();

      expect(source, contains('Future<void> _handleCheckInExpired()'));
      expect(source, contains('tryClaim'));
      expect(source, contains("'native_check_in_expired'"));
    });
  });
}
