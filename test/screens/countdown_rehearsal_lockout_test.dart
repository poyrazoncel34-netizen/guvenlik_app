// Y-06 (chaos audit 2026-10-08): the rehearsal keypad COUNTED wrong PINs into
// the real lockout but never ASKED it. On an API 35 emulator five rehearsal
// misses locked the app ("Kilitli: 17s" at the unlock screen), and the same
// rehearsal keypad then accepted the correct PIN during that lockout -- an
// unthrottled PIN oracle for whoever holds the unlocked phone. A rehearsal has
// no call to stop, so honouring the lockout there costs the owner nothing.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _PinStorage extends SecureStorage {
  final Map<String, String> values = <String, String>{};
  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? '4826' : values[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<void> deleteAll() async => values.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('countdown-rehearsal-lockout');
  late List<String> nativeCalls;
  late _PinStorage storage;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    storage = _PinStorage();
    serviceLocator.registerSingleton<SecureStorage>(storage);
    nativeCalls = <String>[];
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> pumpRehearsal(WidgetTester tester) async {
    // A phone-sized surface: on the default 800x600 the keypad is off-screen
    // and every tap would silently miss.
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call.method);
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
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CountdownScreen(
                      isTestMode: true,
                      entitlementDecision: EntitlementDecision.authorized,
                      pinVerificationService: PinVerificationService.forTesting(
                        secureStorage: _PinStorage(),
                      ),
                      emergencyPlatformService: platform,
                    ),
                  ),
                ),
                child: const Text('rehearse'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.tap(find.text('rehearse'));
    // Never pumpAndSettle: the countdown runs an indefinite urgent pulse.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a locked-out rehearsal keypad does not verify, even the right '
      'PIN', (tester) async {
    final handle = tester.ensureSemantics();
    final until = DateTime.now().add(const Duration(minutes: 5));
    storage.values['pin_lockout_failed_attempts'] = '5';
    storage.values['pin_lockout_until_ms'] = '${until.millisecondsSinceEpoch}';
    await pumpRehearsal(tester);
    for (final digit in '4826'.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump();
    }
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byType(CountdownScreen),
      findsOneWidget,
      reason: 'the lockout was ignored: the right PIN ended the rehearsal',
    );
    expect(
      storage.values['pin_lockout_until_ms'],
      '${until.millisecondsSinceEpoch}',
      reason: 'a refused attempt must not reset the lockout',
    );
    handle.dispose();
  });

  testWidgets('an unreadable lockout counter refuses a rehearsal PIN too', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    storage.values['pin_lockout_failed_attempts'] = 'not-a-number';
    await pumpRehearsal(tester);
    for (final digit in '4826'.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump();
    }
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CountdownScreen), findsOneWidget);
    handle.dispose();
  });

  testWidgets('without a lockout the right PIN still ends a rehearsal', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRehearsal(tester);
    for (final digit in '4826'.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump();
    }
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CountdownScreen), findsNothing);
    handle.dispose();
  });
}
