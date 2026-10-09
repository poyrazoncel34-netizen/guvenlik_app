// Y-07 (chaos audit 2026-10-08): the PIN pad appears as soon as the PIN state
// has loaded, but the native session is armed only after the PRIMARY CONTACT
// has loaded too. A correct PIN that lands in between used to be refused as
// "cancel unconfirmed", the Dart timer was restarted WITHOUT a deadline, and
// the arm that followed saw `_timer != null` and never ran -- no native
// session, yet ten seconds later the screen reported a failed emergency call
// to a user who had cancelled.

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
import 'package:guvenlik_app/core/services/emergency_dispatch_pipeline.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/pin_verification_service.dart';
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

/// Holds the lockout reset a correct PIN performs, when a test asks it to.
Completer<void>? lockoutResetGate;

class _PinStorage extends SecureStorage {
  @override
  Future<String?> read({required String key}) async =>
      key == SecureStorageKeys.userPin ? _pin : null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {
    final gate = lockoutResetGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> deleteAll() async {}
}

/// A primary-contact read that only completes when the test says so.
class _SlowContactsRepository implements ContactsRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async {
    await gate.future;
    return const EmergencyContact(name: 'Test', phone: _phone, isPrimary: true);
  }

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

  late _SlowContactsRepository contacts;
  late List<String> nativeCalls;
  late List<String> dialled;
  Completer<void>? armGate;
  var armAnswersUnknown = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(_PinStorage());
    contacts = _SlowContactsRepository();
    serviceLocator.registerSingleton<ContactsRepository>(contacts);
    nativeCalls = <String>[];
    dialled = <String>[];
    armGate = null;
    armAnswersUnknown = false;
    lockoutResetGate = null;
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> enterPinBeforeArmAndExpectCancel(
    WidgetTester tester, {
    required bool armInFlight,
    bool contactsDuringCancel = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('countdown-pin-before-arm');
    Map<String, Object?>? token;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      nativeCalls.add(call.method);
      final arguments = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      if (call.method == 'armEmergencySession') {
        final gate = armGate;
        if (gate != null) await gate.future;
        token = <String, Object?>{
          'protocolVersion': arguments['protocolVersion'],
          'randomId': arguments['randomId'],
          'generation': arguments['requestedGeneration'],
          'kind': arguments['kind'],
        };
        if (armAnswersUnknown) {
          return <String, Object?>{
            'type': 'unknown',
            'reasonCode': 'commitUncertain',
            'token': token,
          };
        }
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

    Future<bool?>? routeFuture;
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
                onPressed: () => routeFuture = Navigator.of(context).push<bool>(
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
    // Waits for a condition, not a fixed number of real-time slices: the
    // machine running this suite is shared with emulators, and a fixed 120 ms
    // was the one assumption here that load could break.
    for (var i = 0; i < 6 || (armInFlight && i < 200); i++) {
      if (i >= 6 && nativeCalls.contains('armEmergencySession')) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The keypad is up (PIN loaded) while the arm has not answered: this is
    // the window a user can type into.
    expect(find.byType(CountdownScreen), findsOneWidget);
    expect(
      nativeCalls.contains('armEmergencySession'),
      armInFlight,
      reason: 'arm in flight: $armInFlight',
    );
    for (final digit in _pin.split('')) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The contact read (or the arm reply) finally completes.
    if (contactsDuringCancel) {
      // ...while the cancel is still recording itself (lockout reset).
      contacts.gate.complete();
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      lockoutResetGate!.complete();
    } else if (armInFlight) {
      armGate!.complete();
    } else {
      contacts.gate.complete();
    }
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Let a full countdown elapse.
    for (var i = 0; i < 14; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    final armed = nativeCalls.where((m) => m == 'armEmergencySession').length;
    final cancelled = nativeCalls
        .where((m) => m == 'cancelEmergencySession')
        .length;
    expect(nativeCalls, isNot(contains('dispatchEmergencySession')));
    expect(
      armed == 0 || cancelled == armed,
      isTrue,
      reason:
          'a session armed after the cancel must be cancelled '
          '(calls: $nativeCalls)',
    );
    expect(
      dialled,
      isEmpty,
      reason: 'a cancelled countdown must not open the dialer',
    );
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'no failure dialog for a cancelled countdown',
    );
    expect(
      find.byType(CountdownScreen, skipOffstage: false),
      findsNothing,
      reason: 'the correct PIN closes the countdown (calls: $nativeCalls)',
    );
    expect(routeFuture, isNotNull);
  }

  testWidgets(
    'a correct PIN entered before the native arm started is honoured: '
    'nothing is armed and no failed call is reported later',
    (tester) => enterPinBeforeArmAndExpectCancel(tester, armInFlight: false),
  );

  testWidgets(
    'a correct PIN entered while the native arm is in flight cancels the '
    'session that arm creates',
    (tester) async {
      armGate = Completer<void>();
      contacts.gate.complete();
      await enterPinBeforeArmAndExpectCancel(tester, armInFlight: true);
      expect(nativeCalls.where((m) => m == 'cancelEmergencySession').length, 1);
    },
  );

  testWidgets(
    'a contact read that completes while the cancel is being recorded does '
    'not arm the session the user just cancelled',
    (tester) async {
      lockoutResetGate = Completer<void>();
      await enterPinBeforeArmAndExpectCancel(
        tester,
        armInFlight: false,
        contactsDuringCancel: true,
      );
      expect(nativeCalls, isNot(contains('armEmergencySession')));
    },
  );

  // Review of Y-07: the branch where the original defect restarted the timer
  // without a deadline -- an arm in flight that ends neither armed nor
  // rejected. Its uncertain token is the session to cancel.
  testWidgets(
    'a correct PIN entered while the arm in flight ends UNKNOWN cancels that '
    'uncertain session instead of resuming or dialling',
    (tester) async {
      armGate = Completer<void>();
      armAnswersUnknown = true;
      contacts.gate.complete();
      await enterPinBeforeArmAndExpectCancel(tester, armInFlight: true);
      expect(nativeCalls.where((m) => m == 'cancelEmergencySession').length, 1);
    },
  );
}
