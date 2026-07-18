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
      final sessionStart = source.indexOf('_controller.startSession(', start);

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
        'requireExactAlarmPermission',
        start,
      );
      final sessionStart = source.indexOf('_controller.startSession(', start);

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
      final serviceStart = source.indexOf('_service.startSession(', start);

      expect(start, isNot(-1));
      expect(contactCheck, isNot(-1));
      expect(firstWarning, isNot(-1));
      expect(serviceStart, isNot(-1));
      expect(contactCheck < firstWarning, isTrue);
      expect(contactCheck < serviceStart, isTrue);
      expect(source, contains('timer_emergency_contact_required'));
      expect(source, contains('ContactsPage'));
    });

    test('both timer flows require typed native arm acknowledgement', () {
      final platform = File(
        'lib/core/services/emergency_platform_service.dart',
      ).readAsStringSync();
      expect(platform, contains('Future<ArmResult> armEmergencySession'));

      final service = File(
        'lib/core/services/check_in_service.dart',
      ).readAsStringSync();
      expect(service, contains('Future<ArmResult> startSession'));
      expect(service, contains('if (result is! Armed) return result;'));

      final checkIn = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      expect(checkIn, contains('final result = await _service.startSession'));
      expect(checkIn, contains('if (result is! Armed)'));

      final safeWalk = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      expect(safeWalk, contains('final result = await _controller.startSession'));
      expect(safeWalk, contains('if (result is! Armed)'));
    });

    test('exact alarm denial is fail-closed and cannot be acknowledged away', () {
      final guard = File(
        'lib/core/widgets/exact_alarm_permission_guard.dart',
      ).readAsStringSync();
      final enTranslations = File(
        'assets/translations/en-US.json',
      ).readAsStringSync();
      expect(guard, contains('canScheduleExactAlarms'));
      expect(guard, contains('requestExactAlarmPermission'));
      expect(guard, contains('barrierDismissible: false'));
      expect(guard, isNot(contains('exact_alarm_degraded_continue')));
      expect(guard, contains('return false;'));
      expect(
        enTranslations,
        contains(
          'This timed action cannot be armed without exact-alarm access.',
        ),
      );

      final checkIn = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      final checkInStart = checkIn.indexOf('Future<void> _startCheckIn');
      final checkInGuard = checkIn.indexOf(
        'requireExactAlarmPermission',
        checkInStart,
      );
      final serviceStart = checkIn.indexOf(
        '_service.startSession(',
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
        'requireExactAlarmPermission',
        safeWalkStart,
      );
      final sessionStart = safeWalk.indexOf(
        '_controller.startSession(',
        safeWalkStart,
      );
      expect(safeWalkGuard, isNot(-1));
      expect(sessionStart, isNot(-1));
      expect(safeWalkGuard < sessionStart, isTrue);
    });

    test('typed countdown has exact plus distinct inexact revocation backup', () {
      final countdown = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      expect(countdown, contains('_scheduleNativeBackupAlarm'));
      expect(countdown, contains('armEmergencySession'));

      final runtime = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/AndroidEmergencySessionRuntime.kt',
      ).readAsStringSync();
      expect(runtime, contains('setExactAndAllowWhileIdle'));
      expect(runtime, contains('setAndAllowWhileIdle'));
      expect(runtime, contains('val exactIntent'));
      expect(runtime, contains('val inexactIntent'));
    });

    test('safe walk guards mounted after the async controller start', () {
      final source = File(
        'lib/screens/safe_walk_screen.dart',
      ).readAsStringSync();
      final startAwait = source.indexOf(
        'final result = await _controller.startSession(',
      );
      final mountedGuard = source.indexOf('if (!mounted) return;', startAwait);
      final failureSurface = source.indexOf(
        '_showArmFailure(result, pinState);',
        startAwait,
      );

      expect(startAwait, isNot(-1));
      expect(mountedGuard, isNot(-1));
      expect(failureSurface, isNot(-1));
      expect(
        mountedGuard < failureSurface,
        isTrue,
        reason: 'mounted must be checked before touching UI after startSession().',
      );
    });
  });
}
