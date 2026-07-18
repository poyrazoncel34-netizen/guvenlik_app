import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native device state exposes every critical notification capability', () {
    final handler = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt',
    ).readAsStringSync();

    expect(handler, contains('notificationsEnabled'));
    expect(handler, isNot(contains('canUseFullScreenIntent')));
    expect(handler, isNot(contains('notificationPolicyAccessGranted')));
  });

  test('Dart readiness keeps required and enhanced capabilities distinct', () {
    final readiness = File(
      'lib/core/services/emergency_readiness_service.dart',
    ).readAsStringSync();

    expect(readiness, contains('notificationPermission'));
    expect(readiness, isNot(contains('fullScreenIntentPermission')));
    expect(readiness, isNot(contains('notificationPolicyAccess')));
    expect(readiness, contains('backgroundAlertReady'));
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
