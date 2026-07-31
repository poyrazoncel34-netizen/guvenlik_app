import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/utils/panic_hold_gate.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:guvenlik_app/screens/countdown_screen.dart';
import 'package:guvenlik_app/widgets/panic_button.dart';
import 'package:provider/provider.dart';
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
class _FixedAccessProvider extends SubscriptionProvider {
  _FixedAccessProvider(this._state);

  final SubscriptionAccessState _state;

  @override
  SubscriptionAccessState get access => _state;

  @override
  Future<SubscriptionAccessState> resolveAccess() async => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  late FakeSecureStorage secure;
  late FakeLocalDatabaseService db;

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
  });

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  Future<void> pumpButton(
    WidgetTester tester,
    SubscriptionAccessState state,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: _FixedAccessProvider(state),
        child: const MaterialApp(home: Scaffold(body: PanicButton())),
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
}
