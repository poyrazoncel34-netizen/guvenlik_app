import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmergencyCoreService location cache', () {
    test('cached location should expire after 10 minutes not 30', () {
      final source = File(
        'lib/core/services/emergency_core_service.dart',
      ).readAsStringSync();
      // The cache expiry of 30 minutes is too long for emergency scenarios.
      // A stale location from 25 minutes ago could be very misleading.
      expect(
        source,
        isNot(contains('age.inMinutes < 30')),
        reason: 'Cache should expire after 10 minutes, not 30',
      );
      expect(
        source,
        contains('age.inMinutes < 10'),
        reason: 'Cache expiry should be 10 minutes',
      );
    });
  });

  group('EmergencyCoreService GPS timeout', () {
    test('should not have redundant double timeout on getCurrentPosition', () {
      final source = File(
        'lib/core/services/emergency_core_service.dart',
      ).readAsStringSync();
      final getCurrentPos = source.indexOf('Geolocator.getCurrentPosition');
      expect(getCurrentPos, isNot(-1));
      final section = source.substring(getCurrentPos, getCurrentPos + 300);
      expect(
        section,
        contains('timeLimit'),
        reason: 'Should use Geolocator timeLimit',
      );
      expect(
        section,
        isNot(contains('.timeout(')),
        reason: 'Should not have redundant .timeout() on top of timeLimit',
      );
    });
  });
}
