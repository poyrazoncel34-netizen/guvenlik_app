// Android Platform Audit Tests
//
// Verifies Android-specific configuration to prevent crashes on real devices.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Platform Audit', () {
    test('foreground_service.dart must use specialUse type to match manifest',
        () {
      // The AndroidManifest.xml declares BackgroundService with
      // android:foregroundServiceType="specialUse". The Dart config must
      // match, otherwise Android 14+ throws
      // ForegroundServiceTypeNotAllowedException.
      final file = File('lib/core/services/foreground_service.dart');
      expect(file.existsSync(), isTrue,
          reason: 'foreground_service.dart must exist');
      final content = file.readAsStringSync();

      expect(content, contains('AndroidForegroundType.specialUse'),
          reason:
              'Dart foreground service type must be specialUse to match manifest');
      expect(content, isNot(contains('AndroidForegroundType.dataSync')),
          reason:
              'dataSync type will crash on Android 14+ (manifest declares specialUse)');
    });

    test('manifest must NOT declare FOREGROUND_SERVICE_LOCATION (vestigial)',
        () {
      // No service uses foregroundServiceType="location".
      // This vestigial permission triggers Play Store review flags.
      final file = File('android/app/src/main/AndroidManifest.xml');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, isNot(contains('FOREGROUND_SERVICE_LOCATION')),
          reason:
              'FOREGROUND_SERVICE_LOCATION is vestigial — no service uses '
              'location type. Remove to avoid Play Store rejection.');
    });

    test('manifest must NOT listen for LOCKED_BOOT_COMPLETED (dead code)', () {
      // BootCompletedReceiver is not directBootAware and uses
      // credential-protected storage. LOCKED_BOOT_COMPLETED is never
      // delivered by the system without directBootAware="true".
      final file = File('android/app/src/main/AndroidManifest.xml');
      final content = file.readAsStringSync();

      expect(content, isNot(contains('LOCKED_BOOT_COMPLETED')),
          reason:
              'LOCKED_BOOT_COMPLETED requires directBootAware="true" and '
              'device-protected storage. Without these, the intent is never delivered.');
    });

    test('EmergencyPlatformHandler must NOT reference RecordingSessionService',
        () {
      // RecordingSessionService was removed from the manifest but
      // EmergencyPlatformHandler still calls it, causing a crash
      // (IllegalArgumentException: unable to find explicit activity class).
      final file = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, isNot(contains('RecordingSessionService')),
          reason:
              'RecordingSessionService is not declared in manifest. '
              'Calling it crashes with IllegalArgumentException.');
    });

    test('CheckInScheduler must guard scheduleAlarm with canScheduleExactAlarms',
        () {
      // On Android 14+ (API 34), SCHEDULE_EXACT_ALARM is not auto-granted.
      // Calling setExactAndAllowWhileIdle() without permission throws
      // SecurityException. scheduleAlarm must check and fall back to inexact.
      final file = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInScheduler.kt',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // The private scheduleAlarm function must include a fallback to
      // setAndAllowWhileIdle (inexact) when exact alarms are not permitted.
      final scheduleAlarmBody = content.substring(
        content.indexOf('private fun scheduleAlarm'),
      );
      expect(scheduleAlarmBody, contains('canScheduleExactAlarms'),
          reason:
              'scheduleAlarm must check canScheduleExactAlarms before calling '
              'setExactAndAllowWhileIdle to avoid SecurityException on API 34+');
    });

    test('EmergencyNotificationHelper must check POST_NOTIFICATIONS on API 33+',
        () {
      // On Android 13+ (API 33), POST_NOTIFICATIONS must be checked before
      // calling notify(), otherwise emergency alerts are silently dropped.
      final file = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('POST_NOTIFICATIONS'),
          reason:
              'Must check POST_NOTIFICATIONS permission before notify() '
              'on Android 13+ to avoid silently dropping emergency alerts');
    });


    test('foreground_service.dart should not use WakelockPlus', () {
      // WakelockPlus is a screen-on wakelock. flutter_background_service
      // already acquires a PARTIAL_WAKE_LOCK. Screen-on wakelock is
      // unnecessary for background services and wastes battery.
      final file = File('lib/core/services/foreground_service.dart');
      final content = file.readAsStringSync();

      expect(content, isNot(contains('WakelockPlus')),
          reason:
              'WakelockPlus (screen-on) is unnecessary — '
              'flutter_background_service already holds a partial wakelock');
    });
  });
}
