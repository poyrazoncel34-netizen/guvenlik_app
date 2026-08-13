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

  // R2-12: the fix has TWO mechanisms -- the scroll reveal and the reserved
  // bottom padding. An independent reviewer disabled the padding and all six
  // existing cases still passed, so the padding was uncovered. This case
  // measures the scroll extent the padding creates.
  testWidgets('the reserved bottom padding gives the scroll view enough '
      'extent to clear the IME', (tester) async {
    await pumpStep(tester);

    final scrollableFinder = find.byType(Scrollable).first;
    final closedExtent = tester
        .state<ScrollableState>(scrollableFinder)
        .position
        .maxScrollExtent;

    await focusPhoneField(tester);
    await openKeyboard(tester);

    final openExtent = tester
        .state<ScrollableState>(scrollableFinder)
        .position
        .maxScrollExtent;

    // Harness precondition: the IME must really be simulated. Without this a
    // zero-inset run would compare two identical numbers and "pass".
    expect(
      tester.view.viewInsets.bottom,
      moreOrLessEquals(kImeInset, epsilon: 1.0),
      reason: 'harness precondition: the IME inset must be applied',
    );

    // Opening the IME shrinks the viewport by the inset AND, because of
    // `bottom: _imeInset`, adds the same inset to the content. The viewport
    // shrink alone cannot reach this bound: with this content the closed state
    // has slack, so removing the reserved padding leaves the growth well under
    // one keyboard height (measured: 98 vs 418).
    expect(
      openExtent - closedExtent,
      greaterThanOrEqualTo(kImeInset),
      reason:
          'The scrollable extent must grow by at least the keyboard height '
          'when the IME opens. Less than that means `bottom: _imeInset` was '
          'removed: the content ends above the keyboard and the save action '
          'cannot be scrolled clear of it at all. '
          'closed=$closedExtent open=$openExtent',
    );
  });


  // ==========================================================================
  // R3-01: the SAME step, in the embedding production actually uses.
  //
  // Every case above pumps `OnboardingContactStep` alone in a full-height
  // Scaffold body. Production puts it inside `onboarding_screen`'s PageView,
  // under a skip header and above the page dots, the primary button and a
  // helper line. That chrome costs ~230 logical px, so the step's viewport with
  // the IME open is ~345px on a real device instead of the ~480px the standalone
  // harness gives it.
  //
  // Driving the real build on an arm64 API 36 emulator (1080x2400 @ 420dpi,
  // logical 411x914, IME 339) showed the save action NOT revealed on focus: the
  // content still ended mid-helper-sentence and the user had to find the scroll
  // gesture -- the exact IR-01 defect, in the exact embedding the standalone
  // harness cannot see.
  // ==========================================================================
  group('production embedding (PageView + footer chrome)', () {
    // Logical geometry measured from the emulator, not invented.
    const embeddedViewport = Size(411 * 2.625, 914 * 2.625);
    const embeddedIme = 339.0 * 2.625;

    Future<void> pumpEmbedded(WidgetTester tester) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = embeddedViewport;
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    // skip header
                    const SizedBox(height: 48),
                    Expanded(
                      child: PageView(
                        children: [
                          OnboardingContactStep(onGateChanged: (_) {}),
                        ],
                      ),
                    ),
                    // page dots
                    const SizedBox(height: 56),
                    // primary button
                    const SizedBox(height: 84),
                    // gate helper line
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump(const Duration(milliseconds: 50));
      assertRealFormState(tester);
    }

    testWidgets('the save action is revealed above the keyboard without the '
        'user scrolling', (tester) async {
      await pumpEmbedded(tester);

      final keyboardTop =
          embeddedViewport.height / 2.625 - embeddedIme / 2.625;

      // Precondition: before the IME opens the action is on screen (compared
      // against the FULL viewport, not the future keyboard line -- comparing
      // against the keyboard line here would fail for a perfectly healthy
      // layout and mask the real result).
      expect(
        tester.getRect(saveAction()).bottom,
        lessThanOrEqualTo(embeddedViewport.height / 2.625 + 1.0),
        reason: 'harness precondition: action visible before the IME opens',
      );

      await tester.tap(find.byType(TextField).last);
      await tester.pump(const Duration(milliseconds: 50));
      for (final fraction in <double>[0.25, 0.5, 0.75, 1.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: embeddedIme * fraction);
        await tester.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Precondition: the IME really is simulated.
      expect(
        tester.view.viewInsets.bottom,
        moreOrLessEquals(embeddedIme, epsilon: 1.0),
      );

      expect(
        tester.getRect(saveAction()).bottom,
        lessThanOrEqualTo(keyboardTop + 1.0),
        reason:
            'The save action is the ONLY way to register an emergency contact, '
            'and a user who cannot find the scroll gesture ends up with no '
            'panic flow at all. Reproduced on device before this test existed.',
      );
    });
  });

}
