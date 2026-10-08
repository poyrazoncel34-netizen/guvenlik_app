// A countdown must act on ITS OWN route, never on "whatever is on top".
//
// `Navigator.pop(context)` and `Navigator.pushReplacement(context, ...)` do not
// target the route that owns `context`: they target the TOPMOST route of the
// navigator. Anything that lands above a live countdown -- an external
// `korubeni://` link, the resume PIN lock, a paywall -- was therefore the route
// the countdown closed or replaced.
//
// Reproduced on an API 35 emulator (build of 09b9004, Test Mode): start the
// rehearsal, fire `am start -a android.intent.action.VIEW -d
// korubeni://open/timeline` at ~T+3 s. The timeline opened over the rehearsal,
// and at T+10 the rehearsal's "completed" pop closed the TIMELINE. The
// rehearsal stayed on screen at "0 saniye" with BACK and the correct PIN both
// inert: the only way out was killing the app.
//
// For a real panic the same shape is worse: `pushReplacement` REPLACES the
// route above the countdown with the call result. When that route is the
// resume lock, the lock is gone without a PIN; closing the call screen then
// lands on a dead countdown (PopScope canPop:false, keypad disabled) whose
// route never completes, so the shared PanicCountdownGuard is held for the
// rest of the process and every panic entry point refuses.

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
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
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

/// A configured legacy PIN. Every write is recorded, so a lockout debit is
/// observable; reads of the PIN after [holdVerification] wait on [gate].
class _PinStorage extends SecureStorage {
  final List<String> writes = <String>[];
  Completer<void>? gate;

  void holdVerification() => gate = Completer<void>();

  @override
  Future<String?> read({required String key}) async {
    if (key != SecureStorageKeys.userPin) return null;
    final pending = gate;
    if (pending != null) await pending.future;
    return _pin;
  }

  @override
  Future<void> write({required String key, required String value}) async =>
      writes.add(key);

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

/// Native that arms and, at the deadline, reports a submitted request.
void _installSubmittingNative(WidgetTester tester, MethodChannel channel) {
  Map<String, Object?>? token;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
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
}

final _navigatorKey = GlobalKey<NavigatorState>();

/// Opens a countdown from Home and returns the future of its route.
Future<Future<bool?>> _openCountdown(
  WidgetTester tester, {
  required _PinStorage storage,
  bool isTestMode = false,
  MethodChannel? channel,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  late Future<bool?> routeFuture;
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      fallbackLocale: const Locale('tr', 'TR'),
      startLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          navigatorKey: _navigatorKey,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => routeFuture = Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => CountdownScreen(
                    isTestMode: isTestMode,
                    entitlementDecision: EntitlementDecision.authorized,
                    pinVerificationService: PinVerificationService.forTesting(
                      secureStorage: storage,
                      operationTimeout: const Duration(seconds: 30),
                    ),
                    emergencyPlatformService: EmergencyPlatformService.forTesting(
                      methodChannel:
                          channel ?? const MethodChannel('route-scoped-unused'),
                      defaultTimeout: const Duration(seconds: 30),
                    ),
                    dispatchPipeline: const _NoBookkeepingPipeline(),
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
  return routeFuture;
}

/// What an external entry point puts above the countdown.
Route<void> _pushAbove() {
  final route = MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Center(child: Text('ABOVE'))),
  );
  unawaited(_navigatorKey.currentState!.push(route));
  return route;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  late _PinStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    storage = _PinStorage();
    serviceLocator.registerSingleton<SecureStorage>(storage);
    serviceLocator.registerSingleton<ContactsRepository>(_ContactsRepository());
  });

  tearDown(() async => serviceLocator.reset());

  testWidgets(
    'a completed rehearsal closes ITSELF, not the route pushed above it',
    (tester) async {
      final result = await _openCountdown(
        tester,
        storage: storage,
        isTestMode: true,
      );
      final above = _pushAbove();
      await tester.pump(const Duration(milliseconds: 400));
      expect(above.isCurrent, isTrue);

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        above.isActive,
        isTrue,
        reason: 'the rehearsal popped the route above it (device: trapped)',
      );
      expect(above.isCurrent, isTrue);
      expect(
        find.byType(CountdownScreen, skipOffstage: false),
        findsNothing,
        reason: 'the rehearsal must not stay behind at 0 seconds',
      );
      expect(await result, isTrue, reason: 'the rehearsal still completed');
    },
  );

  testWidgets(
    'a real dispatch hands off BELOW a route pushed above the countdown and '
    'never replaces it',
    (tester) async {
      const channel = MethodChannel('route-scoped/real-dispatch');
      _installSubmittingNative(tester, channel);
      final result = await _openCountdown(
        tester,
        storage: storage,
        channel: channel,
      );
      final above = _pushAbove();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10300)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        above.isActive && above.isCurrent,
        isTrue,
        reason:
            'pushReplacement replaced the route ABOVE the countdown; when that '
            'route is the resume lock, the lock disappears without a PIN',
      );
      expect(
        find.byType(EmergencyCallScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'the call result still replaces the countdown',
      );
      expect(
        find.byType(CountdownScreen, skipOffstage: false),
        findsNothing,
        reason: 'a dead countdown left in the stack traps the user',
      );
      expect(await result, isNull, reason: 'the countdown route completed');
    },
  );

  testWidgets(
    'dismissing an arm-failure dialog closes the countdown, not the route '
    'between them',
    (tester) async {
      const channel = MethodChannel('route-scoped/arm-rejected');
      final armReply = Completer<Map<String, Object?>>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'armEmergencySession') return armReply.future;
        throw PlatformException(code: 'unexpected', message: call.method);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final result = await _openCountdown(
        tester,
        storage: storage,
        channel: channel,
      );
      // Something lands above the countdown while native is still arming...
      final above = _pushAbove();
      await tester.pump(const Duration(milliseconds: 400));
      // ...then native refuses, and the blocking dialog opens above both.
      armReply.complete(<String, Object?>{
        'type': 'rejected',
        'reasonCode': 'exactAlarmUnavailable',
      });
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.tap(find.text('emergency_dismiss'.tr()).last);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(
        above.isActive && above.isCurrent,
        isTrue,
        reason: 'the dialog closed the route above the countdown',
      );
      expect(find.byType(CountdownScreen, skipOffstage: false), findsNothing);
      expect(await result, isNull);
    },
  );
}
