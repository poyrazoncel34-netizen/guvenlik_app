import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('security and reliability contracts', () {
    test('cold start with configured PIN routes to AppUnlockScreen first', () {
      final splash = File('lib/screens/splash_screen.dart').readAsStringSync();
      expect(splash, contains('await _hasConfiguredPin()'));
      expect(splash, contains('AppUnlockScreen'));
      expect(splash, contains('pushReplacement'));
    });

    test('delayed fake call no longer uses Future.delayed navigation', () {
      final home = File('lib/screens/home_page.dart').readAsStringSync();
      expect(home, contains('NotificationService.instance.scheduleFakeCall'));
      final delayedFakeCallRegion = home.substring(
        home.indexOf('Widget _buildFakeCallOption'),
        home.indexOf('Widget _buildOnboardingCard'),
      );
      expect(delayedFakeCallRegion, isNot(contains('Future.delayed(delay')));
    });

    test(
      'delayed fake call checks notification permission at point of use',
      () {
        final home = File('lib/screens/home_page.dart').readAsStringSync();
        final scheduleRegion = home.substring(
          home.indexOf('Future<void> _scheduleDelayedFakeCall'),
          home.indexOf('Widget _buildOnboardingCard'),
        );

        expect(
          scheduleRegion,
          contains('ensureNotificationPermissionForScheduledAction(context)'),
        );
        expect(
          scheduleRegion,
          contains('delayed_fake_call_notification_permission_required'),
        );
        expect(scheduleRegion, contains('open_notification_settings'));
      },
    );

    test(
      'delayed fake call prefers exact alarm but falls back to inexact when '
      'the exact-alarm permission is unavailable (S9 / D7)',
      () {
        final notif = File(
          'lib/core/services/notification_service.dart',
        ).readAsStringSync();
        // D7: prefer exact for on-time delivery, but fall back to inexact when
        // the Android 12+ exact-alarm permission is denied (exact would throw
        // SecurityException and drop the call entirely). The choice is gated on
        // canScheduleExactAlarms().
        expect(notif, contains('AndroidScheduleMode.exactAllowWhileIdle'));
        expect(notif, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
        expect(notif, contains('canScheduleExactAlarms()'));

        final home = File('lib/screens/home_page.dart').readAsStringSync();
        final scheduleRegion = home.substring(
          home.indexOf('Future<void> _scheduleDelayedFakeCall'),
          home.indexOf('Widget _buildOnboardingCard'),
        );
        // The exact-alarm permission guard must run before scheduling.
        expect(
          scheduleRegion,
          contains('confirmExactAlarmPermissionOrDegraded('),
        );
        expect(
          scheduleRegion.indexOf('confirmExactAlarmPermissionOrDegraded('),
          lessThan(scheduleRegion.indexOf('scheduleFakeCall(')),
        );
      },
    );

    test('BootCompletedReceiver restores only active sessions', () {
      final receiver = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/BootCompletedReceiver.kt',
      ).readAsStringSync();
      expect(receiver, contains('Intent.ACTION_BOOT_COMPLETED'));
      expect(receiver, contains('CheckInScheduler.hasActiveSession(context)'));
      expect(receiver, isNot(contains('startForegroundService')));
    });
  });
}
