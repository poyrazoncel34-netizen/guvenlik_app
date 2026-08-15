import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-device matrix distinguishes process death from force-stop', () {
    final matrix = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();

    expect(matrix, contains('adb shell am kill'));
    expect(matrix, contains('Android 15'));
    expect(matrix, contains('cancels all pending intents'));
    expect(
      matrix,
      contains(
        'https://developer.android.com/about/versions/15/behavior-changes-all',
      ),
    );
    expect(
      matrix,
      isNot(contains('FORCE-STOP the app; let main+grace expire')),
    );
    expect(matrix, isNot(contains('Dedup race under force-stop')));
  });

  /// RER-01. `MP-41-017` was filed as an EXTERNAL_BLOCKER while its own
  /// remediation named a repository edit that had not been made: the matrix
  /// covered C1-C4 and had no incoming-call case at all. Authoring the case is
  /// repository work; only RUNNING it needs hardware. This test is what makes
  /// deleting or hollowing out that case red, so the row cannot quietly revert
  /// to "external" with the in-repo half undone again.
  test('incoming-call-during-countdown interruption family is authored', () {
    final matrix = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();

    // The three rows, and the fact that they are one family.
    for (final id in const <String>['| C5 |', '| C6 |', '| C7 |']) {
      expect(matrix, contains(id), reason: '$id row is missing from section C');
    }
    expect(matrix, contains('Incoming call during armed countdown \u2014 REJECT'));
    expect(matrix, contains('Incoming call during armed countdown \u2014 ACCEPT'));
    expect(
      matrix,
      contains('Incoming call inside the final-3 s dispatch window'),
    );

    // Every section the case is required to specify. A row that keeps the ID
    // but loses its expectations is the same defect with a tidier surface.
    for (final heading in const <String>[
      '**PRECONDITIONS**',
      '**STEPS**',
      '**EXPECTED UI STATE**',
      '**EXPECTED COUNTDOWN STATE**',
      '**EXPECTED AUDIO/HAPTIC STATE**',
      '**EXPECTED APP LIFECYCLE BEHAVIOR**',
      '**EXPECTED POST-CALL STATE**',
      '**FAIL CRITERIA**',
      '**EVIDENCE TO CAPTURE**',
    ]) {
      expect(
        matrix,
        contains(heading),
        reason: '$heading is required by the RER-01 case specification',
      );
    }

    // The substantive expectations the reviewer named. These are the claims
    // that make the case worth running rather than a checklist of nouns.
    expect(matrix, contains('Never resets to 10'));
    expect(matrix, contains('Exactly one** dispatch per armed generation'));
    expect(matrix, contains('No false completed state'));
    expect(matrix, contains('No lost security gate'));
    expect(
      matrix,
      contains('A **third** phone able to call the device under test'),
      reason: 'the caller must be a third device, never the emergency target',
    );
  });

  /// The case must stay consistent with the implementation it describes. If the
  /// countdown ever stops being deadline-derived, or a siren is added to the
  /// panic path, the QA expectations above become false and must be rewritten
  /// rather than left to mislead an operator.
  test('incoming-call case matches the countdown implementation it describes', () {
    final countdown =
        File('lib/screens/countdown_screen.dart').readAsStringSync();

    // Deadline-derived, not tick-decrementing: this is why an interruption
    // cannot make the countdown drift, which the case asserts.
    expect(countdown, contains('CountdownClock.secondsUntil('));
    // Not a lifecycle observer: the case says the design reacts to no callback.
    expect(countdown, isNot(contains('WidgetsBindingObserver')));
    expect(countdown, isNot(contains('didChangeAppLifecycleState')));
    // Haptic-only audio surface in this path.
    expect(countdown, contains('HapticService.countdownTick'));
    expect(countdown, isNot(contains('Siren')));
    // In-process single-dispatch guard the "exactly one" expectation rests on.
    expect(countdown, contains('_emergencyDispatched'));
  });

  test('real-device evidence language matches the retired FGS design', () {
    final matrix = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();
    final submission = File('docs/play-submission.md').readAsStringSync();

    expect(matrix, isNot(contains('FGS notification content')));
    expect(matrix, isNot(contains('Foreground-service notification')));
    expect(matrix, isNot(contains('Alarm/FGS survives')));
    expect(matrix, isNot(contains('FGS demo video capture')));
    expect(matrix, isNot(contains('with DnD bypass')));
    expect(submission, isNot(contains('Console FGS beyan formuna eklenir')));
  });
}
