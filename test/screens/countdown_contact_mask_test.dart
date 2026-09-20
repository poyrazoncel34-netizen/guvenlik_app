// A-009: the Quick Settings tile, the home-screen widget and the volume
// trigger all open the countdown WITHOUT the app PIN, and the countdown then
// printed the emergency contact's full name. Someone holding the victim's
// unlocked phone -- the duress scenario itself -- could read who would be
// called without knowing the PIN that protects the rest of the app.
//
// These cases render the real screen with the real Turkish catalogue and read
// what is actually on it, so they fail if the masking stops being applied
// rather than if a particular string stops being grepped.
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
import 'package:guvenlik_app/core/utils/contact_name_mask.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A name with a diacritic and two words: masking must not leak the second
/// word, and must not split a multi-byte first character.
const String kContactName = 'Ayşe Yılmaz';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
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
        name: kContactName,
        phone: '+905001234567',
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
    required bool masked,
  }) async {
    const channel = MethodChannel('countdown-mask-test');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final args =
          (call.arguments as Map<Object?, Object?>).cast<String, Object?>();
      if (call.method == 'armEmergencySession') {
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
              // Not test mode: the rehearsal layout does not render the
              // contact panel at all, so it could not show this defect.
              isTestMode: false,
              entitlementDecision: EntitlementDecision.authorized,
              maskContactIdentity: masked,
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

  String renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');

  group('quick-access countdown', () {
    testWidgets('does not render the contact name', (tester) async {
      await pumpCountdown(tester, masked: true);
      final text = renderedText(tester);
      expect(
        text,
        isNot(contains(kContactName)),
        reason: 'the full name is what the tile disclosed without a PIN',
      );
      expect(
        text,
        isNot(contains('Yılmaz')),
        reason: 'the surname alone is still an identification',
      );
      expect(
        text,
        contains(ContactNameMask.mask(kContactName)),
        reason: 'the user must still see that a contact IS configured',
      );
    });

    testWidgets('the mask does not leak the length of the real name', (
      tester,
    ) async {
      await pumpCountdown(tester, masked: true);
      expect(renderedText(tester), contains('A***'));
    });
  });

  group('the in-app countdown is unchanged', () {
    // The panic button lives behind the app PIN, so masking there would remove
    // information the user is entitled to. This is the control: if it ever
    // goes red, the fix stopped being scoped to the unauthenticated surfaces.
    testWidgets('renders the real contact name', (tester) async {
      await pumpCountdown(tester, masked: false);
      expect(renderedText(tester), contains(kContactName));
    });
  });
}
