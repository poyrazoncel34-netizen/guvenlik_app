// Verifies the PanicButton's screen-reader (TalkBack/VoiceOver) activation
// path. Without this, the security app's single SOS entry point is
// unreachable to blind/low-vision users — see the audit on main.
//
// Convention in this repo: panic_button widget tests are source-level
// contracts (see panic_button_test.dart, panic_button_instant_call_test.dart).
// Full widget testing is impractical because PanicButton depends on
// EasyLocalization, Provider scope, platform channels, and Navigator
// transitions to CountdownScreen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/widgets/panic_button.dart').readAsStringSync();
  });

  group('PanicButton screen-reader activation contract', () {
    test('reads MediaQuery.accessibleNavigation to branch behaviour', () {
      expect(
        source.contains('MediaQuery.of(context).accessibleNavigation'),
        isTrue,
        reason:
            'PanicButton must detect when an assistive technology is active '
            'so it can swap the 3-second-hold UX for a tap+confirm UX.',
      );
    });

    test('exposes an onTap handler on the Semantics wrapper', () {
      // Without onTap on Semantics, TalkBack's double-tap gesture cannot
      // activate the button — it does NOT reach the underlying
      // GestureDetector's onLongPressStart in any reliable way.
      expect(
        source.contains('onTap: accessibleNavigation ? _onAccessibleTap'),
        isTrue,
        reason:
            'Semantics.onTap must be wired when accessibleNavigation is true.',
      );
    });

    test(
      'silences the long-press handlers when AT is active to prevent '
      'double-dispatch from stray gestures',
      () {
        expect(
          source.contains(
            'onLongPressStart: accessibleNavigation ? null : _onPressStart',
          ),
          isTrue,
          reason:
              'When AT is on, the long-press path must be disabled so a '
              'stray gesture cannot start a parallel countdown.',
        );
        expect(
          source.contains(
            'onLongPressEnd: accessibleNavigation ? null : _onPressEnd',
          ),
          isTrue,
        );
      },
    );

    test('preserves the original 3-second-hold path when AT is off', () {
      // Sighted users must keep the existing dead-man-switch UX — this is
      // the accidental-trigger guard for the non-AT case.
      expect(
        source.contains('_onPressStart(LongPressStartDetails details)'),
        isTrue,
        reason:
            'The original long-press handler must still exist for non-AT use.',
      );
      expect(
        source.contains('_onPressEnd(LongPressEndDetails details)'),
        isTrue,
      );
      // And the 3-second AnimationController must still drive the ring.
      expect(
        source.contains('duration: const Duration(seconds: 3)'),
        isTrue,
        reason: '3-second progress ring is the visual contract for sighted use.',
      );
    });

    test('confirmation dialog gates the AT activation path', () {
      // The dialog replaces the hold-time as the accidental-trigger guard.
      // Subscription gate and feature warning must run BEFORE the dialog so
      // the user is not prompted to confirm something the app will refuse.
      expect(source.contains('_onAccessibleTap'), isTrue);
      final methodStart = source.indexOf(
        'Future<void> _onAccessibleTap() async',
      );
      expect(methodStart, isNot(-1));
      // Method body ends at the next top-level method declaration. Look for
      // any 'Future<void> _' or '  void _' or 'Widget _' anchor after
      // methodStart, whichever comes first. Fall back to end-of-file.
      int methodEnd = source.length;
      for (final anchor in [
        'Future<void> _onPressStart',
        '  void _onPressEnd',
        '  void _openCountdownScreen',
        '  Widget build',
        '  Widget _',
        '  List<Widget>',
      ]) {
        final idx = source.indexOf(anchor, methodStart + 1);
        if (idx != -1 && idx < methodEnd) methodEnd = idx;
      }
      expect(
        methodEnd > methodStart,
        isTrue,
        reason: 'Could not locate end of _onAccessibleTap body',
      );
      final methodBody = source.substring(methodStart, methodEnd);

      expect(
        methodBody.contains('SubscriptionGate.ensureAccess'),
        isTrue,
        reason: 'Subscription gate must run before the confirmation dialog.',
      );
      expect(
        methodBody.contains('FeatureWarningHelper.showIfNeeded'),
        isTrue,
        reason: 'First-use warning must run before the confirmation dialog.',
      );
      expect(
        methodBody.contains('showDialog<bool>'),
        isTrue,
        reason: 'AT path must show an explicit confirm dialog.',
      );
      expect(
        methodBody.contains('barrierDismissible: false'),
        isTrue,
        reason:
            'The confirm dialog must require an explicit choice; an outside '
            'tap should not silently dismiss the SOS opportunity.',
      );
      expect(
        methodBody.contains('_openCountdownScreen'),
        isTrue,
        reason: 'On confirm, the dialog must hand off to the countdown.',
      );
    });

    test('the AT-only hint replaces the misleading hold-instruction', () {
      // Otherwise TalkBack would say "Basılı tutarak..." for a flow the
      // user cannot perform via TalkBack gestures.
      expect(source.contains("panic_button_a11y_hint"), isTrue);
      expect(source.contains("panic_button_a11y_locked_hint"), isTrue);
    });
  });

  group('Translation keys for AT path are present (TR + EN)', () {
    const expected = [
      'panic_button_a11y_hint',
      'panic_button_a11y_locked_hint',
      'panic_button_a11y_confirm_title',
      'panic_button_a11y_confirm_body',
      'panic_button_a11y_confirm_start',
    ];

    test('tr-TR.json defines all AT keys', () {
      final tr =
          jsonDecode(File('assets/translations/tr-TR.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final k in expected) {
        expect(tr.containsKey(k), isTrue, reason: 'tr-TR missing $k');
      }
    });

    test('en-US.json defines all AT keys', () {
      final en =
          jsonDecode(File('assets/translations/en-US.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final k in expected) {
        expect(en.containsKey(k), isTrue, reason: 'en-US missing $k');
      }
    });
  });
}
