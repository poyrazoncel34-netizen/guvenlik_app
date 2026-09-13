// A correct PIN whose native cancellation is confirmed must leave the
// countdown even when the PIN-lockout store fails to reset.
//
// Before the fix the reset exception escaped `_cancelCountdownAndExit` after
// the native session was already cancelled: the Dart timer was stopped, back
// navigation is blocked (`canPop: false`) and the PIN pad ignored further
// input, so the user sat on a dead countdown until the app was killed.
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

class _EmptyAssetLoader extends AssetLoader {
  const _EmptyAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      <String, dynamic>{};
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

/// Lockout store whose delete fails, as a keystore error would on Android.
class _BrokenDeleteStorage extends SecureStorage {
  int deletes = 0;

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {
    deletes++;
    throw PlatformException(code: 'keystore_delete_failed');
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _BrokenDeleteStorage lockoutStorage;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await serviceLocator.reset();
    lockoutStorage = _BrokenDeleteStorage();
    serviceLocator.registerSingleton<SecureStorage>(lockoutStorage);
    serviceLocator.registerSingleton<ContactsRepository>(_ContactsRepository());
  });

  tearDown(() async => serviceLocator.reset());

  testWidgets(
    'confirmed cancel leaves the countdown when the lockout reset throws',
    (tester) async {
      const channel = MethodChannel('countdown-lockout-reset-failure-test');
      final methods = <String>[];
      Map<String, Object?>? token;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        methods.add(call.method);
        final arguments = (call.arguments as Map<Object?, Object?>)
            .cast<String, Object?>();
        if (call.method == 'armEmergencySession') {
          token = <String, Object?>{
            'protocolVersion': arguments['protocolVersion'],
            'randomId': arguments['randomId'],
            'generation': arguments['requestedGeneration'],
            'kind': arguments['kind'],
          };
          return <String, Object?>{
            'type': 'armed',
            'token': token,
            'mainDeadlineMs': arguments['mainDeadlineMs'],
            'finalDeadlineMs': arguments['finalDeadlineMs'],
          };
        }
        if (call.method == 'cancelEmergencySession') {
          return <String, Object?>{'type': 'cancelled', 'token': token};
        }
        throw PlatformException(code: 'unexpected', message: call.method);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final countdown = CountdownScreen(
        entitlementDecision: EntitlementDecision.authorized,
        pinVerificationService: PinVerificationService.forTesting(
          secureStorage: _PinStorage(),
        ),
        emergencyPlatformService: EmergencyPlatformService.forTesting(
          methodChannel: channel,
          defaultTimeout: const Duration(milliseconds: 100),
        ),
      );
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const <Locale>[Locale('tr', 'TR')],
          path: 'unused',
          assetLoader: const _EmptyAssetLoader(),
          fallbackLocale: const Locale('tr', 'TR'),
          startLocale: const Locale('tr', 'TR'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => TextButton(
                  key: const Key('open-countdown'),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => countdown)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-countdown')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(methods, contains('armEmergencySession'));
      expect(find.byType(CountdownScreen), findsOneWidget);

      final reported = <Object>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      try {
        for (final digit in <String>['4', '8', '2', '6']) {
          await tester.ensureVisible(find.text(digit).last);
          await tester.tap(find.text(digit).last);
          await tester.pump();
        }
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = originalOnError;
      }

      expect(methods, contains('cancelEmergencySession'));
      expect(
        lockoutStorage.deletes,
        greaterThan(0),
        reason: 'the failing reset path must actually have run',
      );
      expect(reported, isEmpty);
      expect(tester.takeException(), isNull);
      expect(
        find.byType(CountdownScreen),
        findsNothing,
        reason: 'a confirmed cancel must leave the countdown',
      );
    },
  );
}
