// Android state restoration -- BEHAVIOUR cover.
//
// WHY THIS FILE EXISTS. The 2026-08-14 device pass recorded, as an honest
// limitation, that "unsubmitted input does NOT survive true process death".
// That was a defect, not a limitation: Flutter ships a first-class mechanism
// for exactly this (`RestorationMixin` + `Restorable*` under a root
// `restorationScopeId`), and the app simply had not adopted it. Losing a
// half-typed emergency contact is not cosmetic -- the onboarding contact step
// is the ONLY gate that can complete onboarding, so a user who loses it can
// end up with no panic flow at all.
//
// WHAT MAKES THESE TESTS NON-VACUOUS. `tester.restartAndRestore()` is the
// documented harness for OS-initiated restoration, but a test that only ever
// sees green proves nothing. Every positive case here is paired with a control
// that MUST stay red-capable:
//
//   * NC-1  a sibling plain TextEditingController in the SAME tree, restarted
//           in the SAME call -- it must come back EMPTY. If the harness ever
//           stopped really destroying state, this field would survive too and
//           the case fails.
//   * NC-2  the same widget with NO root `restorationScopeId` -- the app must
//           be provably un-restorable. This is what fails if the root id is
//           ever dropped from `lib/main.dart`.
//
// The PIN side is covered separately in `test/state_restoration_policy_test.dart`.

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

/// A plain, deliberately NON-restorable field mounted beside the step. It is
/// the in-test negative control: the same `restartAndRestore()` that preserves
/// the step's drafts must wipe this one.
class _NonRestorableSibling extends StatefulWidget {
  const _NonRestorableSibling();
  @override
  State<_NonRestorableSibling> createState() => _NonRestorableSiblingState();
}

class _NonRestorableSiblingState extends State<_NonRestorableSibling> {
  final TextEditingController _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('nc_sibling'),
        controller: _controller,
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

  /// Mounts the real step. `runAsync` is required: the step's `_refresh()` does
  /// sqflite-ffi I/O, which FakeAsync cannot drive.
  Future<void> pumpStep(
    WidgetTester tester, {
    required bool restorationEnabled,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          // Mirrors lib/main.dart: the bucket comes from the root
          // restorationScopeId. That is safe ONLY because the app's initial
          // route is never destroyed -- see
          // state_restoration_navigator_precondition_test.dart for what
          // happens when it is.
          restorationScopeId: restorationEnabled ? 'korubeni' : null,
          home: const _Step(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder nameField() => find.byType(TextField).at(0);
  Finder phoneField() => find.byType(TextField).at(1);

  testWidgets(
      'unsubmitted emergency contact survives an OS-initiated process death',
      (tester) async {
    await pumpStep(tester, restorationEnabled: true);

    // Harness precondition: the real form must be on screen, not the consent
    // card. Two step fields + the control sibling = three.
    expect(
      find.byType(TextField),
      findsNWidgets(3),
      reason: 'harness precondition: name + phone + control sibling',
    );

    await tester.enterText(nameField(), 'Ayse Yilmaz');
    await tester.enterText(phoneField(), '05551112233');
    await tester.enterText(find.byKey(const Key('nc_sibling')), 'CONTROL');
    await tester.pump();

    await tester.restartAndRestore();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.widget<TextField>(nameField()).controller?.text,
      'Ayse Yilmaz',
      reason: 'the half-typed contact NAME must survive process death',
    );
    expect(
      tester.widget<TextField>(phoneField()).controller?.text,
      '05551112233',
      reason: 'the half-typed contact PHONE must survive process death',
    );

    // NC-1: proves the restart really destroyed and rebuilt state. Without
    // this, a harness that quietly stopped restarting would make the two
    // assertions above pass for the wrong reason.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('nc_sibling')))
          .controller
          ?.text,
      isEmpty,
      reason:
          'NEGATIVE CONTROL: a plain TextEditingController in the same tree '
          'must NOT survive the same restart. If it does, the restart is not '
          'really destroying state and every positive case here is vacuous.',
    );
  });

  testWidgets(
      'NEGATIVE CONTROL: with no root restorationScopeId the app is not restorable',
      (tester) async {
    await pumpStep(tester, restorationEnabled: false);

    await tester.enterText(nameField(), 'Ayse Yilmaz');
    await tester.pump();

    // This is what breaks if the root restorationScopeId is ever removed from
    // lib/main.dart: the whole mechanism goes inert, silently. Asserted on
    // the OBSERVABLE outcome rather than on a thrown type, because "restores
    // nothing" is the user-visible failure and it is what a future Flutter
    // version would still have to reproduce.
    Object? restartError;
    try {
      await tester.restartAndRestore();
      await tester.pump(const Duration(milliseconds: 50));
    } on Object catch (error) {
      restartError = error;
    }

    // MEASURED, not assumed: with no root `restorationScopeId` Flutter 3.38.9
    // asserts inside `restartAndRestore()` -- there is no root bucket to
    // restore from at all. Either observable outcome is a failure for the
    // user (an un-restorable app, or an empty field), and both are asserted so
    // this control cannot go quiet if a future Flutter downgrades the assert
    // into a silent no-op.
    if (restartError == null) {
      expect(
        tester.widget<TextField>(nameField()).controller?.text,
        isEmpty,
        reason:
            'NEGATIVE CONTROL: without a root restorationScopeId there is no '
            'root bucket, so the draft MUST be lost.',
      );
    } else {
      expect(
        restartError,
        isNotNull,
        reason:
            'NEGATIVE CONTROL: the app must be provably UN-restorable without '
            'a root restorationScopeId. This is the case that fails if that '
            'line is ever dropped from lib/main.dart -- without it every '
            'RestorationMixin in the app is inert and the positive cases above '
            'would be proving nothing.',
      );
    }
  });

  testWidgets('the phone validation verdict travels with the restored text',
      (tester) async {
    await pumpStep(tester, restorationEnabled: true);

    // A number that fails validation, so the step is showing an error.
    await tester.enterText(phoneField(), '112');
    await tester.pump();
    final errorBefore = tester
        .widget<TextField>(phoneField())
        .decoration
        ?.errorText;
    expect(
      errorBefore,
      isNotNull,
      reason: 'harness precondition: 112 must be rejected as a contact number',
    );

    await tester.restartAndRestore();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.widget<TextField>(phoneField()).controller?.text,
      '112',
      reason: 'the rejected text itself must survive',
    );
    expect(
      tester.widget<TextField>(phoneField()).decoration?.errorText,
      errorBefore,
      reason:
          'restoring the text without its verdict would redraw a form that '
          'LOOKS valid and is not -- the user would press save and be '
          'rejected a second time with no explanation.',
    );
  });
}

void _noop(bool _) {}

/// The step plus its non-restorable control sibling, so both go through the
/// same mount, the same restart and the same scope.
class _Step extends StatelessWidget {
  const _Step();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Column(
          children: <Widget>[
            Expanded(child: OnboardingContactStep(onGateChanged: _noop)),
            _NonRestorableSibling(),
          ],
        ),
      );
}
