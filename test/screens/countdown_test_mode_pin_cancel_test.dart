// Test Mode is the rehearsal the home screen offers ("Test Modu gerçek arama
// yapmaz -- dokunup deneyebilirsin"). It must rehearse the one thing a user
// has to be able to do under stress: cancel with the PIN.
//
// Since 6e47a6b the PIN state was loaded only for real sessions, so a
// rehearsal sat in PinState.loading for its whole ten seconds: no keypad, and
// "Güvenlik PIN'i doğrulanıyor…" on screen although nothing was being verified
// (observed on an API 35 emulator). The accessibility tests that pump Test
// Mode kept passing because there was no keypad left to measure.

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
import 'package:guvenlik_app/core/services/local_database_service.dart';
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

class _MemoryDatabaseService extends LocalDatabaseService {
  _MemoryDatabaseService(this.db);
  final Database db;
  @override
  Future<Database> get database async => db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('countdown-test-mode-pin');
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

  /// Polls, bounded, until PIN verification has visibly finished: the screen
  /// left (match) or the keypad was cleared and a lockout failure recorded.
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump();
    }
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CountdownScreen).evaluate().isEmpty ||
          storage.values.containsKey('pin_lockout_failed_attempts')) {
        return;
      }
    }
  }

  testWidgets('a rehearsal shows the PIN keypad, not an endless loading state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRehearsal(tester);

    expect(find.text("Güvenlik PIN'i doğrulanıyor…"), findsNothing);
    for (final digit in '0123456789'.split('')) {
      expect(find.bySemanticsLabel(digit), findsOneWidget, reason: digit);
    }
    handle.dispose();
  });

  testWidgets('the right PIN ends a rehearsal with no native call at all', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRehearsal(tester);
    expect(find.byType(CountdownScreen), findsOneWidget);

    await enterPin(tester, '4826');

    expect(find.byType(CountdownScreen), findsNothing);
    expect(find.text('rehearse'), findsOneWidget);
    expect(
      nativeCalls,
      isNot(contains('armEmergencySession')),
      reason: 'a rehearsal never arms',
    );
    expect(nativeCalls, isNot(contains('cancelEmergencySession')));
    handle.dispose();
  });

  testWidgets('a wrong rehearsal PIN is metered by the real lockout', (
    tester,
  ) async {
    // Deliberate: an unmetered rehearsal keypad would let anyone holding the
    // unlocked phone guess the PIN that cancels a real countdown.
    final handle = tester.ensureSemantics();
    await pumpRehearsal(tester);
    await enterPin(tester, '1111');
    expect(storage.values['pin_lockout_failed_attempts'], '1');
    expect(find.byType(CountdownScreen), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a cancelled rehearsal leaves the safety history untouched', (
    tester,
  ) async {
    late Database db;
    await tester.runAsync(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await LocalDatabaseService.createSchema(db);
    });
    addTearDown(() => tester.runAsync(db.close));
    serviceLocator.registerSingleton<LocalDatabaseService>(
      _MemoryDatabaseService(db),
    );
    final handle = tester.ensureSemantics();
    await pumpRehearsal(tester);
    await enterPin(tester, '4826');
    expect(find.byType(CountdownScreen), findsNothing);
    final rows = await tester.runAsync(() => db.query('activity_events'));
    expect(rows, isEmpty, reason: 'a rehearsal is not an emergency');
    handle.dispose();
  });
}
