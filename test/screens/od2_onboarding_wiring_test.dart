// OD-2 wiring contract: the background-protection step must actually be IN the
// onboarding flow, must not be able to block completion, and must be where
// 'Atla' (Skip) lands.
//
// These are source-contract assertions, deliberately -- the behaviour of the
// step itself is tested against the real widget in
// od2_background_protection_step_test.dart. What cannot be tested there is that
// onboarding_screen.dart still reaches it: a future edit that drops the page
// from the list, or re-points Skip at the contact gate, would make the step
// unreachable while every widget test above still passed. (Per
// .claude/rules: string-presence tests are not behaviour proof, so each
// assertion below is also covered by a mutant in the OD-2 mutant set.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final onboarding = File('lib/screens/onboarding_screen.dart')
      .readAsStringSync();

  test('the background-protection step is a page in the flow', () {
    expect(onboarding, contains('isBackgroundStep: true'));
    expect(onboarding, contains('OnboardingBackgroundProtectionStep()'));
    expect(onboarding, contains("'onboarding_background_title'.tr()"));
  });

  test('Skip lands on the background step, not on the contact gate', () {
    expect(
      onboarding,
      contains("_pages.indexWhere((p) => p.isBackgroundStep)"),
      reason: 'the skip target must be derived from the flagged step',
    );
    expect(
      onboarding,
      isNot(contains('_skipToContactStep')),
      reason:
          'skipping straight to the gate would let a user never see the step',
    );
  });

  test('only the contact gate can block completion', () {
    // The completion button is disabled by the contact gate alone.
    expect(
      onboarding,
      contains('_isOnContactStep && !_contactGateSatisfied'),
    );
    // Nothing about the background step may gate the button or _finish().
    expect(
      onboarding,
      isNot(contains('isBackgroundStep && !')),
      reason: 'the background step is skippable by owner decision OD-2',
    );
  });

  test('the step never opens Android Settings unprompted', () {
    final step = File(
      'lib/screens/onboarding/onboarding_background_protection_step.dart',
    ).readAsStringSync();
    // requestExactAlarmPermission must be reachable ONLY from the CTA handler.
    final occurrences = RegExp(
      r'requestExactAlarmPermission',
    ).allMatches(step).length;
    expect(
      occurrences,
      1,
      reason:
          'exactly one call site, inside _openSettings; onboarding must not '
          'throw the user into Settings as it opens (OD-2)',
    );
    expect(step, contains('Future<void> _openSettings()'));
    // ...and it must not be called from initState/lifecycle paths.
    expect(step, isNot(contains('_openSettings();\n    _refresh')));
  });

  test('the step re-reads the permission on resume', () {
    final step = File(
      'lib/screens/onboarding/onboarding_background_protection_step.dart',
    ).readAsStringSync();
    expect(step, contains('didChangeAppLifecycleState'));
    expect(step, contains('AppLifecycleState.resumed'));
    expect(step, contains('_refresh()'));
  });

  test('no biometric API is introduced in the new surfaces', () {
    // Checked as an API, not as a word: onboarding_screen.dart already has a
    // comment that the differentiator is "local PIN, no biometrics", and a
    // naive substring match on "biometric" fails on copy that STATES the
    // policy. The repo-wide ban lives in its own policy test; this only guards
    // the two files OD-2 adds.
    for (final path in <String>[
      'lib/screens/onboarding/onboarding_background_protection_step.dart',
      'lib/core/services/safety_readiness_level.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('local_auth')));
      expect(source, isNot(contains('LocalAuthentication')));
      expect(source, isNot(contains('BiometricType')));
    }
  });

  test('USE_EXACT_ALARM is still absent from the manifest', () {
    // OD-2 explicitly forbids bypassing the problem with USE_EXACT_ALARM; the
    // SCHEDULE_EXACT_ALARM approach is kept.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, isNot(contains('USE_EXACT_ALARM')));
    expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
  });
}
