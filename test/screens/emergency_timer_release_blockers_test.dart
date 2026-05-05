import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Safe Walk and Check-in release blockers', () {
    test('safe walk checks emergency contacts before warning and start', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _startSafeWalk()');
      final contactCheck = source.indexOf('_hasEmergencyContact()', start);
      final firstWarning = source.indexOf(
        'FeatureWarningHelper.showIfNeeded',
        start,
      );
      final activeState = source.indexOf('_isActive = true', start);

      expect(start, isNot(-1));
      expect(contactCheck, isNot(-1));
      expect(firstWarning, isNot(-1));
      expect(activeState, isNot(-1));
      expect(contactCheck < firstWarning, isTrue);
      expect(contactCheck < activeState, isTrue);
      expect(source, contains('timer_emergency_contact_required'));
      expect(source, contains('ContactsPage'));
    });

    test('safe walk requires notification permission before timer starts', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _startSafeWalk()');
      final warning = source.indexOf(
        'FeatureWarningHelper.showIfNeeded',
        start,
      );
      final notificationGuard = source.indexOf(
        'PermissionHelper.requestNotificationPermission',
        start,
      );
      final activeState = source.indexOf('_isActive = true', start);

      expect(start, isNot(-1));
      expect(warning, isNot(-1));
      expect(notificationGuard, isNot(-1));
      expect(activeState, isNot(-1));
      expect(warning < notificationGuard, isTrue);
      expect(notificationGuard < activeState, isTrue);
      expect(source, contains('notification_session_permission_required'));
    });

    test('check-in checks emergency contacts before warning and start', () {
      final source = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _startCheckIn');
      final contactCheck = source.indexOf('_hasEmergencyContact()', start);
      final firstWarning = source.indexOf(
        'FeatureWarningHelper.showIfNeeded',
        start,
      );
      final serviceStart = source.indexOf('_service.start(minutes)', start);

      expect(start, isNot(-1));
      expect(contactCheck, isNot(-1));
      expect(firstWarning, isNot(-1));
      expect(serviceStart, isNot(-1));
      expect(contactCheck < firstWarning, isTrue);
      expect(contactCheck < serviceStart, isTrue);
      expect(source, contains('timer_emergency_contact_required'));
      expect(source, contains('ContactsPage'));
    });

    test('native scheduling degradation is surfaced by both timer flows', () {
      final platform = File(
        'lib/core/services/emergency_platform_service.dart',
      ).readAsStringSync();
      expect(
        platform,
        contains("response['scheduled'] == true && response['exact'] == true"),
      );

      final service = File(
        'lib/core/services/check_in_service.dart',
      ).readAsStringSync();
      expect(service, contains('Future<bool> start(int minutes)'));
      expect(service, contains('_nativeScheduleDegraded = !nativeScheduled'));

      final checkIn = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      expect(checkIn, contains('final fullyScheduled = await _service.start'));
      expect(checkIn, contains('timer_scheduling_degraded'));

      final safeWalk = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      expect(safeWalk, contains('final fullyScheduled = await'));
      expect(safeWalk, contains('timer_scheduling_degraded'));
    });
  });
}
