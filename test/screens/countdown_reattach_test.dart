// A-11 (chaos audit 2026-10-08): after a process death the countdown is
// re-shown for a session native still holds ARMED. It must ADOPT that session
// -- no arm, native's deadline, PIN cancel and dispatch on native's token --
// or it would either re-arm (rejected: activeSessionExists) or drift from the
// deadline native will actually call at.

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
import 'package:guvenlik_app/core/services/panic_reattachment.dart';
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

const _randomId = 'countdown-1791443857000-42';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  late List<MethodCall> nativeCalls;
  late List<String> dialled;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage());
    serviceLocator.registerSingleton<ContactsRepository>(_Contacts());
    nativeCalls = <MethodCall>[];
    dialled = <String>[];
  });

  tearDown(() async => serviceLocator.reset());

  final token = <String, Object?>{
    'protocolVersion': emergencyProtocolVersion,
    'randomId': _randomId,
    'generation': 1,
    'kind': 'panic',
  };

  Future<void> openReattached(
    WidgetTester tester,
    _FakeClock clock, {
    bool freshTrigger = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('countdown-reattach');
    final deadline = clock.wall.add(const Duration(seconds: 6));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call);
      switch (call.method) {
        case 'armEmergencySession':
          return <String, Object?>{
            'type': 'rejected',
            'reasonCode': 'activeSessionExists',
          };
        case 'discoverEmergencySession':
          return <String, Object?>{
            'type': 'present',
            'session': <String, Object?>{
              'token': token,
              'lifecycleState': 'armed',
              'mainDeadlineMs': deadline.millisecondsSinceEpoch,
              'finalDeadlineMs': deadline.millisecondsSinceEpoch,
              'target': _phone,
              'callRequestOutcome': 'notAttempted',
              'fallbackOutcome': 'notAttempted',
              'mainDurationMs': 10000,
            },
          };
        case 'cancelEmergencySession':
          return <String, Object?>{'type': 'cancelled', 'token': token};
        case 'dispatchEmergencySession':
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
    final platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(seconds: 30),
    );
    final session = freshTrigger
        ? null
        : await tester.runAsync(
            () => PanicReattachment.discover(platform, clock: clock),
          );
    expect(session != null || freshTrigger, isTrue);
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
                      reattach: session,
                      maskContactIdentity: true,
                      entitlementDecision: EntitlementDecision.authorized,
                      pinVerificationService: PinVerificationService.forTesting(
                        secureStorage: _PinStorage(),
                        operationTimeout: const Duration(seconds: 30),
                      ),
                      emergencyPlatformService: platform,
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
    expect(find.byType(CountdownScreen), findsOneWidget);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Iterable<String> methods() => nativeCalls.map((c) => c.method);

  Object? randomIdOf(String method) =>
      ((nativeCalls.lastWhere((c) => c.method == method).arguments
              as Map<Object?, Object?>)['token']
          as Map<Object?, Object?>)['randomId'];

  testWidgets('a re-shown session is adopted: no arm, native deadline, PIN '
      'cancel on its own token', (tester) async {
    final semantics = tester.ensureSemantics();
    final clock = _FakeClock();
    await openReattached(tester, clock);

    expect(methods(), isNot(contains('armEmergencySession')));
    expect(
      find.bySemanticsLabel(CountdownAnnouncement.labelFor(6)),
      findsOneWidget,
      reason: 'six seconds were left at native',
    );

    for (final digit in _pin.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);

    expect(methods(), contains('cancelEmergencySession'));
    expect(randomIdOf('cancelEmergencySession'), _randomId);
    expect(find.byType(CountdownScreen), findsNothing);
    expect(methods(), isNot(contains('dispatchEmergencySession')));
    semantics.dispose();
  });

  testWidgets('left alone, a re-shown session dispatches once, on its own '
      'token, at native deadline', (tester) async {
    final clock = _FakeClock();
    await openReattached(tester, clock);

    clock.elapsed = const Duration(seconds: 5);
    await settle(tester);
    expect(methods(), isNot(contains('dispatchEmergencySession')));

    clock.elapsed = const Duration(seconds: 6);
    await settle(tester);
    expect(methods().where((m) => m == 'dispatchEmergencySession').length, 1);
    expect(randomIdOf('dispatchEmergencySession'), _randomId);
    expect(methods(), isNot(contains('armEmergencySession')));
    expect(dialled, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 13));
  });

  // Review of A-11: the re-show claims the countdown slot only after polling
  // for the navigator. A widget, tile or volume trigger landing in that window
  // opened a FRESH countdown; native refused its arm (activeSessionExists) and
  // the failure dialog covered the screen while the real armed session had no
  // PIN-cancel surface at all. The refused countdown now adopts that session.
  testWidgets('a fresh trigger refused for an orphaned armed session adopts '
      'it instead of showing a failure dialog', (tester) async {
    final semantics = tester.ensureSemantics();
    final clock = _FakeClock();
    await openReattached(tester, clock, freshTrigger: true);
    await settle(tester);

    expect(methods(), contains('armEmergencySession'));
    expect(find.text('emergency_dismiss'.tr()), findsNothing);
    expect(
      find.bySemanticsLabel(CountdownAnnouncement.labelFor(6)),
      findsOneWidget,
      reason: 'the adopted session had six seconds left at native',
    );

    for (final digit in _pin.split('')) {
      await tester.tap(find.bySemanticsLabel(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);

    expect(randomIdOf('cancelEmergencySession'), _randomId);
    expect(find.byType(CountdownScreen), findsNothing);
    expect(methods(), isNot(contains('dispatchEmergencySession')));
    semantics.dispose();
  });
}
