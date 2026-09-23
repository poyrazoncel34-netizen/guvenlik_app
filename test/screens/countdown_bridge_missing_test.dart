// A-005: when MainActivity fails to install the emergency MethodChannel, the
// arm call raises MissingPluginException. That used to become ArmUnknown, so
// the countdown STARTED -- visually identical to a protected one, with no
// native AlarmManager session behind it -- and the PIN cancel then crossed the
// same missing bridge and could never be confirmed.
//
// These cases render the real CountdownScreen with the real Turkish catalogue.
//
// The absent bridge answers every message with a null reply envelope, which is
// exactly what the engine sends for a channel with no registered handler;
// MethodChannel itself turns that into MissingPluginException. A bare
// unregistered name is not enough inside testWidgets: the engine's reply rides
// the real event loop, which FakeAsync does not drive, so the 100 ms arm
// timeout fires first and the case under test is never reached.
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

  Future<void> pumpCountdown(
    WidgetTester tester, {
    required MethodChannel channel,
  }) async {
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

  testWidgets('a missing bridge blocks the countdown and offers a manual call', (
    tester,
  ) async {
    const channel = MethodChannel('korubeni-test/bridge-never-registered');
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      channel.name,
      (ByteData? message) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel.name,
        null,
      ),
    );

    await pumpCountdown(tester, channel: channel);

    expect(
      find.text(tr('safety_session_not_ready')),
      findsOneWidget,
      reason:
          'without it the countdown ran on as if protected: no native session, '
          'and a PIN cancel that could never be confirmed',
    );
    expect(
      find.text(tr('emergency_manual_call_now')),
      findsOneWidget,
      reason: 'the user must still be one tap from the system dialer',
    );
    expect(find.textContaining('5001234567'), findsWidgets);
  });

  testWidgets('control: a registered bridge arms and shows no failure', (
    tester,
  ) async {
    const channel = MethodChannel('korubeni-test/bridge-registered');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method != 'armEmergencySession') return null;
      final args = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      return <String, Object?>{
        'type': 'armed',
        'token': <String, Object?>{
          'protocolVersion': args['protocolVersion'],
          'randomId': args['randomId'],
          'generation': args['requestedGeneration'],
          'kind': args['kind'],
        },
        'mainDeadlineMs': args['mainDeadlineMs'],
        'finalDeadlineMs': args['finalDeadlineMs'],
      };
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await pumpCountdown(tester, channel: channel);

    expect(find.text(tr('safety_session_not_ready')), findsNothing);
    expect(find.text(tr('emergency_manual_call_now')), findsNothing);
  });
}
