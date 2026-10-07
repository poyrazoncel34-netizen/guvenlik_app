// A completed local-data wipe started from a PUSHED route must return the app
// to the startup decision without destroying `/`.
//
// Reproduced on an API 35 emulator (commit eda8304, play debug): Settings ->
// Kullanici (ProfilePage, a pushed route) -> Cihaz Verilerini Temizle -> PIN
// -> HOME -> process killed -> task resumed. Result: `_history.isNotEmpty`
// failed in navigator.dart and the crash screen replaced the app.
//
// Why: `AppRoot.restartStartup` looked AppRoot up through an inherited widget,
// and a route pushed onto the root Navigator is a sibling of `/` in the
// Overlay, not a descendant of AppRoot. The lookup found nothing, the caller
// fell back to `pushAndRemoveUntil(..., (_) => false)`, `/` was removed, and
// the next Android restoration had no restorable route left.
//
// `startup_pin_boundary_test.dart` only ever called restartStartup from a
// context INSIDE AppRoot, which is why it stayed green.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/navigation/pending_destination_service.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/utils/app_reset_helper.dart';
import 'package:guvenlik_app/screens/app_root.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:guvenlik_app/screens/legal/unified_consent_screen.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SandboxPaths extends PathProviderPlatform {
  _SandboxPaths(this.root);
  final Directory root;
  @override
  Future<String> getApplicationDocumentsPath() async => root.path;
  @override
  Future<String> getTemporaryPath() async => root.path;
  @override
  Future<String> getApplicationSupportPath() async => root.path;
}

class _EmptySecureStorage extends SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> deleteAll() async => _values.clear();
}

Future<void> _settle(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Real I/O (the wipe touches a sandbox directory) finishes on the real
/// clock; poll for the outcome, bounded, instead of guessing a window.
Future<void> _settleUntil(
  WidgetTester tester,
  bool Function() done, {
  int maxRounds = 150,
}) async {
  for (var i = 0; i < maxRounds && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        startLocale: const Locale('tr', 'TR'),
        fallbackLocale: const Locale('tr', 'TR'),
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorKey: rootNavigatorKey,
            // Same precondition as production: root restoration on, so the
            // Navigator restores its route history.
            restorationScopeId: 'korubeni',
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: AppRoot(),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _settle(tester);
}

void main() {
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.poyrazoncel.korubeni/device_integrity'),
          (_) async => const <String, String>{},
        );
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.prefLegalDisclaimerAccepted: false,
      'kvkk_consent_log_v2': '[]',
    });
    PackageInfo.setMockInitialValues(
      appName: 'Synthetic',
      packageName: 'test.synthetic',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    await EasyLocalization.ensureInitialized();
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_EmptySecureStorage());
    final consent = ConsentManager();
    await consent.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consent);
  });

  tearDown(() => serviceLocator.reset());

  testWidgets(
    'wipe completed from a pushed route restarts AppRoot and keeps `/`',
    (tester) async {
      await _pumpApp(tester);
      expect(find.byType(UnifiedConsentScreen), findsOneWidget);
      final initialRoute = ModalRoute.of(
        tester.element(find.byType(UnifiedConsentScreen)),
      );
      expect(initialRoute!.isFirst, isTrue);

      // Stand-in for ProfilePage / DataDeletionScreen: pushed on the root
      // Navigator, exactly like settings_page.dart does.
      late BuildContext pushedContext;
      rootNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) {
            pushedContext = context;
            return const Scaffold(body: Text('pushed-profile'));
          },
        ),
      );
      await _settle(tester, rounds: 5);
      expect(find.text('pushed-profile'), findsOneWidget);

      AppResetHelper.returnToStartupAfterWipe(pushedContext);
      await _settle(tester);

      expect(
        find.text('pushed-profile'),
        findsNothing,
        reason: 'a route showing wiped state must not survive the reset',
      );
      expect(rootNavigatorKey.currentState!.canPop(), isFalse);
      final routeAfterReset = ModalRoute.of(
        tester.element(find.byType(UnifiedConsentScreen)),
      );
      expect(
        routeAfterReset,
        same(initialRoute),
        reason:
            'the reset must restart AppRoot in place; removing `/` leaves '
            'Android restoration with an empty route history',
      );

      // The process-death half of the reproduction.
      await tester.restartAndRestore();
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(UnifiedConsentScreen), findsOneWidget);
      expect(rootNavigatorKey.currentState!.canPop(), isFalse);
    },
  );

  testWidgets(
    'forgot-PIN wipe from the RESUME lock (a route above `/`) restarts AppRoot',
    (tester) async {
      const emergencyChannel = MethodChannel(
        'com.poyrazoncel.korubeni/emergency_platform',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final wipeCalls = <String>[];
      messenger.setMockMethodCallHandler(emergencyChannel, (call) async {
        if (call.method == 'wipeEmergencySessions') {
          wipeCalls.add(call.method);
          return <String, Object?>{'type': 'completed'};
        }
        return <String, Object?>{'type': 'absent'};
      });
      final sandbox = Directory.systemTemp.createTempSync('reset_restart_');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _SandboxPaths(sandbox);
      addTearDown(() {
        messenger.setMockMethodCallHandler(emergencyChannel, null);
        PathProviderPlatform.instance = originalPaths;
        sandbox.deleteSync(recursive: true);
      });
      final storage = serviceLocator<SecureStorage>();
      await storage.write(key: SecureStorageKeys.userPin, value: '4821');
      serviceLocator.registerSingleton<LocalDatabaseService>(
        LocalDatabaseService(),
      );

      await _pumpApp(tester);
      final initialRoute = ModalRoute.of(
        tester.element(find.byType(UnifiedConsentScreen)),
      );

      // Exactly how AppLifecycleHandler.onResumed shows the re-auth lock.
      unawaited(
        rootNavigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => AppUnlockScreen(onUnlocked: () {}),
          ),
        ),
      );
      await _settle(tester, rounds: 8);
      expect(find.byType(AppUnlockScreen), findsOneWidget);

      final forgot = find.text('Şifremi Unuttum');
      await tester.ensureVisible(forgot);
      await tester.tap(forgot);
      await _settle(tester, rounds: 5);
      // A link parked before the wipe must not fire into the fresh install.
      PendingDestinationService.instance.submitUri(
        Uri.parse('korubeni://open/timeline'),
      );
      await tester.enterText(find.byType(TextField), 'SIFIRLA');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sıfırla'));
      await _settleUntil(
        tester,
        () =>
            wipeCalls.isNotEmpty &&
            find.byType(AppUnlockScreen).evaluate().isEmpty &&
            find.byType(UnifiedConsentScreen).evaluate().isNotEmpty,
      );

      expect(wipeCalls, hasLength(1), reason: 'the real wipe must have run');
      expect(PendingDestinationService.instance.hasPending, isFalse);
      expect(await storage.read(key: SecureStorageKeys.userPin), isNull);
      expect(
        find.byType(AppUnlockScreen),
        findsNothing,
        reason: 'a lock whose PIN was just deleted must not stay on top',
      );
      expect(find.byType(UnifiedConsentScreen), findsOneWidget);
      expect(rootNavigatorKey.currentState!.canPop(), isFalse);
      expect(
        ModalRoute.of(tester.element(find.byType(UnifiedConsentScreen))),
        same(initialRoute),
      );

      await tester.restartAndRestore();
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(UnifiedConsentScreen), findsOneWidget);
    },
  );
}
