// Accessibility guideline coverage for CountdownScreen -- the fourth screen
// promised by REMEDIATION_PLAN.md Batch 4 and left uncovered when
// INDEPENDENT_REVIEW.md IR-03 was filed.
//
// It was previously described as "not renderable in a widget harness". That was
// wrong: countdown_dispose_lifecycle_test.dart already pumps it behind a mocked
// platform channel. This file reuses that harness and adds the REAL Turkish
// catalogue, so the matchers assert against user-facing copy rather than raw
// localization keys.
//
// This is the screen a user sees while an emergency is counting down. A control
// here that is unlabelled or too small to hit is the worst possible place for
// one.

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
        name: 'Primary',
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

/// Fails if raw localization keys reach the tree -- the IR-03 vacuity guard.
void assertRealCopyRendered(WidgetTester tester) {
  final leaked = <String>[];
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final d = t.data;
    if (d == null || d.isEmpty) continue;
    if (RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(d)) leaked.add(d);
  }
  expect(
    leaked,
    isEmpty,
    reason:
        'Raw localization keys reached the countdown tree: $leaked. Every '
        'accessible-name assertion would then pass on the key string.',
  );
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
    bool isTestMode = false,
  }) async {
    const channel = MethodChannel('countdown-a11y-test');
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

    final platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 100),
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
              isTestMode: isTestMode,
              entitlementDecision: EntitlementDecision.authorized,
              pinVerificationService: PinVerificationService.forTesting(
                secureStorage: _PinStorage(),
              ),
              emergencyPlatformService: platform,
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

  testWidgets('renders real Turkish copy, not localization keys', (
    tester,
  ) async {
    await pumpCountdown(tester, isTestMode: true);
    expect(find.byType(Text), findsWidgets);
    assertRealCopyRendered(tester);
  });

  testWidgets('every tappable control meets the minimum tap target size', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCountdown(tester, isTestMode: true);
    assertRealCopyRendered(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('every tappable control exposes an accessible name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCountdown(tester, isTestMode: true);
    assertRealCopyRendered(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
