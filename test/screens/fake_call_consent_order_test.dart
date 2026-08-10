import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D7 / H6c: the fake-call screen shows the first-use warning (which grants
/// fake-call consent on accept) BEFORE the defense-in-depth consent gate, so a
/// cold first use can grant consent on this screen rather than being blocked.
void main() {
  test('fake_call_screen runs first-use warning before the consent gate', () {
    final src = File('lib/screens/fake_call_screen.dart').readAsStringSync();
    final warnIdx = src.indexOf('await _checkFirstUseWarning()');
    final gateIdx = src.indexOf('ConsentGateService.requireConsent');
    expect(warnIdx, isNot(-1), reason: 'first-use warning must be awaited');
    expect(gateIdx, isNot(-1));
    expect(
      warnIdx < gateIdx,
      isTrue,
      reason: 'the first-use warning (which grants consent) must precede the '
          'consent gate',
    );
  });

  test('the ringtone only starts after the consent gate passes', () {
    final src = File('lib/screens/fake_call_screen.dart').readAsStringSync();
    final gateIdx = src.indexOf('ConsentGateService.requireConsent');
    // The first _startRingtone() call in initState used to run before any
    // gate, so a scheduled fake call played audio on a device whose owner had
    // withdrawn fake-call consent. The sound IS the feature; playing it first
    // made the gate cosmetic.
    final initState = src.substring(
      src.indexOf('void initState()'),
      src.indexOf('Future<void> _checkFirstUseWarning()'),
    );
    final ringIdx = initState.indexOf('_startRingtone();');
    expect(ringIdx, isNot(-1));
    expect(
      initState.indexOf('ConsentGateService.requireConsent') < ringIdx,
      isTrue,
      reason:
          'Withdrawn consent must mean silence, not a ringtone that is '
          'stopped a moment later.',
    );
    expect(gateIdx, isNot(-1));
  });
}
