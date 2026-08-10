import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android owns whether notifications are delivered, so the app must not keep
/// a second, disagreeing copy of that answer.
///
/// The settings row was a local switch. A user who denied the OS notification
/// permission still saw it ON, and main_navigation only prompts once, so the
/// app silently promised alerts it could not deliver. On a safety app the thing
/// being promised is the emergency alert.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/settings_page.dart').readAsStringSync();
  });

  test('the notification row opens the system settings screen', () {
    expect(
      source,
      contains('PermissionHelper.openNotificationSettings()'),
      reason:
          'Tapping must hand the decision to Android, which is the only place '
          'it can actually be changed.',
    );
  });

  test('there is no local notification toggle left to disagree with the OS', () {
    expect(
      source.contains('provider.setNotifications'),
      isFalse,
      reason:
          'A switch implies the app controls delivery. It does not; the OS '
          'permission does, and a second copy of that answer can only drift.',
    );
    expect(
      source.contains('value: provider.notificationsEnabled'),
      isFalse,
      reason:
          'Rendering the local preference as the notification state is what '
          'showed ON while Android had the permission denied.',
    );
  });
}
