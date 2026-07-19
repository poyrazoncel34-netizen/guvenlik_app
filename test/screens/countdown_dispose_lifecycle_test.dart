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
  _PinStorage({this.failReads = false});

  final bool failReads;

  @override
  Future<String?> read({required String key}) async {
    if (failReads) throw PlatformException(code: 'secure_read_failed');
    return key == SecureStorageKeys.userPin ? '4826' : null;
  }

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
  EntitlementDecision entitlementDecision = EntitlementDecision.authorized,
  bool asPushedRoute = false,
  bool isTestMode = false,
  SecureStorage? pinStorage,
}) async {
  final pin = PinVerificationService.forTesting(
    secureStorage: pinStorage ?? _PinStorage(),
  );
  final countdown = CountdownScreen(
    isTestMode: isTestMode,
    entitlementDecision: entitlementDecision,
    pinVerificationService: pin,
    emergencyPlatformService: platform,
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
          home: asPushedRoute
              ? Builder(
                  builder: (context) => TextButton(
                    key: const Key('open-countdown'),
                    onPressed: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => countdown)),
                    child: const Text('open'),
                  ),
                )
              : countdown,
        ),
      ),
    ),
  );
  if (asPushedRoute) {
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-countdown')));
    await tester.pump();
  }
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
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage());
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

    await _pumpCountdown(tester, platform: platform, asPushedRoute: true);
    for (final digit in <String>['4', '8', '2', '6']) {
      final digitFinder = find.text(digit);
      await tester.ensureVisible(digitFinder);
      await tester.pump();
      await tester.tap(digitFinder);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      methods.where((method) => method == 'cancelEmergencySession'),
      hasLength(1),
    );
    expect(find.byType(CountdownScreen), findsOneWidget);
  });

  testWidgets(
    'rejected native arm has no active token and PIN cancel exits locally',
    (tester) async {
      const channel = MethodChannel('countdown-rejected-arm-cancel-test');
      final methods = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        methods.add(call.method);
        final arguments = (call.arguments as Map<Object?, Object?>)
            .cast<String, Object?>();
        if (call.method == 'armEmergencySession') {
          return <String, Object?>{
            'type': 'rejected',
            'reasonCode': 'callPermissionDenied',
          };
        }
        if (call.method == 'cancelEmergencySession') {
          return <String, Object?>{
            'type': 'stale',
            'token': arguments['token'],
          };
        }
        throw PlatformException(
          code: 'unexpected_method',
          message: call.method,
        );
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

      await _pumpCountdown(tester, platform: platform, asPushedRoute: true);
      for (final digit in <String>['4', '8', '2', '6']) {
        final digitFinder = find.text(digit);
        await tester.ensureVisible(digitFinder);
        await tester.pump();
        await tester.tap(digitFinder);
        await tester.pump();
      }
      for (
        var attempt = 0;
        attempt < 30 && find.byType(CountdownScreen).evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(methods, isNot(contains('cancelEmergencySession')));
      expect(find.byType(CountdownScreen), findsNothing);
    },
  );

  testWidgets('authorization rejection never reaches native or dispatch', (
    tester,
  ) async {
    const channel = MethodChannel('countdown-authorization-rejected-test');
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
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

    await _pumpCountdown(
      tester,
      platform: platform,
      entitlementDecision: EntitlementDecision.denied,
      asPushedRoute: true,
    );
    final countdownNumber = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.style?.fontSize ?? 0) >= 50,
    );
    expect((tester.widget<Text>(countdownNumber)).data, '10');
    for (var second = 0; second < 11; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 100));

    expect(methods.where((method) => method == 'armEmergencySession'), isEmpty);
    expect((tester.widget<Text>(countdownNumber)).data, '10');
    expect(methods, isNot(contains('dispatchEmergencySession')));
  });

  testWidgets('PIN read failure never reaches native or starts countdown', (
    tester,
  ) async {
    const channel = MethodChannel('countdown-pin-read-failed-test');
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
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

    await _pumpCountdown(
      tester,
      platform: platform,
      pinStorage: _PinStorage(failReads: true),
    );
    final countdownNumber = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.style?.fontSize ?? 0) >= 50,
    );
    await tester.pump(const Duration(seconds: 2));

    expect((tester.widget<Text>(countdownNumber)).data, '10');
    expect(methods, isNot(contains('armEmergencySession')));
  });

  testWidgets('test mode advances locally without native safety state', (
    tester,
  ) async {
    const channel = MethodChannel('countdown-local-test-mode');
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
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

    await _pumpCountdown(
      tester,
      platform: platform,
      isTestMode: true,
      asPushedRoute: true,
    );
    final countdownNumber = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.style?.fontSize ?? 0) >= 50,
    );
    await tester.pump(const Duration(seconds: 1));

    expect((tester.widget<Text>(countdownNumber)).data, '9');
    expect(methods, isEmpty);

    await tester.pump(const Duration(seconds: 9));
    for (
      var attempt = 0;
      attempt < 30 && find.byType(CountdownScreen).evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(CountdownScreen), findsNothing);
    expect(methods, isEmpty);
  });
}
