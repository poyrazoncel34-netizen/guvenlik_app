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

Future<void> _pumpCountdown(
  WidgetTester tester, {
  required EmergencyPlatformService platform,
}) async {
  final pin = PinVerificationService.forTesting(secureStorage: _PinStorage());
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
          home: CountdownScreen(
            entitlementDecision: EntitlementDecision.authorized,
            pinVerificationService: pin,
            emergencyPlatformService: platform,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
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
    serviceLocator.registerSingleton<ContactsRepository>(_ContactsRepository());
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('disposing an armed countdown never sends native cancel', (
    tester,
  ) async {
    const channel = MethodChannel('countdown-dispose-lifecycle-test');
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
      final arguments = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      if (call.method == 'armEmergencySession') {
        return <String, Object?>{
          'type': 'armed',
          'token': <String, Object?>{
            'protocolVersion': arguments['protocolVersion'],
            'randomId': arguments['randomId'],
            'generation': arguments['requestedGeneration'],
            'kind': arguments['kind'],
          },
          'mainDeadlineMs': arguments['mainDeadlineMs'],
          'finalDeadlineMs': arguments['finalDeadlineMs'],
        };
      }
      throw PlatformException(code: 'unexpected_method', message: call.method);
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
    await _pumpCountdown(tester, platform: platform);

    expect(
      methods.where((method) => method == 'armEmergencySession'),
      hasLength(1),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(methods, isNot(contains('cancelEmergencySession')));
  });

  testWidgets('unknown native cancel acknowledgement keeps countdown active', (
    tester,
  ) async {
    const channel = MethodChannel('countdown-cancel-unknown-test');
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
        return <String, Object?>{
          'type': 'unknown',
          'token': token,
          'reasonCode': 'nativeTimeout',
        };
      }
      throw PlatformException(code: 'unexpected_method', message: call.method);
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

    await _pumpCountdown(tester, platform: platform);
    for (final digit in <String>['4', '8', '2', '6']) {
      final digitFinder = find.text(digit);
      await tester.ensureVisible(digitFinder);
      await tester.pump();
      await tester.tap(digitFinder);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      methods.where((method) => method == 'cancelEmergencySession'),
      hasLength(1),
    );
    expect(find.byType(CountdownScreen), findsOneWidget);
  });
}
