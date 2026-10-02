// WHICH surface gets WHICH overlay policy is the safety-relevant decision, and
// it is not inferable from behaviour in a unit test -- so it is pinned here.
//
// Getting it wrong in one direction is a tapjacking hole. Getting it wrong in
// the other direction locks an owner out of their own safety app:
// `filterTouchesWhenObscured` discards obscured touches with NO opacity
// threshold, stricter than Android 12+'s own untrusted-touch blocking, and
// minSdk here is 29 where the platform does none of it. Screen dimmers and
// blue-light filters are exactly the overlays that difference reaches.
//
// So BLOCK is admissible only where refusing the action is a safe answer. On a
// gateway -- the unlock PIN pad, the consent flow -- it is not: a user who
// cannot tap cannot open the app, cannot reach the panic button, and cannot
// even use "PIN'imi unuttum", which is a touch like any other.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

/// Source with `//` line comments removed, so prose discussing a policy cannot
/// be mistaken for the policy itself.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final comment = line.indexOf('//');
      return comment == -1 ? line : line.substring(0, comment);
    })
    .join('\n');

const _gatewaySurfaces = <String, String>{
  'lib/screens/app_unlock_screen.dart': 'the app unlock PIN pad',
  'lib/screens/legal/unified_consent_screen.dart': 'the consent flow',
};

const _nonGatewaySurfaces = <String, String>{
  'lib/screens/settings_legal/data_export_screen.dart': 'the data export',
  'lib/core/utils/app_reset_helper.dart': 'the local-data reset',
};

/// Surfaces that must not be guarded at all: a discarded or delayed touch here
/// is a delayed emergency call.
const _emergencyPath = <String>[
  'lib/screens/countdown_screen.dart',
  'lib/widgets/panic_button.dart',
  'lib/core/widgets/safety_session_pin_gate.dart',
  'lib/core/widgets/emergency_trigger_host.dart',
];

void main() {
  group('gateway surfaces warn and never block', () {
    _gatewaySurfaces.forEach((path, label) {
      test('$label asks for warn', () {
        final code = _codeOnly(_source(path));

        expect(
          code,
          contains('OverlayTouchPolicy.warn'),
          reason: '$label must claim the warn policy.',
        );
        expect(
          code.contains('OverlayTouchPolicy.block'),
          isFalse,
          reason:
              'BLOCK on $label discards touches with no opacity threshold. A '
              'user running a screen dimmer could not open the app at all -- '
              'panic button included -- and no in-app escape exists, because '
              'every escape is also a touch.',
        );
      });
    });
  });

  group('non-gateway surfaces block', () {
    _nonGatewaySurfaces.forEach((path, label) {
      test('$label asks for block', () {
        expect(
          _codeOnly(_source(path)),
          contains('OverlayTouchPolicy.block'),
          reason:
              '$label discloses or destroys user data, and refusing it while '
              'another app is drawn over the confirmation is a safe answer.',
        );
      });
    });
  });

  group('the emergency path carries no overlay policy', () {
    for (final path in _emergencyPath) {
      test('${path.split('/').last} is unguarded', () {
        final code = _codeOnly(_source(path));

        expect(
          code.contains('OverlayTouchPolicy'),
          isFalse,
          reason:
              'A benign overlay -- a chat head, a volume panel, a navigation '
              'card -- must never be able to swallow a panic press or the '
              'cancellation of an armed countdown.',
        );
        expect(code.contains('OverlayTouchShield'), isFalse);
      });
    }
  });

  test('only BLOCK reaches the framework touch filter', () {
    // The Kotlin side owns this decision (OverlayTouchGuardTest proves the
    // mapping). Pinned here too so the Dart-side policy names cannot be
    // repointed at a stricter native behaviour without a failing test.
    final kotlin = _source(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/security/'
      'OverlayTouchGuard.kt',
    );

    expect(
      kotlin,
      contains('fun filterTouches(policy: Policy): Boolean = policy == Policy.BLOCK'),
      reason:
          'If WARN ever starts setting filterTouchesWhenObscured, every gateway '
          'surface silently becomes lock-out capable.',
    );
  });
}
