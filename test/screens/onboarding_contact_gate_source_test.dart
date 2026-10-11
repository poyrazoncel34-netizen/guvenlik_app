// Convention in this repo: screen tests are source-level contracts (see
// countdown_live_region_test.dart). The gate's behaviour is covered
// functionally in test/core/services/onboarding_contact_gate_service_test.dart;
// this file pins the wiring that routes the screen through it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String onboarding;
  late String step;
  late String home;

  setUpAll(() {
    onboarding = File('lib/screens/onboarding_screen.dart').readAsStringSync();
    step = File(
      'lib/screens/onboarding/onboarding_contact_step.dart',
    ).readAsStringSync();
    home = File('lib/screens/home_page.dart').readAsStringSync();
  });

  group('onboarding completion is gated', () {
    test('the screen no longer writes the completion flag itself', () {
      // A direct prefs write here is exactly how an install used to reach the
      // home screen with no reachable contact.
      expect(
        onboarding.contains('AppConstants.prefOnboardingDone'),
        isFalse,
        reason:
            'Completion must go through OnboardingContactGateService, which '
            'refuses to write the flag without a callable contact.',
      );
      expect(
        onboarding.contains('SharedPreferences'),
        isFalse,
        reason: 'The screen must not keep a second path to the pref store.',
      );
    });

    test('completion is delegated to the gate service', () {
      expect(
        onboarding.contains('OnboardingContactGateService.completeOnboarding()'),
        isTrue,
      );
      expect(
        onboarding.contains('if (!completed)'),
        isTrue,
        reason: 'A refused completion must not navigate onward.',
      );
    });

    test('skip lands on an actionable step instead of finishing', () {
      // UPDATED for OD-2 (2026-10-11). Skip used to jump straight to the
      // contact gate; it now lands on the background-protection step, which
      // sits immediately before the gate. The property this test exists to
      // protect is unchanged and is asserted below: Skip must NOT call
      // _finish, and the gate is still the only thing that completes
      // onboarding. Landing one page earlier means a user who taps Skip still
      // passes through the step and still cannot finish without the gate.
      expect(onboarding.contains('_skipToFirstActionableStep'), isTrue);
      expect(
        onboarding.contains('_skipToContactStep'),
        isFalse,
        reason: 'the old single-target skip must not come back',
      );
      expect(
        RegExp(r'onPressed:[^;]*_skipToFirstActionableStep').hasMatch(onboarding),
        isTrue,
        reason: 'Skip used to call _finish directly, bypassing the gate.',
      );
      expect(
        RegExp(r'_skipToFirstActionableStep\(\)[^}]*_finish').hasMatch(onboarding),
        isFalse,
        reason: 'Skip must never reach completion.',
      );
      // Its target is derived from the flagged step, not from an index that a
      // reordered page list would silently invalidate.
      expect(
        onboarding.contains('_pages.indexWhere((p) => p.isBackgroundStep)'),
        isTrue,
      );
    });

    test('the start button is disabled until the gate is satisfied', () {
      expect(
        onboarding.contains(
          'onPressed: _isOnContactStep && !_contactGateSatisfied',
        ),
        isTrue,
      );
      expect(onboarding.contains("'onboarding_contact_required_hint'"), isTrue);
    });

    test('the contact step is still the last page', () {
      // OD-2 added a page BEFORE this one; the gate staying last is what keeps
      // it the only exit from onboarding.
      expect(onboarding.contains('isContactStep: true'), isTrue);
      expect(
        onboarding.contains('int get _contactStepIndex => _pages.length - 1'),
        isTrue,
      );
      // And the new page is genuinely before it, not after.
      expect(
        onboarding.indexOf('isBackgroundStep: true') <
            onboarding.indexOf('isContactStep: true'),
        isTrue,
        reason: 'the gate must remain the final page',
      );
    });
  });

  group('contact step contract', () {
    test('writes through the gate service, not ContactService directly', () {
      expect(
        step.contains('OnboardingContactGateService.savePrimaryContact'),
        isTrue,
      );
      expect(
        step.contains('ContactService.'),
        isFalse,
        reason: 'One write path to the canonical contact store.',
      );
    });

    test('uses the shared native picker service', () {
      expect(
        step.contains('NativeContactPickerService.pickPhoneContact()'),
        isTrue,
      );
      expect(
        step.contains('MethodChannel('),
        isFalse,
        reason: 'No second channel to the platform picker.',
      );
    });

    test('asks for KVKK consent before storing third-party data', () {
      expect(step.contains('EmergencyContactConsentDialog.show'), isTrue);
      expect(step.contains('needsContactDataConsent'), isTrue);
      expect(step.contains('grantContactDataConsent'), isTrue);
    });

    test('introduces no biometric unlock', () {
      expect(step.contains('local_auth'), isFalse);
      expect(step.contains('BiometricType'), isFalse);
    });
  });

  group('home screen keeps a tappable missing-contact indicator', () {
    test('the contact chip reports the missing state', () {
      expect(home.contains('"emergency_contact_not_selected".tr()'), isTrue);
      expect(home.contains('"tap_to_select_contact".tr()'), isTrue);
    });

    test('the chip navigates to the contacts screen', () {
      expect(home.contains('_buildEmergencyContactChip'), isTrue);
      expect(home.contains('onTap: _navigateToContacts'), isTrue);
    });

    test('the readiness card still tracks the emergency contact row', () {
      // The card lives in its own widget now; home_page passes the state in.
      final card = File(
        'lib/core/widgets/readiness_card.dart',
      ).readAsStringSync();
      expect(card.contains("'emergency_contact'.tr()"), isTrue);
      expect(card.contains('isOk: hasEmergencyContact'), isTrue);
      expect(
        home.contains('hasEmergencyContact: provider.emergencyContact != null'),
        isTrue,
      );
    });
  });
}
