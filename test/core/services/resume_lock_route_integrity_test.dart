// The resume PIN lock is a ROUTE above `/`, so its integrity depended on every
// other piece of navigation code knowing which route it was closing. Three
// paths did not:
//
// * `EmergencyCallScreen._returnHome` ran `popUntil(route.isFirst)`. When the
//   call result sat above the lock -- a widget / Quick Settings panic after
//   more than two minutes in the background, or a Check-In dispatched on
//   resume -- "end" popped the lock too and opened the app with no PIN.
// * The lock's own `onUnlocked` was `navigator.pop()`: the TOP route. A
//   countdown pushed above the lock while the PIN was being verified was the
//   route it closed, leaving an armed native session with no cancel surface.
// * Nothing re-raised the lock once something else removed it.
//
// And the lock itself was pushed above a live panic countdown when the quick
// access countdown won the race on the same resume, hiding the PIN-cancel pad
// behind a second PIN prompt with ten seconds on the clock.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/security/secure_storage_keys.dart';
import 'package:guvenlik_app/core/services/app_lifecycle_handler.dart';
import 'package:guvenlik_app/core/services/app_reset_state_registry.dart';
import 'package:guvenlik_app/core/services/call_service.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/screens/app_unlock_screen.dart';
import 'package:guvenlik_app/screens/emergency_call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// A configured PIN; [absent] models the record a wipe deleted, and
/// [hang] a keystore read that never returns.
class _PinStorage extends SecureStorage {
  bool absent = false;
  bool hang = false;

  @override
  Future<String?> read({required String key}) async {
    if (key != SecureStorageKeys.userPin) return null;
    if (hang) await Completer<void>().future;
    return absent ? null : 'pbkdf2_sha256\$1\$AAAA\$AAAA';
  }

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}
}

Future<void> _settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR')],
      path: 'assets/translations',
      assetLoader: const _RealTrAssetLoader(),
      startLocale: const Locale('tr', 'TR'),
      fallbackLocale: const Locale('tr', 'TR'),
      child: Builder(
        builder: (context) => MaterialApp(
          navigatorKey: rootNavigatorKey,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    ),
  );
  await _settle(tester, rounds: 3);
}

/// The real resume path, after a background longer than the threshold.
Future<void> _resumeAfterLongBackground(WidgetTester tester) async {
  AppLifecycleHandler.instance.pausedAtForTest = DateTime.now().subtract(
    const Duration(seconds: AppLifecycleHandler.lockAfterSeconds + 5),
  );
  unawaited(AppLifecycleHandler.instance.onResumed());
  await _settle(tester);
}

Route<void> _push(String label) {
  final route = MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: Center(child: Text(label))),
  );
  unawaited(rootNavigatorKey.currentState!.push(route));
  return route;
}

State _lockState(WidgetTester tester) =>
    tester.state(find.byType(AppUnlockScreen, skipOffstage: false));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _PinStorage storage;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    storage = _PinStorage();
    serviceLocator.registerSingleton<SecureStorage>(storage);
    AppLifecycleHandler.instance.resetForTest();
    PanicCountdownGuard.resetForTesting();
  });

  tearDown(() async {
    AppLifecycleHandler.instance.resetForTest();
    PanicCountdownGuard.resetForTesting();
    await serviceLocator.reset();
  });

  testWidgets('"end" on a call result shown above the lock never removes the '
      'lock', (tester) async {
    await _pumpApp(tester);
    await _resumeAfterLongBackground(tester);
    expect(find.byType(AppUnlockScreen), findsOneWidget);
    final lockBefore = _lockState(tester);

    // A quick-access panic (or a Check-In dispatched on this resume) put its
    // result above the lock: the no-PIN emergency surface, by design.
    unawaited(
      rootNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => EmergencyCallScreen(
            name: 'Acil Kisi',
            phone: '+905551112233',
            callResult: EmergencyCallResult.requested('+905551112233'),
          ),
        ),
      ),
    );
    await _settle(tester, rounds: 3);
    await tester.tap(find.bySemanticsLabel('emergency_call_end'.tr()).first);
    await _settle(tester);

    expect(find.byType(EmergencyCallScreen), findsNothing);
    expect(
      find.byType(AppUnlockScreen),
      findsOneWidget,
      reason: 'popUntil(isFirst) removed the PIN lock: app open without a PIN',
    );
    expect(
      identical(_lockState(tester), lockBefore),
      isTrue,
      reason: 'the original lock route must survive, not be re-created',
    );
    expect(find.text('HOME'), findsNothing);
    expect(AppLifecycleHandler.instance.lockActive.value, isTrue);
  });

  testWidgets('unlocking closes the LOCK, not a route pushed above it', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _resumeAfterLongBackground(tester);
    // Pushed above the lock while the PIN was being verified (e.g. a volume
    // trigger countdown).
    final above = _push('ABOVE');
    await _settle(tester, rounds: 3);

    tester
        .widget<AppUnlockScreen>(
          find.byType(AppUnlockScreen, skipOffstage: false),
        )
        .onUnlocked();
    await _settle(tester);

    expect(
      above.isActive && above.isCurrent,
      isTrue,
      reason: 'unlock popped the route above the lock instead of the lock',
    );
    expect(find.byType(AppUnlockScreen, skipOffstage: false), findsNothing);
    expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
  });

  testWidgets('a lock removed by anything but an unlock comes back while a PIN '
      'exists', (tester) async {
    await _pumpApp(tester);
    await _resumeAfterLongBackground(tester);
    expect(find.byType(AppUnlockScreen), findsOneWidget);

    rootNavigatorKey.currentState!.popUntil((route) => route.isFirst);
    await _settle(tester);

    expect(
      find.byType(AppUnlockScreen),
      findsOneWidget,
      reason: 'a stack-wide pop is not an unlock',
    );
    expect(AppLifecycleHandler.instance.lockActive.value, isTrue);
  });

  testWidgets('the lock comes back at once, without waiting on storage', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _resumeAfterLongBackground(tester);
    expect(find.byType(AppUnlockScreen), findsOneWidget);

    storage.hang = true; // a keystore read that never returns
    rootNavigatorKey.currentState!.popUntil((route) => route.isFirst);
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(
      find.byType(AppUnlockScreen),
      findsOneWidget,
      reason: 'the app sat unlocked behind a pending storage read',
    );
    expect(find.text('HOME').hitTestable(), findsNothing);
    // The new lock's own bounded PIN read times out against the hung store.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a leaked countdown guard does not switch the lock off for good', (
    tester,
  ) async {
    await _pumpApp(tester);
    // Held with no route behind it: the shape of a leak.
    expect(PanicCountdownGuard.tryAcquire(Object()), isTrue);

    await _resumeAfterLongBackground(tester);
    expect(find.byType(AppUnlockScreen), findsNothing);

    await tester.pump(AppLifecycleHandler.maxCountdownDeferral);
    await _settle(tester);
    expect(find.byType(AppUnlockScreen), findsOneWidget);
  });

  testWidgets('a lock removed after a wipe deleted the PIN stays down', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _resumeAfterLongBackground(tester);
    expect(find.byType(AppUnlockScreen), findsOneWidget);

    // "Forgot PIN": AppResetService.clearLocalData deletes the PIN and runs
    // the reset registry, THEN the unlock screen pops to the first route.
    storage.absent = true;
    expect(await AppResetStateRegistry.resetAll(), isTrue);
    rootNavigatorKey.currentState!.popUntil((route) => route.isFirst);
    await _settle(tester);

    expect(find.byType(AppUnlockScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect(AppLifecycleHandler.instance.lockActive.value, isFalse);
  });

  testWidgets('the lock waits for a live panic countdown instead of covering '
      'its PIN-cancel pad', (tester) async {
    await _pumpApp(tester);
    // The quick-access countdown won the race on this resume.
    final opened = PanicCountdownGuard.open(
      Object(),
      () => rootNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('COUNTDOWN'))),
        ),
      ),
    );
    expect(opened, isNotNull);
    await _settle(tester, rounds: 3);

    await _resumeAfterLongBackground(tester);

    expect(
      find.text('COUNTDOWN'),
      findsOneWidget,
      reason: 'the lock was pushed over the live countdown',
    );
    expect(find.byType(AppUnlockScreen), findsNothing);
    expect(
      AppLifecycleHandler.instance.lockActive.value,
      isTrue,
      reason: 'links must stay parked while the lock is pending',
    );

    rootNavigatorKey.currentState!.pop(); // countdown cancelled with the PIN
    await _settle(tester);

    expect(PanicCountdownGuard.isHeld, isFalse);
    expect(
      find.byType(AppUnlockScreen),
      findsOneWidget,
      reason: 'the deferred lock must still come up once the countdown closes',
    );
  });
}
