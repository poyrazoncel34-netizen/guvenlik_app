// A refused panic must never leave the user at a dead end (2026-11-02).
//
// Native arm (`CapabilitySnapshot.rejectionReason` plus the coordinator) and
// the Dart pre-arm checks refuse a panic for many reasons. Before this test,
// 24 of the 26 rows below -- all but exactAlarmDenied and platformBridgeMissing
// -- reached the blocking failure dialog with "Kapat" as its ONLY button: no
// setting to fix, no call to make. Each row below is one refusal
// code, pumped through the real CountdownScreen, with the actions the user
// MUST be offered there. A refusal the user can fix gets its one-tap fix; one
// nothing on this device can fix still gets the manual call, because Dart
// verified entitlement, PIN and the target before native was asked.
//
// The second group is the return from Settings: the dialog stays up while the
// user is away, so it has to read readiness again when the app resumes and
// offer the NEXT missing capability instead of the one just fixed.
//
// Real CountdownScreen, real Turkish catalogue.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kContactPhone = '+905001234567';

Map<String, dynamic> trCatalogue() =>
    jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>;

/// A key the catalogue does not have renders as a marker, so a missing action
/// fails the row as "not offered" instead of crashing the whole table.
String tr(String key) => (trCatalogue()[key] as String?) ?? '<missing:$key>';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      trCatalogue();
}

enum _Pin { configured, absent, unreadable }

class _PinStorage extends SecureStorage {
  _PinStorage(this.pin);

  final _Pin pin;

  @override
  Future<String?> read({required String key}) async {
    if (key != SecureStorageKeys.userPin) return null;
    return switch (pin) {
      _Pin.configured => '4826',
      _Pin.absent => null,
      _Pin.unreadable => throw const FileSystemException('keystore'),
    };
  }

  @override
  Future<void> write({required String key, required String value}) async {}
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
}

class _ContactsRepository implements ContactsRepository {
  _ContactsRepository({required this.hasPrimary});

  final bool hasPrimary;

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => hasPrimary
      ? const EmergencyContact(
          name: 'Test Kisi',
          phone: kContactPhone,
          isPrimary: true,
        )
      : null;
  @override
  Future<List<String>> getAllEmergencyNumbers() async => const <String>[];
  @override
  Future<List<EmergencyContact>> getContactRecords() async =>
      const <EmergencyContact>[];
  @override
  Future<List<String>> getContacts() async => const <String>[];
  @override
  Future<void> clearPrimaryEmergencyContact() async {}
  @override
  Future<void> saveContactRecords(List<EmergencyContact> contacts) async {}
  @override
  Future<void> saveContacts(List<String> numbers) async {}
  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) async {}
  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {}
}

class _FakeClock implements SafetyClock {
  DateTime wall = DateTime(2026, 11, 2, 12);
  Duration elapsed = Duration.zero;

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => elapsed;
}

/// The actions, by translation key.
const String kCall = 'emergency_manual_call_now';
const String kExactAlarm = 'background_protection_open';
const String kCallPermission = 'panic_fix_call_permission';
const String kNotifications = 'open_notification_settings';
const String kAlertChannel = 'panic_fix_alert_channel';
const String kContact = 'select_emergency_contact';
const String kPinSetup = 'pin_setup_button';
const String kPinSettings = 'settings_pin_title';
const String kSubscription = 'panic_fix_subscription';

/// Every boolean of the native readiness probe, all granted unless named.
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

/// One refusal and what the dialog must offer for it.
class _Row {
  const _Row(
    this.code,
    this.actions, {
    this.missing = const <String>{},
    this.entitlement = EntitlementDecision.authorized,
    this.pin = _Pin.configured,
    this.hasContact = true,
    this.nativeCode = true,
  });

  final String code;
  final List<String> actions;

  /// The readiness flags that are really off on the device for this refusal.
  final Set<String> missing;
  final EntitlementDecision entitlement;
  final _Pin pin;
  final bool hasContact;

  /// False: produced by the Dart pre-arm checks, native is never asked.
  final bool nativeCode;

  /// Authorization and target refusals: a call would bypass the gate.
  bool get mayOfferCall => !_gateRefusals.contains(code);

  String get label => nativeCode ? code : 'dart:$code';
}

const Set<String> _gateRefusals = <String>{
  'entitlementDenied',
  'entitlementUnknown',
  'pinNotConfigured',
  'pinReadFailed',
  'targetNotCallable',
  'callableTargetMissing',
  'invalidTarget',
};

/// Every refusal that reaches the blocking dialog. Literal on purpose: the
/// expectations are not computed by the code under test.
const List<_Row> _blockedRows = <_Row>[
  // CapabilitySnapshot.rejectionReason(), in its own order.
  _Row('unsupportedOs', <String>[kCall], missing: <String>{'supportedOs'}),
  _Row('entitlementDenied', <String>[kSubscription]),
  _Row('entitlementUnknown', <String>[kSubscription]),
  _Row('pinNotConfigured', <String>[kPinSetup]),
  _Row('targetNotCallable', <String>[kContact]),
  _Row(
    'telephonyUnavailable',
    <String>[kCall],
    missing: <String>{'telephonyCalling'},
  ),
  _Row(
    'telecomUnavailable',
    <String>[kCall],
    missing: <String>{'telecomAvailable'},
  ),
  _Row(
    'dialHandlerUnavailable',
    <String>[kCall],
    missing: <String>{'dialHandlerAvailable'},
  ),
  _Row(
    'exactAlarmDenied',
    <String>[kExactAlarm, kCall],
    missing: <String>{'canScheduleExactAlarms'},
  ),
  // EmergencySessionCoordinator / EmergencyPlatformHandler.
  _Row('unsupportedProtocol', <String>[kCall]),
  _Row('invalidRandomId', <String>[kCall]),
  _Row('invalidGeneration', <String>[kCall]),
  _Row('invalidDeadline', <String>[kCall]),
  _Row('invalidKind', <String>[kCall]),
  _Row('invalidTarget', <String>[kContact]),
  _Row('generationMismatch', <String>[kCall]),
  _Row('immutableTargetMismatch', <String>[kCall]),
  _Row('activeSessionExists', <String>[kCall]),
  _Row(
    'exactAlarmScheduleFailed',
    <String>[kExactAlarm, kCall],
    missing: <String>{'canScheduleExactAlarms'},
  ),
  // The Dart channel when the native handler is not registered (A-005).
  _Row('platformBridgeMissing', <String>[kCall]),
  // A code a future native build adds before this table learns it.
  _Row('someFutureRefusal', <String>[kCall]),
  // Dart pre-arm checks.
  _Row(
    'entitlementUnknown',
    <String>[kSubscription],
    entitlement: EntitlementDecision.unknown,
    nativeCode: false,
  ),
  _Row(
    'entitlementDenied',
    <String>[kSubscription],
    entitlement: EntitlementDecision.denied,
    nativeCode: false,
  ),
  _Row(
    'pinNotConfigured',
    <String>[kPinSetup],
    pin: _Pin.absent,
    nativeCode: false,
  ),
  _Row(
    'pinReadFailed',
    <String>[kPinSettings],
    pin: _Pin.unreadable,
    nativeCode: false,
  ),
  _Row(
    'callableTargetMissing',
    <String>[kContact],
    hasContact: false,
    nativeCode: false,
  ),
];

/// Not refusals at the dialog: Y-11 keeps them on the limited-protection
/// countdown that ends in the dialer. They are listed so the table covers
/// every code `rejectionReason()` can return.
const List<String> foregroundDialCodes = <String>[
  'callPermissionDenied',
  'notificationsDisabled',
  'alertChannelNotHigh',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const armChannel = MethodChannel('korubeni-test/no-dead-end');
  const platformChannel = MethodChannel(EmergencyPlatformService.channelName);

  late Map<String, Object?> deviceState;
  late List<String> platformCalls;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    deviceState = readinessMap();
    platformCalls = <String>[];
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> pumpRefused(WidgetTester tester, _Row row) async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage(row.pin));
    serviceLocator.registerSingleton<ContactsRepository>(
      _ContactsRepository(hasPrimary: row.hasContact),
    );
    deviceState = readinessMap(missing: row.missing);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(armChannel, (call) async {
      if (call.method == 'armEmergencySession') {
        return <String, Object?>{'type': 'rejected', 'reasonCode': row.code};
      }
      return null;
    });
    // The app's own emergency channel: readiness probes and the exact-alarm
    // settings both go through it.
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      platformCalls.add(call.method);
      return switch (call.method) {
        'getDeviceState' => deviceState,
        'canScheduleExactAlarms' => deviceState['canScheduleExactAlarms'],
        'requestExactAlarmPermission' => true,
        _ => null,
      };
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(armChannel, null);
      messenger.setMockMethodCallHandler(platformChannel, null);
    });
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
            home: CountdownScreen(
              isTestMode: false,
              entitlementDecision: row.entitlement,
              pinVerificationService: PinVerificationService.forTesting(
                secureStorage: _PinStorage(row.pin),
              ),
              emergencyPlatformService: EmergencyPlatformService.forTesting(
                methodChannel: armChannel,
                defaultTimeout: const Duration(milliseconds: 100),
              ),
              dialerOpener: (_) async => true,
              safetyClock: _FakeClock(),
            ),
          ),
        ),
      ),
    );
    // Never pumpAndSettle: the countdown runs an indefinite urgent pulse.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(AlertDialog), matching: matching);

  /// Everything the dialog offers besides dismissing it.
  Finder dialogActions() => inDialog(
    find.byWidgetPredicate(
      (widget) => widget is ElevatedButton || widget is OutlinedButton,
    ),
  );

  Future<void> returnFromSettings(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  group('no refusal is a dead end', () {
    for (final row in _blockedRows) {
      testWidgets('${row.label} offers ${row.actions.join(' + ')}', (
        tester,
      ) async {
        await pumpRefused(tester, row);

        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: '${row.label} blocks the countdown',
        );
        expect(
          dialogActions(),
          findsWidgets,
          reason: '${row.label}: "Kapat" alone is a dead end',
        );
        for (final action in row.actions) {
          expect(
            inDialog(find.text(tr(action))),
            findsOneWidget,
            reason: '${row.label} must offer $action',
          );
        }
        if (!row.mayOfferCall) {
          expect(
            inDialog(find.text(tr(kCall))),
            findsNothing,
            reason: '${row.label}: a call would bypass the refusing gate',
          );
        }
      });
    }

    for (final code in foregroundDialCodes) {
      testWidgets('$code keeps the limited-protection countdown', (
        tester,
      ) async {
        await pumpRefused(tester, _Row(code, const <String>[]));

        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text(tr('countdown_limited_protection_title')),
          findsOneWidget,
        );
      });
    }
  });

  group('returning from Settings', () {
    testWidgets('the fixed capability disappears and the next missing one is '
        'offered, in native order', (tester) async {
      await pumpRefused(
        tester,
        const _Row(
          'exactAlarmDenied',
          <String>[kExactAlarm, kCall],
          missing: <String>{'canScheduleExactAlarms', 'callPermissionGranted'},
        ),
      );
      expect(inDialog(find.text(tr(kExactAlarm))), findsOneWidget);

      await tester.tap(inDialog(find.text(tr(kExactAlarm))));
      await tester.pump();
      expect(platformCalls, contains('requestExactAlarmPermission'));

      // The user turned the alarm access on in Settings and came back.
      deviceState = readinessMap(missing: <String>{'callPermissionGranted'});
      await returnFromSettings(tester);

      expect(
        inDialog(find.text(tr(kExactAlarm))),
        findsNothing,
        reason: 'the alarm access is on now; offering it again misleads',
      );
      expect(
        inDialog(find.text(tr(kCallPermission))),
        findsOneWidget,
        reason: 'CALL_PHONE is the next refusal in native order',
      );
      expect(inDialog(find.text(tr(kCall))), findsOneWidget);

      // Everything granted: nothing left to fix, the call stays.
      deviceState = readinessMap();
      await returnFromSettings(tester);
      expect(inDialog(find.text(tr(kCallPermission))), findsNothing);
      expect(inDialog(find.text(tr(kExactAlarm))), findsNothing);
      expect(inDialog(find.text(tr(kCall))), findsOneWidget);
    });

    testWidgets('notifications and the alert channel follow CALL_PHONE', (
      tester,
    ) async {
      await pumpRefused(
        tester,
        const _Row(
          'exactAlarmDenied',
          <String>[kExactAlarm, kCall],
          missing: <String>{
            'canScheduleExactAlarms',
            'notificationsEnabled',
            'alertChannelHigh',
          },
        ),
      );

      deviceState = readinessMap(
        missing: <String>{'notificationsEnabled', 'alertChannelHigh'},
      );
      await returnFromSettings(tester);
      expect(inDialog(find.text(tr(kNotifications))), findsOneWidget);
      expect(inDialog(find.text(tr(kAlertChannel))), findsNothing);

      deviceState = readinessMap(missing: <String>{'alertChannelHigh'});
      await returnFromSettings(tester);
      expect(inDialog(find.text(tr(kNotifications))), findsNothing);
      expect(inDialog(find.text(tr(kAlertChannel))), findsOneWidget);
    });
  });
}
