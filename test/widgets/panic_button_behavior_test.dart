import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/utils/panic_hold_gate.dart';
import 'package:guvenlik_app/domain/repositories/contacts_repository.dart';
import 'package:guvenlik_app/presentation/providers/contacts_provider.dart';
import 'package:guvenlik_app/presentation/providers/home_provider.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:guvenlik_app/screens/contacts_page.dart';
import 'package:guvenlik_app/widgets/panic_button.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

/// Behaviour cover for the app's single most important control.
///
/// `panic_button.dart` sat at 0.3% line coverage: every guarantee about it lived
/// in source-contract assertions that read the file as text, not in anything
/// that actually pressed the button. These tests drive the real widget.
///
/// Scope note: every case here is a REFUSAL path. That is deliberate, not a
/// shortcut -- a button that silently stops arming looks exactly like a button
/// nobody pressed, so refusals are where regressions hide. The accept path
/// mounts CountdownScreen, which brings its own timers, platform channels and
/// repositories; it is exercised with that screen's harness under test/screens/.
///
/// Also not covered here: the "no callable contact" block. That branch lives
/// past the release handler's second entitlement check and did not reproduce
/// under this FakeAsync harness; it needs the same treatment as the accept
/// path rather than a weaker assertion standing in for it.
/// A [Stopwatch] whose elapsed time the test sets explicitly.
///
/// The button measures the hold with a real Stopwatch on purpose (monotonic, so
/// a wall-clock change cannot complete an armed hold). `tester.pump` advances
/// only the FAKE clock, so a test that pumps 2.5s and asserts "did not arm" is
/// really asserting "this machine executed the test body in under 3 real
/// seconds" -- which is false under a loaded full-suite run. That is exactly
/// how this file flaked: green in isolation, red about half the time in the
/// full suite.
class _ManualStopwatch implements Stopwatch {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  set elapsed(Duration value) => _elapsed = value;

  @override
  Duration get elapsed => _elapsed;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
  @override
  void reset() => _elapsed = Duration.zero;
  @override
  bool get isRunning => _running;
  @override
  int get elapsedMicroseconds => _elapsed.inMicroseconds;
  @override
  int get elapsedMilliseconds => _elapsed.inMilliseconds;
  @override
  int get elapsedTicks => _elapsed.inMicroseconds;
  @override
  int get frequency => 1000000;
}

class _FixedAccessProvider extends SubscriptionProvider {
  _FixedAccessProvider(this._state);

  final SubscriptionAccessState _state;

  @override
  SubscriptionAccessState get access => _state;

  @override
  EntitlementDecision get entitlementDecision => _state.entitlementDecision;

  @override
  Future<SubscriptionAccessState> resolveAccess() async => _state;
}

class _DelayedArmBoundaryProvider extends SubscriptionProvider {
  _DelayedArmBoundaryProvider(this.state);

  final SubscriptionAccessState state;
  final Completer<SubscriptionAccessState> armBoundary =
      Completer<SubscriptionAccessState>();
  int resolveCount = 0;

  @override
  SubscriptionAccessState get access => state;

  @override
  EntitlementDecision get entitlementDecision => state.entitlementDecision;

  @override
  Future<void> ensureOfflineGraceLoaded() async {}

  @override
  Future<SubscriptionAccessState> resolveAccess() {
    resolveCount++;
    return resolveCount.isOdd ? Future.value(state) : armBoundary.future;
  }
}

class _NoopContactsProvider extends ContactsProvider {
  @override
  Future<void> initialize() async {}
}

class _NoopHomeProvider extends HomeProvider {
  @override
  Future<void> initialize() async {}
}

class _ContactsRepository implements ContactsRepository {
  const _ContactsRepository(this.primary);

  final EmergencyContact? primary;

  @override
  Future<void> clearPrimaryEmergencyContact() async {}
  @override
  Future<List<String>> getAllEmergencyNumbers() async =>
      primary == null ? const [] : [primary!.phone];
  @override
  Future<List<EmergencyContact>> getContactRecords() async =>
      primary == null ? const [] : [primary!];
  @override
  Future<List<String>> getContacts() => getAllEmergencyNumbers();
  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() async => primary;
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

class _PushObserver extends NavigatorObserver {
  int countdownPushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRouteBuilder<dynamic>) countdownPushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  late FakeSecureStorage secure;
  late FakeLocalDatabaseService db;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    // The first-use warning dialog is keyed off SharedPreferences; marking it
    // seen keeps these tests about the gates, not about the dialog.
    // AppConstants.prefWarningPanic. Marking the first-use warning as already
    // seen keeps these tests about the gates rather than about that dialog.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'warning_panic_shown': true,
    });
    await serviceLocator.reset();
    secure = FakeSecureStorage();
    db = FakeLocalDatabaseService();
    serviceLocator.registerSingleton<SecureStorage>(secure);
    serviceLocator.registerSingleton<LocalDatabaseService>(db);
    ContactService.resetCache();
    PackageInfo.setMockInitialValues(
      appName: 'KoruBeni',
      packageName: 'com.poyrazoncel.korubeni',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (_) async => Directory.systemTemp.path,
        );
  });

  tearDown(() async {
    ContactService.resetCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await serviceLocator.reset();
  });

  late _ManualStopwatch holdClock;

  Future<void> pumpButton(
    WidgetTester tester,
    SubscriptionAccessState state, {
    NavigatorObserver? observer,
    SubscriptionProvider? provider,
  }) async {
    holdClock = _ManualStopwatch();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: provider ?? _FixedAccessProvider(state),
          ),
          ChangeNotifierProvider<ContactsProvider>.value(
            value: _NoopContactsProvider(),
          ),
          ChangeNotifierProvider<HomeProvider>.value(
            value: _NoopHomeProvider(),
          ),
        ],
        child: MaterialApp(
          navigatorObservers: [?observer],
          home: Scaffold(body: PanicButton(holdClockOverride: () => holdClock)),
        ),
      ),
    );
    await tester.pump();
  }

  /// Holds past the 3s gate and releases. Never pumpAndSettle: the button's
  /// breathing animation repeats forever and would hang the test.
  Future<void> holdPastGate(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PanicButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Drive the hold clock explicitly rather than hoping real time passed.
    holdClock.elapsed =
        PanicHoldGate.requiredDuration + const Duration(milliseconds: 500);
    await tester.pump(
      PanicHoldGate.requiredDuration + const Duration(milliseconds: 500),
    );
    await gesture.up();
    // The release handler re-checks entitlement and then the contact store,
    // so several async gaps have to be driven before the outcome is on screen.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Seeds through the production write path.
  ///
  /// Must run inside [WidgetTester.runAsync]: `testWidgets` bodies execute in a
  /// FakeAsync zone, and the sqflite-ffi I/O behind ContactService never
  /// completes there. This is why the existing contact tests use plain `test()`.
  /// Seeding here also warms ContactService's in-memory cache, so the read the
  /// widget itself performs later resolves on a microtask.
  Future<void> seedCallableContact(WidgetTester tester) async {
    await tester.runAsync(
      () => ContactService.savePrimaryEmergencyContact(
        name: 'Acil Kisi',
        phone: '+905551112233',
      ),
    );
  }

  final verifiedPro = const SubscriptionAccessState.uninitialized()
      .markVerified(isPro: true);

  testWidgets('an unresolvable entitlement refuses the press, visibly', (
    tester,
  ) async {
    // This is the state a paying user lands in when the store cannot be
    // reached. The refusal must happen AND must be visible: an unexplained
    // no-op is indistinguishable from a crash to someone about to need it.
    await seedCallableContact(tester);
    await pumpButton(
      tester,
      const SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
      ),
    );

    await holdPastGate(tester);

    expect(find.byType(CountdownScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    // Localization is not initialized in widget tests, so `.tr()` yields the key.
    // Asserting the exact key proves WHICH gate refused.
    expect(find.text('subscription_entitlement_unverified'), findsOneWidget);
  });

  testWidgets('a cold start with no entitlement answer stays fail-closed', (
    tester,
  ) async {
    await seedCallableContact(tester);
    await pumpButton(tester, const SubscriptionAccessState.uninitialized());

    await holdPastGate(tester);

    expect(find.byType(CountdownScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a press released before the 3s gate does not arm', (
    tester,
  ) async {
    await seedCallableContact(tester);
    await pumpButton(tester, verifiedPro);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PanicButton)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // Pin the hold clock strictly below the gate. Without this the assertion
    // silently depends on machine speed instead of on the gate.
    holdClock.elapsed =
        PanicHoldGate.requiredDuration - const Duration(milliseconds: 500);
    await tester.pump(
      PanicHoldGate.requiredDuration - const Duration(milliseconds: 500),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(CountdownScreen),
      findsNothing,
      reason: 'the 3s hold is the guard against accidental activation',
    );
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'an incomplete hold is not a refusal, it is a non-event',
    );
  });

  testWidgets('PNK-04 pointer cancel resets a completed hold without arming', (
    tester,
  ) async {
    await seedCallableContact(tester);
    await pumpButton(tester, verifiedPro);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PanicButton)),
    );
    await tester.pump();
    holdClock.elapsed =
        PanicHoldGate.requiredDuration + const Duration(milliseconds: 500);
    await tester.pump(
      PanicHoldGate.requiredDuration + const Duration(milliseconds: 500),
    );

    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CountdownScreen), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'PNK-14 verified free access renders the locked production state',
    (tester) async {
      final verifiedFree = const SubscriptionAccessState.uninitialized()
          .markVerified(isPro: false);
      await pumpButton(tester, verifiedFree);

      expect(find.text('panic_button_locked_title'), findsOneWidget);
      expect(find.text('panic_button_locked_subtitle'), findsOneWidget);
      expect(find.text('subscription_badge_pro'), findsOneWidget);
      expect(find.text('panic_button_armed_title'), findsNothing);
    },
  );

  testWidgets(
    'PNK-07: completed hold without callable contact is refused visibly',
    (tester) async {
      await tester.runAsync(ContactService.getContactRecords);
      await pumpButton(tester, verifiedPro);

      await holdPastGate(tester);

      expect(find.byType(CountdownScreen), findsNothing);
      expect(find.text('timer_emergency_contact_required'), findsOneWidget);
      expect(find.text('timer_add_contact_action'), findsOneWidget);
    },
  );

  testWidgets('PNK-08: missing-contact SnackBar action pushes ContactsPage', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(ContactService.getContactRecords);
    await pumpButton(tester, verifiedPro);
    await holdPastGate(tester);

    await tester.tap(find.text('timer_add_contact_action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(ContactsPage), findsOneWidget);
  });

  testWidgets('PNK-09: accepting first-use warning cancels that first hold', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.runAsync(ContactService.getContactRecords);
    await pumpButton(tester, verifiedPro);

    await holdPastGate(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CountdownScreen), findsNothing);

    await tester.tap(find.text('feature_warning_continue'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CountdownScreen), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool('warning_panic_shown'),
      isTrue,
    );

    await holdPastGate(tester);
    expect(find.text('timer_emergency_contact_required'), findsOneWidget);
  });

  testWidgets(
    'PNK-13: five rapid completed holds can push only one countdown',
    (tester) async {
      const primary = EmergencyContact(
        name: 'Acil Kisi',
        phone: '+905551112233',
        isPrimary: true,
      );
      await seedCallableContact(tester);
      serviceLocator.registerSingleton<ContactsRepository>(
        const _ContactsRepository(primary),
      );
      final delayedProvider = _DelayedArmBoundaryProvider(verifiedPro);
      final observer = _PushObserver();
      await pumpButton(
        tester,
        verifiedPro,
        observer: observer,
        provider: delayedProvider,
      );

      for (var press = 0; press < 5; press++) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PanicButton)),
        );
        await tester.pump();
        holdClock.elapsed =
            PanicHoldGate.requiredDuration + const Duration(milliseconds: 1);
        await tester.pump(const Duration(milliseconds: 10));
        await gesture.up();
        await tester.pump();
      }

      expect(
        delayedProvider.resolveCount,
        2,
        reason: 'route guard async yetki sınırından önce sahiplenilmeli',
      );
      delayedProvider.armBoundary.complete(verifiedPro);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        observer.countdownPushes,
        1,
        reason: 'hızlı tekrarlar yalnız bir CountdownScreen route açmalı',
      );
      expect(find.byType(CountdownScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
