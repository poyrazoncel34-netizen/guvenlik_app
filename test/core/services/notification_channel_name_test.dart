// N-01 -- notification channel names must never be a raw translation key.
//
// `NotificationService.initialize()` runs in main.dart's pre-runApp startup
// block. At that point `EasyLocalization.ensureInitialized()` has run, but the
// EasyLocalization *delegate* has not loaded the asset bundle yet -- that only
// happens once the widget tree builds. `.tr()` in that window returns the KEY
// it was given.
//
// Android persists a channel's name when the channel is first created, so an
// unguarded lookup permanently labels the channel with a raw key. It was
// observed on a booted emulator (API 36, commit 29757f5): the app's own log
// reported `Localization key [notification_channel_emergency_name] not found`
// for all three channels -- including the EMERGENCY channel that the Check-In
// grace warning posts to.
//
// This measures BEHAVIOUR: it captures what the plugin was actually asked to
// create, with no translations loaded, which is precisely the startup window.

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final created = <Map<Object?, Object?>>[];

  setUpAll(() {
    // The host test platform registers no implementation, so
    // resolvePlatformSpecificImplementation<Android...> would throw before any
    // channel is created. Register the real Android implementation and let the
    // mocked MethodChannel above stand in for the OS.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() {
    created.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'createNotificationChannel') {
            created.add(call.arguments as Map<Object?, Object?>);
          }
          // `initialize` is typed Future<bool>; returning null would fail with
          // a type error before any channel is created.
          if (call.method == 'initialize') return true;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('no channel is created with its translation key as the name', () async {
    // Deliberately NOT initializing EasyLocalization: this reproduces the real
    // pre-runApp window rather than a state the startup path never sees.
    await NotificationService.instance.initialize();

    expect(
      created,
      isNotEmpty,
      reason:
          'The mock captured no createNotificationChannel call, so this test '
          'would pass without ever exercising the thing it claims to check.',
    );

    for (final arguments in created) {
      final id = arguments['id'];
      final name = arguments['name'] as String?;
      final description = arguments['description'] as String?;

      expect(
        name,
        isNotNull,
        reason: 'channel $id was created without a name',
      );
      expect(
        name,
        isNot(startsWith('notification_channel_')),
        reason:
            'channel $id would show the raw key "$name" in Android settings. '
            'Guard the lookup with a literal fallback, the way '
            'foreground_service.dart already does.',
      );
      expect(
        description,
        isNot(startsWith('notification_channel_')),
        reason: 'channel $id description fell back to a raw key',
      );
      expect(name, isNotEmpty, reason: 'channel $id got an empty name');
    }
  });
}
