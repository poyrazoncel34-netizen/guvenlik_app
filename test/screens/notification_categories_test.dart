// MP-11-014 / MP-23-010 / MP-26-006 -- the notification surfaces.
//
// Three requirements, one surface, deliberately: the audit's own remediation
// note said "one preference surface serves both rows", and the third (feedback)
// is what makes the surface honest rather than decorative.
//
// The assertions below are about what the user is TOLD. A screen that renders a
// tidy grey toggle for "emergency alerts: off" would satisfy a checklist and
// mislead the person the app exists for, so the muted-safety case is asserted
// separately from the muted-anything-else case.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/notification_preferences_service.dart';
import 'package:guvenlik_app/core/services/notification_service.dart';
import 'package:guvenlik_app/screens/settings_notifications/notification_categories_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

Map<String, String> _catalogue() =>
    (jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
            as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));

/// A stand-in for the platform, so every OS state can be driven.
class _FakeService implements NotificationPreferencesService {
  _FakeService(this.states);

  final List<NotificationCategoryState> states;
  final List<NotificationCategory> opened = <NotificationCategory>[];
  bool throwOnRead = false;

  @override
  Future<List<NotificationCategoryState>> readAll() async {
    if (throwOnRead) throw Exception('platform unavailable');
    return states;
  }

  @override
  Future<bool> openSettingsFor(NotificationCategory category) async {
    opened.add(category);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationCategoryState _state(
  NotificationCategory category, {
  bool appLevelEnabled = true,
  bool channelExists = true,
  Importance? importance = Importance.max,
}) => NotificationCategoryState(
  category: category,
  appLevelEnabled: appLevelEnabled,
  channelExists: channelExists,
  channelImportance: importance,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  group('the state model answers from the platform, not from a local copy', () {
    test('permission granted + channel live = delivered', () {
      expect(_state(NotificationCategory.emergencyAlert).willBeDelivered,
          isTrue);
    });

    test('permission revoked at OS level = NOT delivered', () {
      final state = _state(NotificationCategory.emergencyAlert,
          appLevelEnabled: false);
      expect(state.willBeDelivered, isFalse);
      expect(state.isSilencedSafetySurface, isTrue);
    });

    test('channel muted while permission is granted = NOT delivered', () {
      final state = _state(NotificationCategory.emergencyAlert,
          importance: Importance.none);
      expect(state.channelMuted, isTrue);
      expect(state.willBeDelivered, isFalse);
    });

    test('a non-safety category muted is NOT flagged as a safety silence', () {
      final state =
          _state(NotificationCategory.general, importance: Importance.none);
      expect(state.willBeDelivered, isFalse);
      expect(state.isSilencedSafetySurface, isFalse,
          reason: 'flagging everything the same way makes the flag useless');
    });

    test('a channel that has not been created yet is not reported as muted',
        () {
      final state = _state(NotificationCategory.general,
          channelExists: false, importance: null);
      expect(state.channelMuted, isFalse);
    });

    test('every category names a real Android channel', () {
      const known = <String>{
        kEmergencyAlertsChannelId,
        kServiceStatusChannelId,
        kGeneralNotificationsChannelId,
      };
      for (final category in NotificationCategory.values) {
        expect(known, contains(category.channelId), reason: category.name);
      }
    });

    test('every category has distinct title and description keys', () {
      final keys = <String>{};
      for (final category in NotificationCategory.values) {
        expect(keys.add(category.titleKey), isTrue);
        expect(keys.add(category.descriptionKey), isTrue);
      }
    });

    test('the projection carries what a diagnostics reader needs', () {
      final map = _state(NotificationCategory.emergencyAlert).toMap();
      expect(map['category'], 'emergencyAlert');
      expect(map['channelId'], kEmergencyAlertsChannelId);
      expect(map['willBeDelivered'], isTrue);
      expect(map['safetyCritical'], isTrue);
    });
  });

  group('the screen tells the truth', () {
    Future<_FakeService> pump(
      WidgetTester tester,
      List<NotificationCategoryState> states, {
      bool throwOnRead = false,
    }) async {
      final service = _FakeService(states)..throwOnRead = throwOnRead;
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const <Locale>[Locale('tr', 'TR')],
          path: 'assets/translations',
          fallbackLocale: const Locale('tr', 'TR'),
          assetLoader: const _RealTrAssetLoader(),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: EasyLocalization.of(context)!.locale,
              supportedLocales: EasyLocalization.of(context)!.supportedLocales,
              localizationsDelegates: EasyLocalization.of(context)!.delegates,
              home: NotificationCategoriesScreen(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    List<String> rendered(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    testWidgets('every category is named with its purpose', (tester) async {
      final catalogue = _catalogue();
      await pump(
        tester,
        NotificationCategory.values.map(_state).toList(growable: false),
      );
      final texts = rendered(tester);
      for (final category in NotificationCategory.values) {
        expect(texts, contains(catalogue[category.titleKey]),
            reason: category.name);
        expect(texts, contains(catalogue[category.descriptionKey]),
            reason: category.name);
      }
    });

    testWidgets('a muted SAFETY category names its consequence', (tester) async {
      final catalogue = _catalogue();
      await pump(tester, <NotificationCategoryState>[
        _state(NotificationCategory.emergencyAlert,
            importance: Importance.none),
      ]);
      final texts = rendered(tester);
      expect(texts, contains(catalogue['notification_status_channel_muted']));
      expect(
        texts,
        contains(catalogue['notification_status_safety_warning']),
        reason: 'a muted emergency channel must not read like a muted '
            'marketing channel',
      );
    });

    testWidgets('a muted ordinary category does NOT raise the safety warning',
        (tester) async {
      final catalogue = _catalogue();
      await pump(tester, <NotificationCategoryState>[
        _state(NotificationCategory.general, importance: Importance.none),
      ]);
      expect(rendered(tester),
          isNot(contains(catalogue['notification_status_safety_warning'])));
    });

    testWidgets('a revoked OS permission is reported as such', (tester) async {
      final catalogue = _catalogue();
      await pump(tester, <NotificationCategoryState>[
        _state(NotificationCategory.emergencyAlert, appLevelEnabled: false),
      ]);
      expect(rendered(tester),
          contains(catalogue['notification_status_app_blocked']));
    });

    testWidgets('a read failure is shown, never rendered as healthy',
        (tester) async {
      final catalogue = _catalogue();
      await pump(tester, const <NotificationCategoryState>[],
          throwOnRead: true);
      final texts = rendered(tester);
      expect(texts, contains(catalogue['notification_categories_read_failed']));
      expect(texts,
          isNot(contains(catalogue['notification_status_delivered'])));
    });

    testWidgets('tapping a category opens THAT category in Android settings',
        (tester) async {
      final catalogue = _catalogue();
      final service = await pump(tester, <NotificationCategoryState>[
        _state(NotificationCategory.emergencyAlert),
        _state(NotificationCategory.fakeCall),
      ]);
      await tester.tap(
        find.text(catalogue['notification_category_fake_call']!),
      );
      await tester.pumpAndSettle();
      expect(service.opened, <NotificationCategory>[
        NotificationCategory.fakeCall,
      ]);
    });

    testWidgets('each row is one screen-reader node with its status',
        (tester) async {
      final catalogue = _catalogue();
      await pump(tester, <NotificationCategoryState>[
        _state(NotificationCategory.emergencyAlert,
            importance: Importance.none),
      ]);
      expect(
        find.bySemanticsLabel(RegExp(
          '${RegExp.escape(catalogue['notification_category_emergency']!)}.*'
          '${RegExp.escape(catalogue['notification_status_channel_muted']!)}',
        )),
        findsOneWidget,
      );
    });

    testWidgets('no raw localization key reaches the tree', (tester) async {
      await pump(
        tester,
        NotificationCategory.values.map(_state).toList(growable: false),
      );
      final leaked = rendered(tester)
          .where((d) => RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(d))
          .toList();
      expect(leaked, isEmpty);
    });

    testWidgets('every row clears the 48 dp interactive box', (tester) async {
      await pump(
        tester,
        NotificationCategory.values.map(_state).toList(growable: false),
      );
      final taps = find.byType(InkWell);
      expect(taps, findsNWidgets(NotificationCategory.values.length));
      for (var i = 0; i < NotificationCategory.values.length; i++) {
        // GLOBAL coordinates, per the project's definition of done.
        final rect = tester.getRect(taps.at(i));
        expect(rect.height, greaterThanOrEqualTo(48.0));
        expect(rect.width, greaterThanOrEqualTo(48.0));
      }
    });
  });

  group('a notification tap uses the SAME gate as a deep link', () {
    late String source;

    setUpAll(() {
      source = File('lib/core/services/notification_service.dart')
          .readAsStringSync();
    });

    test('in-app destinations are parked, not pushed', () {
      expect(source, contains('PendingDestinationService.instance.submitDestination'));
      expect(source, contains('ExternalEntrySource.notification'));
    });

    test('the payload is matched against an allowlist, never parsed as a route',
        () {
      expect(source, contains('payloadDestinations'));
      for (final parsed in <String>['Uri.parse(payload', 'payload.split(']) {
        expect(source, isNot(contains(parsed)),
            reason: 'a payload survives a reboot in Android\'s own store and '
                'comes back verbatim; it is untrusted input');
      }
    });

    test('the fake-call exception is NAMED, and is the only direct push', () {
      final start = source.indexOf('void _handleNotificationResponse');
      final body = source.substring(start, source.indexOf('\n  }', start));
      expect(body, contains('THE NAMED EXCEPTION'));
      expect('navigator.push('.allMatches(body), hasLength(1),
          reason: 'a second direct push would be a second, ungated path');
      expect(body, contains('FakeCallScreen'));
    });

    test('the alert poster reports suppression instead of returning silently',
        () {
      expect(source, contains('DispatchTargetOutcome.suppressedByUserSetting'));
      expect(source, contains('DispatchTargetOutcome.permissionDenied'));
      expect(source, contains('areSystemNotificationsEnabled'));
    });
  });
}
