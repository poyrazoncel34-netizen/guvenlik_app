// Regression cover for the IME-driven reveal of the onboarding save action.
//
// HISTORY -- this file previously could not fail. An independent reviewer
// disabled the production fix and it stayed green four runs in a row. Three
// defects caused that, and all three are guarded against below:
//
//   1. the "keyboard" case passed `bottomInset: 0`, so the IME was never
//      simulated at all;
//   2. the test itself called `tester.ensureVisible(...)` and then asserted
//      `findsOneWidget` -- a finder matches the widget TREE, not the visible
//      viewport, so the assertion held whether or not the button was on screen;
//   3. (found while rewriting) the harness never granted the emergency-contact
//      consent, so the step rendered its consent card, DISABLED both text
//      fields, and never rendered the save button. Tapping a disabled field
//      focuses nothing, so the reveal could not fire and the assertion silently
//      measured the consent button instead.
//
// Rules this file follows:
//   * never call ensureVisible / scrollUntilVisible -- that is the production
//     behaviour under test, not a test utility;
//   * simulate the IME through `tester.view.viewInsets`, the same signal the
//     widget observes via didChangeMetrics;
//   * assert GEOMETRY against the keyboard line, not tree membership;
//   * assert harness preconditions first, so a broken harness fails loudly
//     instead of passing vacuously.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/di/service_locator.dart';
import 'package:guvenlik_app/core/security/secure_storage.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/local_database_service.dart';
import 'package:guvenlik_app/core/services/onboarding_contact_gate_service.dart';
import 'package:guvenlik_app/screens/onboarding/onboarding_contact_step.dart';
import 'package:guvenlik_app/services/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/contact_service_test_support.dart';

/// 800 logical px tall is a short phone -- the geometry that reproduces the bug.
const Size kViewport = Size(400, 800);
const double kImeInset = 320;

double get kKeyboardTop => kViewport.height - kImeInset;

/// `find.byType` matches the EXACT runtime type, and `ElevatedButton.icon`
/// builds a private `_ElevatedButtonWithIcon` SUBCLASS. A byType finder
/// therefore silently misses the save action and matches the consent card's
/// plain ElevatedButton instead -- another way this file could have passed
/// while measuring the wrong widget. Predicate finders match subclasses.
Finder saveAction() =>
    find.byWidgetPredicate((w) => w is ElevatedButton, description: 'save action');
Finder pickAction() =>
    find.byWidgetPredicate((w) => w is OutlinedButton, description: 'pick action');

/// Fails loudly if the step is not in the state a real user reaches.
void assertRealFormState(WidgetTester tester) {
  expect(
    find.byType(TextField),
    findsNWidgets(2),
    reason: 'harness precondition: name + phone fields must be present',
  );
  expect(
    tester.widget<TextField>(find.byType(TextField).last).enabled,
    isNot(false),
    reason:
        'harness precondition: the phone field must be ENABLED, otherwise a '
        'tap focuses nothing and every geometry assertion below is vacuous.',
  );
  expect(
    saveAction(),
    findsOneWidget,
    reason:
        'harness precondition: with consent granted the consent card is gone, '
        'so exactly one ElevatedButton-family widget (the save action) remains.',
  );
  expect(
    pickAction(),
    findsOneWidget,
    reason: 'harness precondition: the pick-from-contacts action must render',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initContactServiceTestFfi();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await serviceLocator.reset();
    serviceLocator.registerSingleton<SecureStorage>(FakeSecureStorage());
    serviceLocator.registerSingleton<LocalDatabaseService>(
      FakeLocalDatabaseService(),
    );
    ContactService.resetCache();

    final consent = ConsentManager();
    await consent.initialize();
    serviceLocator.registerSingleton<ConsentManager>(consent);
    await OnboardingContactGateService.grantContactDataConsent(locale: 'tr');
  });

  tearDown(() async {
    ContactService.resetCache();
    await serviceLocator.reset();
  });

  /// Mounts the step inside a real Scaffold. The Scaffold matters: with
  /// resizeToAvoidBottomInset (default true) it CONSUMES the bottom inset and
  /// resizes the body, which is precisely the lifecycle under test.
  Future<void> pumpStep(WidgetTester tester, {Size size = kViewport}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OnboardingContactStep(onGateChanged: (_) {})),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 50));
    assertRealFormState(tester);
  }

  Future<void> focusPhoneField(WidgetTester tester) async {
    await tester.tap(find.byType(TextField).last);
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Simulates the Android IME animating in over several frames.
  Future<void> openKeyboard(WidgetTester tester) async {
    for (final fraction in <double>[0.25, 0.5, 0.75, 1.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: kImeInset * fraction);
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> closeKeyboard(WidgetTester tester) async {
    tester.view.viewInsets = FakeViewPadding.zero;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('save action is above the keyboard line once the IME opens', (
    tester,
  ) async {
    await pumpStep(tester);
    await focusPhoneField(tester);
    await openKeyboard(tester);

    final rect = tester.getRect(saveAction());
    expect(
      rect.bottom,
      lessThanOrEqualTo(kKeyboardTop + 1.0),
      reason:
          'The save action is the only control that completes onboarding, and '
          'onboarding is what registers the emergency contact. With the '
          'keyboard open it must sit above the IME. '
          'rect=$rect keyboardTop=$kKeyboardTop',
    );
  });

  testWidgets('both actions stay in the tree with the IME open', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpStep(tester);
    await focusPhoneField(tester);
    await openKeyboard(tester);

    // The reported symptom was disappearance from the uiautomator tree.
    expect(saveAction(), findsOneWidget);
    expect(pickAction(), findsOneWidget);
    handle.dispose();
  });

  testWidgets('repeated focus cycles keep the action revealed', (tester) async {
    await pumpStep(tester);

    for (var cycle = 0; cycle < 3; cycle++) {
      await focusPhoneField(tester);
      await openKeyboard(tester);
      expect(
        tester.getRect(saveAction()).bottom,
        lessThanOrEqualTo(kKeyboardTop + 1.0),
        reason: 'cycle $cycle: the reveal must be repeatable, not once-only',
      );
      await closeKeyboard(tester);
    }
  });

  testWidgets('dismissing the keyboard leaves the action on screen', (
    tester,
  ) async {
    await pumpStep(tester);
    await focusPhoneField(tester);
    await openKeyboard(tester);
    await closeKeyboard(tester);

    final rect = tester.getRect(saveAction());
    expect(
      rect.bottom,
      lessThanOrEqualTo(kViewport.height + 1.0),
      reason: 'a reveal that over-scrolls and never unwinds is its own defect',
    );
    expect(rect.top, greaterThanOrEqualTo(-1.0));
  });

  testWidgets('manual scrolling is not pinned by the reveal', (tester) async {
    await pumpStep(tester);
    await focusPhoneField(tester);
    await openKeyboard(tester);

    final before = tester.getRect(saveAction()).top;
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 150));
    await tester.pump(const Duration(milliseconds: 150));
    final after = tester.getRect(saveAction()).top;

    expect(
      (after - before).abs(),
      greaterThan(1.0),
      reason:
          'The user must be able to scroll back to the fields while typing; '
          'the reveal must not re-pin the offset. before=$before after=$after',
    );
  });

  testWidgets('a tall viewport needs no scrolling to clear the IME', (
    tester,
  ) async {
    await pumpStep(tester, size: const Size(400, 1600));
    await focusPhoneField(tester);
    await openKeyboard(tester);

    expect(
      tester.getRect(saveAction()).bottom,
      lessThanOrEqualTo(1600 - kImeInset + 1.0),
    );
  });
}
