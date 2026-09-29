import 'dart:async';
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
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_dispatch_pipeline.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phone = '+905001234567';

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
      const EmergencyContact(name: 'Test Kisi', phone: _phone, isPrimary: true);

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

Map<String, Object?> _token(Map<String, Object?> arguments) =>
    <String, Object?>{
      'protocolVersion': arguments['protocolVersion'],
      'randomId': arguments['randomId'],
      'generation': arguments['requestedGeneration'],
      'kind': arguments['kind'],
    };

Map<String, Object?> _dispatchResult(
  Map<String, Object?> token, {
  required String call,
  required String fallback,
  required String terminal,
}) => <String, Object?>{
  'token': token,
  'callRequestOutcome': call,
  'fallbackOutcome': fallback,
  'connectionState': 'unknown',
  'terminalState': terminal,
};

class _NoBookkeepingPipeline extends EmergencyDispatchPipeline {
  const _NoBookkeepingPipeline();

  @override
  Future<DispatchExecution<T>> execute<T>({
    required String dispatchId,
    required Future<T> Function() criticalOperation,
    required bool Function(T result) shouldRunBestEffort,
    required Iterable<BestEffortStep> bestEffortOperations,
    void Function(DispatchOutcomeLedger ledger, T result)?
    recordCriticalOutcome,
  }) => super.execute<T>(
    dispatchId: dispatchId,
    criticalOperation: criticalOperation,
    shouldRunBestEffort: shouldRunBestEffort,
    bestEffortOperations: const <BestEffortStep>[],
    recordCriticalOutcome: recordCriticalOutcome,
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

  Future<void> openCountdown(
    WidgetTester tester, {
    required MethodChannel channel,
    Future<bool> Function(String number)? dialerOpener,
    EmergencyDispatchPipeline? dispatchPipeline,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

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
                key: const Key('open-countdown'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CountdownScreen(
                      entitlementDecision: EntitlementDecision.authorized,
                      pinVerificationService: PinVerificationService.forTesting(
                        secureStorage: _PinStorage(),
                      ),
                      emergencyPlatformService:
                          EmergencyPlatformService.forTesting(
                            methodChannel: channel,
                            defaultTimeout: const Duration(seconds: 30),
                          ),
                      dialerOpener: dialerOpener,
                      dispatchPipeline: dispatchPipeline,
                    ),
                  ),
                ),
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
    expect(find.byType(CountdownScreen), findsOneWidget);
  }

  testWidgets('GS-11: too-late PIN cancel visibly resumes native dispatch', (
    tester,
  ) async {
    const channel = MethodChannel('korubeni-test/countdown-too-late');
    final dispatchReply = Completer<Map<String, Object?>>();
    final methods = <String>[];
    Map<String, Object?>? token;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      methods.add(call.method);
      final arguments = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      if (call.method == 'armEmergencySession') {
        token = _token(arguments);
        return <String, Object?>{
          'type': 'armed',
          'token': token,
          'mainDeadlineMs': arguments['mainDeadlineMs'],
          'finalDeadlineMs': arguments['finalDeadlineMs'],
        };
      }
      if (call.method == 'cancelEmergencySession') {
        return <String, Object?>{
          'type': 'tooLate',
          'token': token,
          'terminalState': 'claimed',
        };
      }
      if (call.method == 'dispatchEmergencySession') {
        return dispatchReply.future;
      }
      throw PlatformException(code: 'unexpected', message: call.method);
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await openCountdown(tester, channel: channel);
    for (final digit in <String>['4', '8', '2', '6']) {
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.pump();

    expect(
      methods,
      containsAllInOrder(<String>[
        'cancelEmergencySession',
        'dispatchEmergencySession',
      ]),
    );
    expect(
      find.text('İptal için çok geç; arama isteği gönderilmiş olabilir.'),
      findsOneWidget,
    );
    expect(find.byType(CountdownScreen), findsOneWidget);

    dispatchReply.complete(
      _dispatchResult(
        token!,
        call: 'notAttempted',
        fallback: 'notAttempted',
        terminal: 'cancelled',
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CountdownScreen), findsNothing);
  });

  testWidgets(
    'GS-18: native cancelled dispatch exits without a result screen',
    (tester) async {
      const channel = MethodChannel('korubeni-test/countdown-native-cancelled');
      Map<String, Object?>? token;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final arguments = (call.arguments as Map<Object?, Object?>)
            .cast<String, Object?>();
        if (call.method == 'armEmergencySession') {
          token = _token(arguments);
          return <String, Object?>{
            'type': 'armed',
            'token': token,
            'mainDeadlineMs': arguments['mainDeadlineMs'],
            'finalDeadlineMs': arguments['finalDeadlineMs'],
          };
        }
        if (call.method == 'dispatchEmergencySession') {
          return _dispatchResult(
            token!,
            call: 'notAttempted',
            fallback: 'notAttempted',
            terminal: 'cancelled',
          );
        }
        throw PlatformException(code: 'unexpected', message: call.method);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await openCountdown(tester, channel: channel);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10200)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(CountdownScreen), findsNothing);
      expect(find.byType(EmergencyCallScreen), findsNothing);
      expect(find.byKey(const Key('open-countdown')), findsOneWidget);
    },
  );

  testWidgets(
    'GS-19: total dispatch failure opens the blocking recovery dialog',
    (tester) async {
      const channel = MethodChannel('korubeni-test/countdown-total-failure');
      Map<String, Object?>? token;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final arguments = (call.arguments as Map<Object?, Object?>)
            .cast<String, Object?>();
        if (call.method == 'armEmergencySession') {
          token = _token(arguments);
          return <String, Object?>{
            'type': 'armed',
            'token': token,
            'mainDeadlineMs': arguments['mainDeadlineMs'],
            'finalDeadlineMs': arguments['finalDeadlineMs'],
          };
        }
        if (call.method == 'dispatchEmergencySession') {
          return _dispatchResult(
            token!,
            call: 'failed',
            fallback: 'failed',
            terminal: 'requestFailed',
          );
        }
        throw PlatformException(code: 'unexpected', message: call.method);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await openCountdown(
        tester,
        channel: channel,
        dialerOpener: (_) async => false,
        dispatchPipeline: const _NoBookkeepingPipeline(),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10200)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      for (
        var i = 0;
        i < 8 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Şimdi Ara'), findsOneWidget);
      expect(find.byType(EmergencyCallScreen), findsNothing);
    },
  );
}
