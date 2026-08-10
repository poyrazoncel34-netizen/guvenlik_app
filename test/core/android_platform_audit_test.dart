// Android Platform Audit Tests
//
// Verifies Android-specific configuration to prevent crashes on real devices.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Platform Audit', () {
    test('generic specialUse foreground service must stay retired', () {
      final file = File('lib/core/services/foreground_service.dart');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'foreground_service.dart must exist',
      );
      final content = file.readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(content, isNot(contains('FlutterBackgroundService')));
      expect(manifest, isNot(contains('FOREGROUND_SERVICE_SPECIAL_USE')));
      expect(manifest, isNot(contains('BackgroundService')));
    });

    test(
      'manifest must NOT declare FOREGROUND_SERVICE_LOCATION (vestigial)',
      () {
        // No service uses foregroundServiceType="location".
        // This vestigial permission triggers Play Store review flags.
        final file = File('android/app/src/main/AndroidManifest.xml');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        expect(
          content,
          isNot(contains('FOREGROUND_SERVICE_LOCATION')),
          reason:
              'FOREGROUND_SERVICE_LOCATION is vestigial — no service uses '
              'location type. Remove to avoid Play Store rejection.',
        );
      },
    );

    test('manifest wires the Direct Boot recovery receiver', () {
      final file = File('android/app/src/main/AndroidManifest.xml');
      final content = file.readAsStringSync();

      expect(content, contains('LOCKED_BOOT_COMPLETED'));
      expect(content, contains('android:directBootAware="true"'));
    });

    test(
      'EmergencyPlatformHandler must NOT reference removed recording service',
      () {
        // The native recording service is not declared in the manifest.
        // EmergencyPlatformHandler must not call it.
        final file = File(
          'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt',
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        final removedService =
            'Recording'
            'SessionService';

        expect(
          content,
          isNot(contains(removedService)),
          reason:
              'The removed recording service is not declared in manifest. '
              'Calling it would crash with IllegalArgumentException.',
        );
      },
    );

    test('typed scheduler must guard exact alarms and arm an inexact backup', () {
      // On Android 14+ (API 34), SCHEDULE_EXACT_ALARM is not auto-granted.
      // Calling setExactAndAllowWhileIdle() without permission throws
      // SecurityException. scheduleAlarm must check and fall back to inexact.
      final file = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/AndroidEmergencySessionRuntime.kt',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      final scheduler = content.substring(
        content.indexOf('class AndroidEmergencySessionAlarmScheduler'),
      );
      // Presence is not order. This used to assert only that the string
      // appeared somewhere in the class, which a permission check placed AFTER
      // the schedule call would also satisfy.
      final guardIndex = scheduler.indexOf('canScheduleExactAlarms');
      final exactIndex = scheduler.indexOf('setExactAndAllowWhileIdle');
      expect(guardIndex, isNot(-1));
      expect(exactIndex, isNot(-1));
      expect(
        guardIndex < exactIndex,
        isTrue,
        reason:
            'scheduleAlarm must check canScheduleExactAlarms before calling '
            'setExactAndAllowWhileIdle to avoid SecurityException on API 34+',
      );
      expect(scheduler, contains('catch (_: SecurityException)'));
      expect(scheduler, contains('setAndAllowWhileIdle'));
    });

    test(
      'EmergencyNotificationHelper must check POST_NOTIFICATIONS on API 33+',
      () {
        // On Android 13+ (API 33), POST_NOTIFICATIONS must be checked before
        // calling notify(), otherwise emergency alerts are silently dropped.
        final file = File(
          'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt',
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // Comments were not stripped here, so the sentence explaining the
        // rule satisfied the rule. Assert on code, and on the actual
        // permission CHECK rather than a mention of the constant.
        final code = content
            .split('\n')
            .where((line) {
              final t = line.trimLeft();
              return !t.startsWith('//') && !t.startsWith('*') &&
                  !t.startsWith('/*');
            })
            .join('\n');
        expect(
          code,
          contains('checkSelfPermission'),
          reason:
              'Must CHECK the POST_NOTIFICATIONS permission before notify() '
              'on Android 13+ to avoid silently dropping emergency alerts',
        );
        expect(code, contains('Manifest.permission.POST_NOTIFICATIONS'));
        expect(
          code,
          contains('PackageManager.PERMISSION_GRANTED'),
          reason: 'A permission query whose result is ignored is not a check.',
        );
      },
    );

    test('SmsSender must not exist in Android Play build', () {
      final file = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/SmsSender.kt',
      );
      expect(
        file.existsSync(),
        isFalse,
        reason: 'SMS delivery is not supported in this Android Play build.',
      );
    });

    test('foreground_service.dart should not use WakelockPlus', () {
      // The active-session status layer is notification-only. Deadline
      // delivery belongs to native alarms; no wakelock belongs here.
      final file = File('lib/core/services/foreground_service.dart');
      final content = file.readAsStringSync();

      expect(
        content,
        isNot(contains('WakelockPlus')),
        reason: 'The status notification layer must not acquire a wakelock.',
      );
    });
  });
}
