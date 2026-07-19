import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';

void main() {
  test('native device state exposes every critical notification capability', () {
    final handler = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt',
    ).readAsStringSync();

    expect(handler, contains('notificationsEnabled'));
    expect(handler, isNot(contains('canUseFullScreenIntent')));
    expect(handler, isNot(contains('notificationPolicyAccessGranted')));
  });

  test('Dart readiness requires both notification delivery capabilities', () {
    const base = PlatformReadinessSnapshot(
      supportedOs: true,
      telephonyCalling: true,
      telecomAvailable: true,
      dialHandlerAvailable: true,
      batteryOptimizationWhitelisted: true,
      exactAlarmPermission: true,
      callPermission: true,
      notificationPermission: true,
      alertChannelHigh: true,
    );
    const notificationsDisabled = PlatformReadinessSnapshot(
      supportedOs: true,
      telephonyCalling: true,
      telecomAvailable: true,
      dialHandlerAvailable: true,
      batteryOptimizationWhitelisted: true,
      exactAlarmPermission: true,
      callPermission: true,
      notificationPermission: false,
      alertChannelHigh: true,
    );
    const lowImportanceChannel = PlatformReadinessSnapshot(
      supportedOs: true,
      telephonyCalling: true,
      telecomAvailable: true,
      dialHandlerAvailable: true,
      batteryOptimizationWhitelisted: true,
      exactAlarmPermission: true,
      callPermission: true,
      notificationPermission: true,
      alertChannelHigh: false,
    );

    expect(base.backgroundAlertReady, isTrue);
    expect(notificationsDisabled.backgroundAlertReady, isFalse);
    expect(lowImportanceChannel.backgroundAlertReady, isFalse);
    expect(notificationsDisabled.criticalSafetyReady, isFalse);
    expect(lowImportanceChannel.criticalSafetyReady, isFalse);
  });

  test('notification helper never claims DND bypass without policy access', () {
    final helper = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt',
    ).readAsStringSync();

    expect(helper, isNot(contains('setBypassDnd(true)')));
  });

  test('native alert posting returns an observable outcome', () {
    final helper = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyNotificationHelper.kt',
    ).readAsStringSync();

    expect(helper, contains('): Boolean'));
    expect(helper, contains('return false'));
    expect(helper, contains('return true'));
    expect(helper, contains('SecurityException'));
  });
}
