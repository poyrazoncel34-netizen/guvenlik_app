// Y-04 (chaos audit 2026-10-08): on an API 35 emulator a +1 h wall-clock change
// two seconds into a panic countdown took the Dart countdown to zero at once.
// Native had already rebased its deadline (TIME_SET keeps safety timers
// duration-based), refused the early dispatch, the refusal read as unknown and
// the DIALER opened (15:20:43) -- the PIN-cancel pad was gone -- and the native
// alarm still placed the automatic request at the real deadline (15:20:51).

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
import 'package:guvenlik_app/core/services/countdown_announcement.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_dispatch_pipeline.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
import 'package:guvenlik_app/core/services/safety_clock.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phone = '+905001234567';
const _pin = '4826';

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
      key == SecureStorageKeys.userPin ? _pin : null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

class _Contacts implements ContactsRepository {
  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async =>
      const EmergencyContact(name: 'Test', phone: _phone, isPrimary: true);

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

class _FakeClock implements SafetyClock {
  DateTime wall = DateTime(2026, 10, 8, 14, 20);
  Duration elapsed = Duration.zero;

  @override
  DateTime now() => wall;

  @override
  Duration get monotonic => elapsed;
}

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

  late List<String> nativeCalls;
  late List<String> dialled;
  late int? armedFinalMs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage());
    serviceLocator.registerSingleton<ContactsRepository>(_Contacts());
    nativeCalls = <String>[];
    dialled = <String>[];
    armedFinalMs = null;
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> openCountdown(WidgetTester tester, _FakeClock clock) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('countdown-wall-clock-jump');
    Map<String, Object?>? token;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call.method);
      final arguments = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      if (call.method == 'armEmergencySession') {
        armedFinalMs = arguments['finalDeadlineMs'] as int?;
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
      if (call.method == 'dispatchEmergencySession') {
        return <String, Object?>{
          'token': token,
          'callRequestOutcome': 'submittedUnconfirmed',
          'fallbackOutcome': 'posted',
          'connectionState': 'unknown',
          'terminalState': 'requestSubmittedUnconfirmed',
        };
      }
      throw PlatformException(code: 'unexpected', message: call.method);
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
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => CountdownScreen(
                      entitlementDecision: EntitlementDecision.authorized,
                      pinVerificationService: PinVerificationService.forTesting(
                        secureStorage: _PinStorage(),
                        operationTimeout: const Duration(seconds: 30),
                      ),
                      emergencyPlatformService:
                          EmergencyPlatformService.forTesting(
                            methodChannel: channel,
                            defaultTimeout: const Duration(seconds: 30),
                          ),
                      dispatchPipeline: const _NoBookkeepingPipeline(),
                      dialerOpener: (number) async {
                        dialled.add(number);
                        return true;
                      },
                      safetyClock: clock,
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(nativeCalls, contains('armEmergencySession'));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  for (final jump in <Duration>[
    const Duration(hours: 1),
    const Duration(hours: -2),
  ]) {
    testWidgets(
      'a ${jump.isNegative ? 'backward' : 'forward'} wall-clock change keeps '
      'the countdown, its cancel pad and its single dispatch on the real '
      'deadline',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final clock = _FakeClock();
        final armedAt = clock.wall;
        await openCountdown(tester, clock);
        expect(
          armedFinalMs,
          armedAt.add(const Duration(seconds: 10)).millisecondsSinceEpoch,
          reason: 'native still receives the wall deadline',
        );

        clock.elapsed += const Duration(seconds: 1);
        clock.wall = clock.wall.add(const Duration(seconds: 1)).add(jump);
        await settle(tester);

        expect(nativeCalls, isNot(contains('dispatchEmergencySession')));
        expect(dialled, isEmpty, reason: 'the dialer opened early');
        expect(find.byType(CountdownScreen), findsOneWidget);
        expect(
          find.bySemanticsLabel(CountdownAnnouncement.labelFor(9)),
          findsOneWidget,
          reason: '9 s are left',
        );
        expect(find.bySemanticsLabel('4'), findsWidgets);

        clock.elapsed = const Duration(seconds: 10);
        await settle(tester);

        expect(
          nativeCalls.where((m) => m == 'dispatchEmergencySession').length,
          1,
          reason: 'one dispatch at the real deadline',
        );
        expect(dialled, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 13));
        semantics.dispose();
      },
    );
  }
}
