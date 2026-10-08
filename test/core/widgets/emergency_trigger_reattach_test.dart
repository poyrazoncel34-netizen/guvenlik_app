// A-11 (chaos audit 2026-10-08): a panic countdown whose process died must be
// re-shown -- for the seconds native still has left -- when the app comes
// back, instead of the user facing the unlock screen while native calls at
// the deadline. The host adopts the ARMED session; it never arms one.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/core/services/panic_reattachment.dart';
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
            as Map<String, dynamic>)[key]
        as String;

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

class _StubReattached extends StatelessWidget {
  const _StubReattached(this.session);
  final PanicReattachment session;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text('REATTACHED ${session.armed.sessionToken.randomId}'),
    ),
  );
}

const _channel = MethodChannel('emergency-trigger-reattach');

Future<PanicReattachment?> _armedPanic() => PanicReattachment.discover(
  EmergencyPlatformService.forTesting(methodChannel: _channel),
);

void _installNative(WidgetTester tester, {required bool armed}) {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    if (call.method != 'discoverEmergencySession') return null;
    if (!armed) return <String, Object?>{'type': 'absent'};
    return <String, Object?>{
      'type': 'present',
      'session': <String, Object?>{
        'token': <String, Object?>{
          'protocolVersion': emergencyProtocolVersion,
          'randomId': 'countdown-reattach-1',
          'generation': 1,
          'kind': 'panic',
        },
        'lifecycleState': 'armed',
        'mainDeadlineMs': deadline.millisecondsSinceEpoch,
        'finalDeadlineMs': deadline.millisecondsSinceEpoch,
        'target': '05551234567',
        'callRequestOutcome': 'notAttempted',
        'fallbackOutcome': 'notAttempted',
        'mainDurationMs': 10000,
      },
    };
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
}

Future<void> _pumpHost(WidgetTester tester, PushCounter observer) async {
  final provider = ParkedSubscriptionProvider(
    const SubscriptionAccessState.uninitialized(),
  );
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
            discoverArmedPanic: _armedPanic,
            reattachBuilder: _StubReattached.new,
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    PanicCountdownGuard.resetForTesting();
    // The host binds the native event channel in initState; unmocked, its
    // MissingPluginException fails whichever test runs first.
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
  tearDown(PanicCountdownGuard.resetForTesting);

  testWidgets('an ARMED panic left by a dead process is re-shown at start', (
    tester,
  ) async {
    _installNative(tester, armed: true);
    final observer = PushCounter();
    await _pumpHost(tester, observer);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);

    expect(find.text('REATTACHED countdown-reattach-1'), findsOneWidget);
    expect(
      PanicCountdownGuard.isHeld,
      isTrue,
      reason: 'one countdown at a time',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await drainHostTimers(tester);
  });

  testWidgets('a countdown already on screen is not doubled', (tester) async {
    _installNative(tester, armed: true);
    final other = Object();
    expect(PanicCountdownGuard.tryAcquire(other), isTrue);
    final observer = PushCounter();
    await _pumpHost(tester, observer);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);

    expect(find.textContaining('REATTACHED'), findsNothing);
    PanicCountdownGuard.release(other);
    await tester.pumpWidget(const SizedBox.shrink());
    await drainHostTimers(tester);
  });

  testWidgets('no ARMED panic, nothing re-shown', (tester) async {
    _installNative(tester, armed: false);
    final observer = PushCounter();
    await _pumpHost(tester, observer);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);

    expect(find.textContaining('REATTACHED'), findsNothing);
    expect(PanicCountdownGuard.isHeld, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await drainHostTimers(tester);
  });

  testWidgets('a return to the app re-checks: a session re-shown on resume', (
    tester,
  ) async {
    _installNative(tester, armed: false);
    final observer = PushCounter();
    await _pumpHost(tester, observer);
    expect(find.textContaining('REATTACHED'), findsNothing);

    _installNative(tester, armed: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);

    expect(find.text('REATTACHED countdown-reattach-1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await drainHostTimers(tester);
  });
}
