// Each fix the blocked-arm dialog offers reaches the right screen
// (2026-11-02).
//
// The two Android settings deep links are checked at the channel boundary:
// exact-alarm access through the emergency channel (ExactAlarmSettingsIntent
// natively), the alert channel through the settings channel WITH its id
// (ACTION_CHANNEL_NOTIFICATION_SETTINGS). The rest go through PermissionHelper,
// which branches on dart:io's Platform and so cannot be driven from a host
// test; for those the launcher's defaults are pinned by identity instead, and
// the dialog is shown to hand each remedy to the matching opener.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/arm_remedy.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_result_policy.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/panic_arm_policy.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/core/utils/permission_helper.dart';
import 'package:guvenlik_app/core/widgets/arm_remedy_launcher.dart';
import 'package:guvenlik_app/core/widgets/emergency_failure_dialog.dart';
import 'package:guvenlik_app/screens/pin_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const settingsChannel = MethodChannel('com.poyrazoncel.korubeni/settings');
const platformChannel = MethodChannel(EmergencyPlatformService.channelName);

const token = SessionToken(
  protocolVersion: emergencyProtocolVersion,
  randomId: 'arm-remedy-launcher-test',
  generation: 1,
  kind: EmergencySessionKind.panic,
);

Map<String, dynamic> trCatalogue() =>
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

String tr(String key) => trCatalogue()[key] as String;

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      trCatalogue();
}

class _PinStorage extends SecureStorage {
  _PinStorage(this.pin);

  final Future<String?> Function() pin;

  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? pin() : null;
  @override
  Future<void> write({required String key, required String value}) async {}
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
}

Map<String, Object?> readinessMap({Set<String> missing = const <String>{}}) =>
    <String, Object?>{
      for (final key in const <String>[
        'supportedOs',
        'telephonyCalling',
        'telecomAvailable',
        'dialHandlerAvailable',
        'batteryOptimizationsIgnored',
        'canScheduleExactAlarms',
        'callPermissionGranted',
        'notificationsEnabled',
        'alertChannelHigh',
      ])
        key: !missing.contains(key),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Map<String, Object?> deviceState;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    calls = <MethodCall>[];
    deviceState = readinessMap();
  });

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    Future<Object?> record(MethodCall call) async {
      calls.add(call);
      return switch (call.method) {
        'getDeviceState' => deviceState,
        'canScheduleExactAlarms' => deviceState['canScheduleExactAlarms'],
        _ => true,
      };
    }

    messenger.setMockMethodCallHandler(settingsChannel, record);
    messenger.setMockMethodCallHandler(platformChannel, record);
    addTearDown(() {
      messenger.setMockMethodCallHandler(settingsChannel, null);
      messenger.setMockMethodCallHandler(platformChannel, null);
    });
    late BuildContext captured;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const <Locale>[Locale('tr', 'TR')],
        path: 'assets/translations',
        assetLoader: const _RealTrAssetLoader(),
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  captured = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  group('Android settings deep links', () {
    testWidgets('exact-alarm access opens ExactAlarmSettingsIntent', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      await const ArmRemedyLauncher().apply(context, ArmRemedy.exactAlarm);

      expect(calls.map((call) => call.method), <String>[
        'requestExactAlarmPermission',
      ]);
    });

    testWidgets('the alert channel opens ITS settings, not the app page', (
      tester,
    ) async {
      final context = await pumpHost(tester);

      await const ArmRemedyLauncher().apply(context, ArmRemedy.alertChannel);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'openNotificationChannelSettings');
      expect(calls.single.arguments, <String, Object?>{
        'channelId': 'emergency_alerts',
      });
    });
  });

  test('the defaults are the production paths', () {
    const launcher = ArmRemedyLauncher();
    expect(
      identical(
        launcher.requestCallPermission,
        PermissionHelper.requestCallPhonePermission,
      ),
      isTrue,
      reason: 'CALL_PHONE: the runtime request with its disclosure',
    );
    expect(
      identical(
        launcher.openNotificationSettings,
        PermissionHelper.openNotificationSettings,
      ),
      isTrue,
      reason: 'ACTION_APP_NOTIFICATION_SETTINGS via the settings channel',
    );
    expect(identical(launcher.openContacts, ArmRemedyScreens.contacts), isTrue);
    expect(identical(launcher.openPin, ArmRemedyScreens.pin), isTrue);
    expect(
      identical(launcher.openSubscription, ArmRemedyScreens.subscription),
      isTrue,
    );
  });

  group('the dialog hands each refusal to its opener', () {
    late List<String> opened;

    ArmRemedyLauncher recording() => ArmRemedyLauncher(
      requestCallPermission: (_) async {
        opened.add('callPermission');
        return true;
      },
      openNotificationSettings: () async {
        opened.add('notifications');
        return true;
      },
      openContacts: (_) async => opened.add('contacts'),
      openPin: (_) async => opened.add('pin'),
      openSubscription: (_) async => opened.add('subscription'),
    );

    setUp(() => opened = <String>[]);

    // code, the device state behind it, what the button reads, what it opens.
    final rows = <(String, Set<String>, String, Object)>[
      (
        'entitlementDenied',
        <String>{},
        'panic_fix_subscription',
        'subscription',
      ),
      (
        'entitlementUnknown',
        <String>{},
        'panic_fix_subscription',
        'subscription',
      ),
      ('pinNotConfigured', <String>{}, 'pin_setup_button', 'pin'),
      ('pinReadFailed', <String>{}, 'settings_pin_title', 'pin'),
      ('targetNotCallable', <String>{}, 'select_emergency_contact', 'contacts'),
      (
        'callableTargetMissing',
        <String>{},
        'select_emergency_contact',
        'contacts',
      ),
      ('invalidTarget', <String>{}, 'select_emergency_contact', 'contacts'),
      (
        'exactAlarmDenied',
        <String>{'canScheduleExactAlarms'},
        'background_protection_open',
        const MethodCall('requestExactAlarmPermission'),
      ),
      (
        'exactAlarmScheduleFailed',
        <String>{'canScheduleExactAlarms'},
        'background_protection_open',
        const MethodCall('requestExactAlarmPermission'),
      ),
      // Not dialog refusals (Y-11 keeps them on the dialer countdown), but the
      // dialog walks to them after the alarm access is fixed.
      (
        'callPermissionDenied',
        <String>{'callPermissionGranted'},
        'panic_fix_call_permission',
        'callPermission',
      ),
      (
        'notificationsDisabled',
        <String>{'notificationsEnabled'},
        'open_notification_settings',
        'notifications',
      ),
      (
        'alertChannelNotHigh',
        <String>{'alertChannelHigh'},
        'panic_fix_alert_channel',
        const MethodCall('openNotificationChannelSettings', <String, Object?>{
          'channelId': 'emergency_alerts',
        }),
      ),
    ];

    for (final (code, missing, label, target) in rows) {
      testWidgets('$code -> $label', (tester) async {
        deviceState = readinessMap(missing: missing);
        final context = await pumpHost(tester);
        final refused = ArmRejected(code, rejectedToken: token);
        unawaited(
          EmergencyFailureDialog.show(
            context,
            copy: EmergencyResultPolicy.failureCopy(
              reason: EmergencyFailureReason.armRejected,
              refusal: PanicArmPolicy.refusalFor(refused),
            ),
            phoneNumber: PanicArmPolicy.manualDialNumber(refused, '+905001'),
            remedyLauncher: recording(),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        calls.clear();

        await tester.tap(find.text(tr(label)));
        await tester.pump();

        if (target is MethodCall) {
          expect(
            calls.where((call) => call.method == target.method),
            hasLength(1),
          );
          final call = calls.firstWhere((call) => call.method == target.method);
          expect(call.arguments, target.arguments);
          expect(opened, isEmpty);
        } else {
          expect(opened, <Object>[target]);
        }
      });
    }
  });

  group('PIN: never replaced without the old PIN', () {
    Future<void> openPin(
      WidgetTester tester,
      Future<String?> Function() read,
    ) async {
      final context = await pumpHost(tester);
      unawaited(
        ArmRemedyScreens.pin(
          context,
          pins: PinVerificationService.forTesting(
            secureStorage: _PinStorage(read),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('no PIN yet: PIN creation opens', (tester) async {
      await openPin(tester, () async => null);

      expect(find.byType(PinSetupScreen), findsOneWidget);
    });

    testWidgets('a stored PIN: the change sheet, which asks for the old one', (
      tester,
    ) async {
      await openPin(tester, () async => '4826');

      expect(find.byType(PinSetupScreen), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('an unreadable PIN is treated as stored, not absent', (
      tester,
    ) async {
      await openPin(
        tester,
        () async => throw const FileSystemException('keystore'),
      );

      expect(find.byType(PinSetupScreen), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
