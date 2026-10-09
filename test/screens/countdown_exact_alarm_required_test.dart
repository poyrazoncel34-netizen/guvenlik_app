// Y-11 (chaos audit 2026-10-08, owner decision 2026-10-09): on an API 36 clean
// install exact-alarm access is denied by default. Native refused the arm
// (`exactAlarmDenied`) and the screen ran a dialer-only countdown that looked
// exactly like a protected one; a process death during it called nobody. The
// protected countdown must not start: the user is offered background
// protection (the exact-alarm settings) and a call to the contact now.
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

String tr(String key) => trCatalogue()[key] as String;

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      trCatalogue();
}

class _PinStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? '4826' : null;
  @override
  Future<void> write({required String key, required String value}) async {}
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
}

class _ContactsRepository implements ContactsRepository {
  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async =>
      const EmergencyContact(
        name: 'Test Kisi',
        phone: kContactPhone,
        isPrimary: true,
      );
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
  DateTime wall = DateTime(2026, 10, 9, 12);
  Duration elapsed = Duration.zero;

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => elapsed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage());
    serviceLocator.registerSingleton<ContactsRepository>(_ContactsRepository());
  });

  tearDown(() async => serviceLocator.reset());

  Future<({List<String> calls, List<String> dialled})> pumpRejected(
    WidgetTester tester,
    String reasonCode, {
    _FakeClock? clock,
  }) async {
    final calls = <String>[];
    final dialled = <String>[];
    const channel = MethodChannel('korubeni-test/exact-alarm-required');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'armEmergencySession') {
        return <String, Object?>{'type': 'rejected', 'reasonCode': reasonCode};
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
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
              entitlementDecision: EntitlementDecision.authorized,
              pinVerificationService: PinVerificationService.forTesting(
                secureStorage: _PinStorage(),
              ),
              emergencyPlatformService: EmergencyPlatformService.forTesting(
                methodChannel: channel,
                defaultTimeout: const Duration(milliseconds: 100),
              ),
              dialerOpener: (number) async {
                dialled.add(number);
                return true;
              },
              safetyClock: clock ?? _FakeClock(),
            ),
          ),
        ),
      ),
    );
    // Never pumpAndSettle: the countdown runs an indefinite urgent pulse.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return (calls: calls, dialled: dialled);
  }

  testWidgets('without exact-alarm access the protected countdown does not '
      'start; background protection and a call are offered', (tester) async {
    final clock = _FakeClock();
    final run = await pumpRejected(tester, 'exactAlarmDenied', clock: clock);

    expect(find.text(tr('panic_exact_alarm_required')), findsOneWidget);
    expect(find.text(tr('background_protection_open')), findsOneWidget);
    expect(find.text(tr('emergency_manual_call_now')), findsOneWidget);
    expect(find.textContaining('5001234567'), findsWidgets);

    // The old dialer-only countdown opened the dialer at T+10.
    for (var i = 0; i < 14; i++) {
      clock.elapsed += const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(run.dialled, isEmpty, reason: 'no countdown ran out');
    expect(run.calls, isNot(contains('dispatchEmergencySession')));

    // The settings action goes through the app's real emergency channel.
    final settingsCalls = <String>[];
    const realChannel = MethodChannel(
      'com.poyrazoncel.korubeni/emergency_platform',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      realChannel,
      (call) async {
        settingsCalls.add(call.method);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        realChannel,
        null,
      ),
    );
    await tester.tap(find.text(tr('background_protection_open')));
    await tester.pump();
    expect(settingsCalls, contains('requestExactAlarmPermission'));
    expect(
      find.text(tr('panic_exact_alarm_required')),
      findsOneWidget,
      reason: 'the refusal stays up while the user is in Settings',
    );
  });

  testWidgets('control: a refused CALL_PHONE keeps the dialer countdown', (
    tester,
  ) async {
    final clock = _FakeClock();
    final run = await pumpRejected(
      tester,
      'callPermissionDenied',
      clock: clock,
    );

    expect(find.text(tr('panic_exact_alarm_required')), findsNothing);
    expect(find.text(tr('background_protection_open')), findsNothing);
    for (var i = 0; i < 14; i++) {
      clock.elapsed += const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(run.dialled, isNotEmpty, reason: 'CALL_PHONE refusal still dials');
  });
}
