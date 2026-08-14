import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android owns whether notifications are delivered, so the app must not keep
/// a second, disagreeing copy of that answer.
///
/// The settings row was once a local switch. A user who denied the OS
/// notification permission still saw it ON, and main_navigation only prompts
/// once, so the app silently promised alerts it could not deliver. On a safety
/// app the thing being promised is the emergency alert.
///
/// The row then opened Android's APP-LEVEL notification screen. That fixed the
/// disagreement but answered only "notifications: on or off", which is not the
/// question MP-23-010 / MP-26-006 ask — a user who wants emergency alerts but
/// not the fake-call notification had no in-app control and no way to find the
/// right OS screen. The row now leads to a per-CATEGORY surface that still
/// holds no local copy: it reads the platform's current answer per channel and
/// links to that channel's own Android screen.
///
/// These assertions therefore moved from "does the row call this one method" to
/// the invariant that method existed to protect, checked across both files.
void main() {
  late String settings;
  late String screen;
  late String prefs;

  setUpAll(() {
    settings = File('lib/screens/settings_page.dart').readAsStringSync();
    screen = File(
      'lib/screens/settings_notifications/notification_categories_screen.dart',
    ).readAsStringSync();
    prefs = File(
      'lib/core/services/notification_preferences_service.dart',
    ).readAsStringSync();
  });

  test('the notification row leads to the per-category surface', () {
    expect(settings, contains('NotificationCategoriesScreen'));
  });

  test('the decision is still handed to Android, now per channel', () {
    expect(prefs, contains('openNotificationChannelSettings'));
    expect(screen, contains('openSettingsFor'));
  });

  test('the surface reads the platform, it does not remember an answer', () {
    expect(prefs, contains('getNotificationChannels'));
    expect(prefs, contains('areSystemNotificationsEnabled'));
    // No local persistence of a delivery switch anywhere on this path.
    for (final source in <String>[settings, screen, prefs]) {
      expect(RegExp(r'setBool\(.*[Nn]otification').hasMatch(source), isFalse,
          reason: 'a stored switch can drift from the OS answer');
    }
  });

  test('there is no local notification toggle left to disagree with the OS', () {
    expect(
      settings.contains('provider.setNotifications'),
      isFalse,
      reason:
          'A switch implies the app controls delivery. It does not; the OS '
          'permission does, and a second copy of that answer can only drift.',
    );
    expect(
      settings.contains('value: provider.notificationsEnabled'),
      isFalse,
      reason:
          'Rendering the local preference as the notification state is what '
          'showed ON while Android had the permission denied.',
    );
    expect(
      screen.contains('Switch('),
      isFalse,
      reason:
          'a Switch on this screen would be a control the app cannot honour; '
          'each row is a link to the place the switch really lives',
    );
  });

  test('a muted safety channel is not rendered like an ordinary one', () {
    expect(screen, contains('isSilencedSafetySurface'));
    expect(screen, contains('notification_status_safety_warning'));
  });
}
