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
      final sessionStart = source.indexOf('_controller.start(', start);

      expect(start, isNot(-1));
      expect(contactCheck, isNot(-1));
      expect(firstWarning, isNot(-1));
      expect(sessionStart, isNot(-1));
      expect(contactCheck < firstWarning, isTrue);
      expect(contactCheck < sessionStart, isTrue);
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
      final exactAlarmGuard = source.indexOf(
        'confirmExactAlarmPermissionOrDegraded',
        start,
      );
      final sessionStart = source.indexOf('_controller.start(', start);

      expect(start, isNot(-1));
      expect(warning, isNot(-1));
      expect(notificationGuard, isNot(-1));
      expect(exactAlarmGuard, isNot(-1));
      expect(sessionStart, isNot(-1));
      expect(warning < notificationGuard, isTrue);
      expect(notificationGuard < exactAlarmGuard, isTrue);
      expect(notificationGuard < sessionStart, isTrue);
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

    test('exact alarm degraded mode requires explicit acknowledgment', () {
      final guard = File(
        'lib/core/widgets/exact_alarm_permission_guard.dart',
      ).readAsStringSync();
      final enTranslations = File(
        'assets/translations/en-US.json',
      ).readAsStringSync();
      expect(guard, contains('canScheduleExactAlarms'));
      expect(guard, contains('requestExactAlarmPermission'));
      expect(guard, contains('barrierDismissible: false'));
      expect(guard, contains('exact_alarm_degraded_continue'));
      expect(
        enTranslations,
        contains(
          'Exact alarm access improves safety timer reliability. Without it, timers may be delayed.',
        ),
      );

      final checkIn = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      final checkInStart = checkIn.indexOf('Future<void> _startCheckIn');
      final checkInGuard = checkIn.indexOf(
        'confirmExactAlarmPermissionOrDegraded',
        checkInStart,
      );
      final serviceStart = checkIn.indexOf(
        '_service.start(minutes)',
        checkInStart,
      );
      expect(checkInGuard, isNot(-1));
      expect(serviceStart, isNot(-1));
      expect(checkInGuard < serviceStart, isTrue);

      final safeWalk = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final safeWalkStart = safeWalk.indexOf('Future<void> _startSafeWalk');
      final safeWalkGuard = safeWalk.indexOf(
        'confirmExactAlarmPermissionOrDegraded',
        safeWalkStart,
      );
      final sessionStart = safeWalk.indexOf('_controller.start(', safeWalkStart);
      expect(safeWalkGuard, isNot(-1));
      expect(sessionStart, isNot(-1));
      expect(safeWalkGuard < sessionStart, isTrue);
    });

    test('countdown backup alarm has denied/degraded native fallback', () {
      final countdown = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      expect(countdown, contains('_scheduleNativeBackupAlarm'));
      expect(countdown, contains('degraded safety net'));

      final scheduler = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmScheduler.kt',
      ).readAsStringSync();
      expect(scheduler, contains('CheckInScheduler.canScheduleExactAlarms'));
      expect(scheduler, contains('setExactAndAllowWhileIdle'));
      expect(scheduler, contains('setAndAllowWhileIdle'));
      expect(scheduler, contains('Exact alarm permission denied'));
    });

    test('safe walk guards mounted after the async controller start', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final startAwait = source.indexOf(
        'final fullyScheduled = await _controller.start(',
      );
      final mountedGuard = source.indexOf('if (!mounted) return;', startAwait);
      final degradedSnack = source.indexOf(
        '_showTimerSchedulingDegraded();',
        startAwait,
      );

      expect(startAwait, isNot(-1));
      expect(mountedGuard, isNot(-1));
      expect(degradedSnack, isNot(-1));
      expect(
        mountedGuard < degradedSnack,
        isTrue,
        reason: 'mounted must be checked before touching UI after start().',
      );
    });
  });
}
