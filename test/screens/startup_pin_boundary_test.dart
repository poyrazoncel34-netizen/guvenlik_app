import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:guvenlik_app/screens/app_root.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:guvenlik_app/widgets/consent_checkbox_widget.dart';
import 'accessibility_guidelines_test.dart' show pumpLocalized;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/screens/splash_screen.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:guvenlik_app/screens/legal/unified_consent_screen.dart';
import 'package:guvenlik_app/screens/onboarding_screen.dart';
import 'package:guvenlik_app/screens/main_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guvenlik_app/core/services/app_reset_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';

class _PartialStore implements AppResetLocalDataStore {
  _PartialStore(this.failure, this.storage);
  final String failure;
  final _Storage storage;
  String? database = 'synthetic contact';
  String? file = 'synthetic location';
  @override
  Future<bool> clearPreferences() async {
    await (await SharedPreferences.getInstance()).clear();
    return failure != 'preferences';
  }

  @override
  Future<void> deleteDatabase() async {
    if (failure == 'database') throw StateError('locked');
    database = null;
  }

  @override
  Future<bool> clearLocalFiles() async {
    if (failure == 'files') return false;
    file = null;
    return true;
  }

  @override
  Future<void> clearSecureStorage() async {
    storage.pin = null;
    storage.values.clear();
  }
}

class _Storage extends SecureStorage {
  String? pin = '4821';
  final Map<String, String> values = {};
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
    if (key == SecureStorageKeys.userPin) pin = null;
  }

  @override
  Future<String?> read({required String key}) async =>
      values[key] ?? (key == SecureStorageKeys.userPin ? pin : null);
}

void main() {
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.poyrazoncel.korubeni/device_integrity'),
          (_) async => const <String, String>{
            'suBinary': 'absent',
            'magiskBinary': 'absent',
            'superuserArtifacts': 'absent',
            'pathSuBinary': 'absent',
            'rwSystemMounts': 'absent',
            'testKeys': 'absent',
            'dangerousProps': 'absent',
            'developmentEnvironment': 'absent',
          },
        );
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_Storage());
  });
  tearDown(() => serviceLocator.reset());
  for (final standalone in [false, true]) {
    testWidgets('real consent and PIN lifecycle standalone=$standalone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefLegalDisclaimerAccepted: true,
        AppConstants.prefTermsVersion: 'old',
        AppConstants.prefKvkkVersion: 'old',
        AppConstants.prefOnboardingDone: false,
        'synthetic_surviving_contact': 'Synthetic protected contact',
        'kvkk_consent_log_v2': '[]',
      });
      await EasyLocalization.ensureInitialized();
      PackageInfo.setMockInitialValues(
        appName: 'Synthetic',
        packageName: 'test.synthetic',
        version: '1',
        buildNumber: '1',
        buildSignature: '',
      );
      final consent = ConsentManager();
      await consent.initialize();
      serviceLocator.registerSingleton<ConsentManager>(consent);
      await pumpLocalized(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: standalone ? const SplashScreen() : const AppRoot(),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(UnifiedConsentScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(MainNavigation), findsNothing);
      await tester.tap(find.text('18 yaşından büyüğüm'));
      await tester.pump();
      for (final index in [0, 1]) {
        tester
            .widget<ConsentCheckboxWidget>(
              find.byType(ConsentCheckboxWidget).at(index),
            )
            .onChanged(true);
      }
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byType(ElevatedButton));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(AppUnlockScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      for (final pin in ['1111', '4821']) {
        for (final digit in pin.split('')) {
          await tester.runAsync(() async {
            tester
                .widget<InkWell>(
                  find.ancestor(
                    of: find.text(digit),
                    matching: find.byType(InkWell),
                  ),
                )
                .onTap!();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pump();
        }
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (pin == '1111') {
          expect(find.byType(AppUnlockScreen), findsOneWidget);
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(find.byType(MainNavigation), findsNothing);
          await tester.pump(const Duration(seconds: 5));
        }
      }
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'synthetic_surviving_contact',
        ),
        'Synthetic protected contact',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final failure in ['preferences', 'database', 'files']) {
    testWidgets(
      'partial reset $failure reopens behind preserved PIN then retries',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          AppConstants.prefOnboardingDone: true,
        });
        final storage = serviceLocator<SecureStorage>() as _Storage;
        final store = _PartialStore(failure, storage);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(
                'com.poyrazoncel.korubeni/emergency_platform',
              ),
              (_) async => {'type': 'completed'},
            );
        expect(
          await AppResetService.clearLocalData(localStore: store),
          WipeResult.unknown,
        );
        expect(await storage.read(key: SecureStorageKeys.userPin), '4821');
        if (failure == 'database') expect(store.database, 'synthetic contact');
        if (failure == 'files') expect(store.file, 'synthetic location');
        Widget? destination;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: SplashScreen(advance: (next) => destination = next),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(destination, isA<UnifiedConsentScreen>());
        (destination as UnifiedConsentScreen).onAccepted!();
        await tester.pump();
        expect(destination, isA<AppUnlockScreen>());
        final retry = _PartialStore('none', storage);
        expect(
          await AppResetService.clearLocalData(localStore: retry),
          WipeResult.completed,
        );
        expect(await storage.read(key: SecureStorageKeys.userPin), isNull);
        expect(retry.database, isNull);
        expect(retry.file, isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final onboardingDone in [true, false]) {
    testWidgets('reconsent gates existing PIN, onboarding=$onboardingDone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefLegalDisclaimerAccepted: true,
        AppConstants.prefTermsVersion: 'old',
        AppConstants.prefKvkkVersion: 'old',
        AppConstants.prefOnboardingDone: onboardingDone,
      });
      Widget? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SplashScreen(advance: (next) => destination = next),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(destination, isA<UnifiedConsentScreen>());
      (destination as UnifiedConsentScreen).onAccepted!();
      await tester.pump();
      expect(destination, isA<AppUnlockScreen>());
      expect(destination, isNot(isA<OnboardingScreen>()));
      await tester.pumpWidget(MaterialApp(home: destination));
      await tester.pumpAndSettle();
      for (final digit in ['1', '1', '1', '1']) {
        await tester.runAsync(() async {
          tester
              .widget<InkWell>(
                find.ancestor(
                  of: find.text(digit),
                  matching: find.byType(InkWell),
                ),
              )
              .onTap!();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(destination, isA<AppUnlockScreen>());
      expect(find.byType(MainNavigation), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      for (final digit in ['4', '8', '2', '1']) {
        await tester.runAsync(() async {
          tester
              .widget<InkWell>(
                find.ancestor(
                  of: find.text(digit),
                  matching: find.byType(InkWell),
                ),
              )
              .onTap!();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(
        destination,
        onboardingDone ? isA<MainNavigation>() : isA<OnboardingScreen>(),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
