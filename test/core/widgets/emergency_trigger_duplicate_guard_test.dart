// R2-02 / R2-03 regression: the quick-access panic entries.
//
// R2-02 -- the duplicate guard was WRITTEN after `_resolveAccessBounded`
// (400ms anchor budget + 1800ms store budget) and a frame await, but READ at
// the top. Two triggers inside that ~2.2s window both saw `false` and both
// pushed a countdown route. The old test asserted only that the guard was reset
// in a `finally`, which stays green through any reordering -- so this file
// tests the concurrency boundary itself, by firing the real trigger twice while
// entitlement resolution is deliberately parked.
//
// R2-03 -- a refused press used to be a bare `return`: the app opened and
// nothing happened, which on a safety control is indistinguishable from a
// crash.
//
// Harness notes (both were real failures while writing this file):
//   * `pumpWidget` runs inside `tester.runAsync` because the real tr-TR
//     catalogue is loaded from disk, and file I/O deadlocks under FakeAsync.
//   * `EmergencyTriggerHost.initState` starts a 5s readiness probe timer, so
//     every test drains it before finishing or the binding asserts.
//   * The trigger future for an ACCEPTED press does not complete until the
//     countdown route is popped, so it is never awaited directly.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/widgets/emergency_trigger_host.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealTrAssetLoader extends AssetLoader {
  const _RealTrAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
          as Map<String, dynamic>;
}

String trCopy(String key) =>
    (jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
        as Map<String, dynamic>)[key] as String;

/// A provider whose entitlement resolution is parked until the test releases
/// it. This reproduces the real window: `_resolveAccessBounded` awaits the
/// store, and the guard has to already be held by then.
class ParkedSubscriptionProvider extends SubscriptionProvider {
  ParkedSubscriptionProvider(this._answer);

  final SubscriptionAccessState _answer;
  final Completer<void> gate = Completer<void>();
  int resolveCalls = 0;

  @override
  SubscriptionAccessState get access => _answer;

  @override
  Future<void> ensureOfflineGraceLoaded() async {}

  @override
  Future<SubscriptionAccessState> resolveAccess() async {
    resolveCalls++;
    await gate.future;
    return _answer;
  }
}

class _StubCountdown extends StatelessWidget {
  const _StubCountdown();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('STUB_COUNTDOWN')));
}

/// Counts route pushes so "exactly one countdown" is measured, not inferred.
class PushCounter extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

/// Bounded frame pump. `pumpAndSettle` does not terminate in this tree.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Drains the host's 5s platform-readiness probe timer.
Future<void> drainHostTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
}

Future<EmergencyTriggerHostState> pumpHost(
  WidgetTester tester, {
  required ParkedSubscriptionProvider provider,
  required PushCounter observer,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'assets/translations',
        assetLoader: const _RealTrAssetLoader(),
        startLocale: const Locale('tr', 'TR'),
        fallbackLocale: const Locale('tr', 'TR'),
        child: ChangeNotifierProvider<SubscriptionProvider>.value(
          value: provider,
          child: EmergencyTriggerHost(
            countdownBuilder: (_) => const _StubCountdown(),
            child: Builder(
              builder: (context) => MaterialApp(
                navigatorKey: rootNavigatorKey,
                scaffoldMessengerKey: rootScaffoldMessengerKey,
                navigatorObservers: <NavigatorObserver>[observer],
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const Scaffold(body: Center(child: Text('HOME'))),
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await settle(tester);

  final state = tester.state<EmergencyTriggerHostState>(
    find.byType(EmergencyTriggerHost),
  );
  // Harness preconditions. Without these a later "exactly one countdown"
  // assertion could pass against an unattached observer or an unbuilt tree.
  expect(
    observer.pushed,
    isNotEmpty,
    reason: 'observer is not attached to the root navigator',
  );
  expect(find.text('HOME'), findsOneWidget, reason: 'host tree did not build');
  observer.pushed.clear();
  return state;
}

SubscriptionAccessState entitledButUnverifiable() => SubscriptionAccessState(
  status: SubscriptionAccessStatus.unavailable,
  lastVerifiedPro: true,
  lastVerifiedProAt: DateTime.now().subtract(const Duration(hours: 1)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // The host binds the native safety-kernel event channel in initState.
    // Without a mock, `receiveBroadcastStream().listen` raises an uncaught
    // MissingPluginException that fails whichever test happens to run first.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const [
      'com.poyrazoncel.korubeni/emergency_platform',
      'com.poyrazoncel.korubeni/emergency_platform/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (MethodCall call) async => null,
      );
    }
  });

  group('R2-02: two triggers inside the resolve window', () {
    testWidgets('push exactly one countdown route', (tester) async {
      final provider = ParkedSubscriptionProvider(entitledButUnverifiable());
      final observer = PushCounter();
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );

      // Precondition: this user IS authorized, so a countdown is the correct
      // outcome for the FIRST trigger. Without this the test could "pass" by
      // rejecting both.
      expect(provider.access.canUsePaidSafetyFeature, isTrue);

      // Two triggers while entitlement resolution is still parked -- exactly
      // the window the old ordering left open.
      unawaited(state.triggerPanicForTest());
      unawaited(state.triggerPanicForTest());
      await tester.pump();

      expect(
        provider.resolveCalls,
        1,
        reason:
            'the second trigger must be stopped by the guard BEFORE it starts '
            'its own entitlement resolution',
      );

      provider.gate.complete();
      await settle(tester);

      expect(
        observer.pushed.length,
        1,
        reason: 'two rapid triggers stacked two countdown routes (R2-02)',
      );
      expect(find.text('STUB_COUNTDOWN'), findsOneWidget);
      await drainHostTimers(tester);
    });

    testWidgets('twenty rapid triggers still push exactly one', (tester) async {
      final provider = ParkedSubscriptionProvider(entitledButUnverifiable());
      final observer = PushCounter();
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );

      for (var i = 0; i < 20; i++) {
        unawaited(state.triggerPanicForTest());
      }
      await tester.pump();
      expect(provider.resolveCalls, 1);

      provider.gate.complete();
      await settle(tester);

      expect(observer.pushed.length, 1);
      await drainHostTimers(tester);
    });

    testWidgets('the guard releases so a later trigger still works', (
      tester,
    ) async {
      final provider = ParkedSubscriptionProvider(entitledButUnverifiable());
      final observer = PushCounter();
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );

      provider.gate.complete();
      unawaited(state.triggerPanicForTest());
      await settle(tester);
      expect(observer.pushed.length, 1);

      // Close the countdown the way a cancel would.
      rootNavigatorKey.currentState!.pop();
      await settle(tester);
      expect(find.text('STUB_COUNTDOWN'), findsNothing);

      observer.pushed.clear();
      unawaited(state.triggerPanicForTest());
      await settle(tester);
      expect(
        observer.pushed.length,
        1,
        reason:
            'a latched guard would disable the quick-access entries for the '
            'rest of the process',
      );
      rootNavigatorKey.currentState!.pop();
      await settle(tester);
      await drainHostTimers(tester);
    });

    testWidgets('a rejected trigger does not latch the guard', (tester) async {
      // Never-subscribed: rejected, and the guard must still release.
      final provider = ParkedSubscriptionProvider(
        const SubscriptionAccessState.uninitialized(),
      );
      final observer = PushCounter();
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );

      provider.gate.complete();
      await state.triggerPanicForTest();
      await settle(tester);
      expect(observer.pushed, isEmpty, reason: 'no countdown for a non-holder');

      // A second attempt must still be evaluated, not swallowed by a stuck
      // guard.
      final before = provider.resolveCalls;
      await state.triggerPanicForTest();
      await settle(tester);
      expect(provider.resolveCalls, greaterThan(before));
      await drainHostTimers(tester);
    });
  });

  group('R2-03: a refused quick-access press explains itself', () {
    testWidgets('an unresolved entitlement produces a visible, readable '
        'message instead of silence', (tester) async {
      final provider = ParkedSubscriptionProvider(
        // Unresolved: not confirmed free, so the paywall is NOT the answer.
        const SubscriptionAccessState(
          status: SubscriptionAccessStatus.unavailable,
        ),
      );
      final observer = PushCounter();
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );
      expect(provider.access.canUsePaidSafetyFeature, isFalse);

      provider.gate.complete();
      await state.triggerPanicForTest();
      await settle(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(trCopy('subscription_entitlement_unverified')),
        findsOneWidget,
        reason:
            'the refusal must be stated in real localized copy, not a raw key '
            'and not silence',
      );
      // Never a countdown, never a claim that the emergency ran.
      expect(find.text('STUB_COUNTDOWN'), findsNothing);
      expect(observer.pushed, isEmpty);
      await drainHostTimers(tester);
    });

    testWidgets('the refusal is announced to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final provider = ParkedSubscriptionProvider(
        const SubscriptionAccessState(
          status: SubscriptionAccessStatus.unavailable,
        ),
      );
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: PushCounter(),
      );
      provider.gate.complete();
      await state.triggerPanicForTest();
      await settle(tester);

      expect(
        find.bySemanticsLabel(trCopy('subscription_entitlement_unverified')),
        findsOneWidget,
      );
      handle.dispose();
      await drainHostTimers(tester);
    });

    testWidgets('rapid refused presses do not flood the screen with messages', (
      tester,
    ) async {
      final provider = ParkedSubscriptionProvider(
        const SubscriptionAccessState(
          status: SubscriptionAccessStatus.unavailable,
        ),
      );
      final state = await pumpHost(
        tester,
        provider: provider,
        observer: PushCounter(),
      );

      provider.gate.complete();
      for (var i = 0; i < 5; i++) {
        await state.triggerPanicForTest();
      }
      await settle(tester);

      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'five refusals must not stack five SnackBars',
      );
      await drainHostTimers(tester);
    });
  });

  group('R2-02: the entry points really do share this path', () {
    // The test seam above is only trustworthy if the production triggers route
    // through the same method.
    test('volume trigger and quick-panic hand-off both call _openCountdown', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();
      expect(source, contains('onPanicTriggered: _openCountdown'));
      expect(
        RegExp(
          r'_consumeQuickPanicRequest\(\)\s*async\s*\{[\s\S]{0,400}?_openCountdown\(\)',
        ).hasMatch(source),
        isTrue,
      );
      expect(
        source,
        contains('Future<void> triggerPanicForTest() => _openCountdown();'),
        reason: 'the test seam must call the production method, not a copy',
      );
    });

    test('the guard is acquired before the first await', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _openCountdown() async {');
      expect(start, isNot(-1));
      final body = source.substring(start);
      final acquire = body.indexOf('_countdownOpen = true;');
      final firstAwait = body.indexOf('await ');
      expect(acquire, isNot(-1));
      expect(firstAwait, isNot(-1));
      expect(
        acquire,
        lessThan(firstAwait),
        reason:
            'Writing the guard after an await is R2-02 exactly. The behavioural '
            'tests above are the primary evidence; this pins the ordering so a '
            'reviewer can see it without running them.',
      );
      expect(body, contains('} finally {'));
      expect(body, contains('_countdownOpen = false;'));
    });

    test('the refusal path goes through the shared rejection surface', () {
      final source = File(
        'lib/core/widgets/emergency_trigger_host.dart',
      ).readAsStringSync();
      expect(source, contains('SubscriptionGate.reportRejection('));
      expect(
        source,
        isNot(contains('!access.canUsePaidSafetyFeature) return;')),
        reason: 'the silent bare-return rejection must not return (R2-03)',
      );
    });
  });
}
