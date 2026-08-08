// Source contract (repo convention for the emergency path — see
// countdown_live_region_test.dart). The panic button's release behaviour is
// safety-relevant in one direction only: the ring may take its time coming
// back on an ABANDONED hold, but the completed hold must carry no motion at
// all, because that path leads straight into dispatch.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/widgets/panic_button.dart').readAsStringSync();
  });

  test('the completed hold resets instantly, with no spring in the way', () {
    expect(
      source,
      contains('if (completed || _reduceMotion || '
          '_progressController.value == 0)'),
      reason:
          'a completed hold, and a reduce-motion user, must both take the '
          'instant reset branch',
    );
    expect(
      RegExp(
        r'if \(completed[\s\S]{0,120}_progressController\.stop\(\);'
        r'\s*_progressController\.reset\(\);\s*return;',
      ).hasMatch(source),
      isTrue,
      reason: 'the instant branch must return before reaching the spring',
    );
  });

  test('release state is known at both call sites, never defaulted', () {
    expect(source, contains('_resetPress({required bool completed})'));
    expect(source, contains('_resetPress(completed: completed)'));
    expect(source, contains('_resetPress(completed: false)'));
    expect(
      source,
      isNot(contains('_resetPress()')),
      reason:
          'an unnamed reset would let a completed hold animate by accident',
    );
  });

  test('the abandoned hold springs back from its current value', () {
    expect(
      source,
      contains(
        'SpringSimulation(Motion.settle, _progressController.value, 0, 0)',
      ),
      reason:
          'starting from the live value is what makes an interrupt look '
          'continuous instead of jumping',
    );
  });

  test('the release animation is never awaited', () {
    expect(
      source,
      isNot(contains('await _progressController.animateWith')),
      reason: 'awaiting it would put motion on the press path',
    );
  });

  test('no bouncy spring is introduced on a safety control', () {
    expect(source, isNot(contains('withDampingRatio')));
    expect(
      source,
      isNot(contains('Motion.bounce')),
      reason: 'overshoot belongs to momentum gestures, not to a panic button',
    );
  });
}
