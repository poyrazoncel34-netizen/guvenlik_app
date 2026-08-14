import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A panic expiry must claim/dispatch through the native coordinator before
/// non-critical Flutter bookkeeping. Alarm cancellation is not a dispatch
/// prerequisite and widget lifecycle is not cancellation authority.
///
/// This test used to assert the ordering by comparing string offsets inside
/// `_executeEmergency`: `dispatchEmergencySession` had to appear textually
/// before `OfflineQueueService.instance.enqueue` and friends. That worked only
/// while the bookkeeping calls were inline in the screen. MP-01-027 moved them
/// into `EmergencyBookkeeping` so each one could carry its own outcome, and the
/// old assertion then compared against `indexOf(...) == -1` — which is `false <
/// -1`, i.e. it would have failed for the RIGHT change and passed for a screen
/// with no dispatch at all.
///
/// The invariant is now checked where it is actually enforced, and more
/// strictly than before: the screen must not perform bookkeeping directly at
/// all, and the pipeline must await the critical operation before the
/// best-effort loop.
void main() {
  late String screen;
  late String pipeline;
  late String bookkeeping;

  const nonCriticalCalls = <String>[
    'OfflineQueueService.instance.enqueue',
    'ActivityService.logEvent(\n        type: ActivityType.emergencyTriggered',
    'HapticService.emergencyTriggered',
    'NotificationService.instance.showEmergencyAlert',
  ];

  setUpAll(() {
    screen = File('lib/screens/countdown_screen.dart').readAsStringSync();
    pipeline = File(
      'lib/core/services/emergency_dispatch_pipeline.dart',
    ).readAsStringSync();
    bookkeeping = File(
      'lib/core/services/emergency_bookkeeping.dart',
    ).readAsStringSync();
  });

  test('the dispatch path still dispatches', () {
    final executeStart = screen.indexOf('Future<void> _executeEmergency()');
    expect(executeStart, isNot(-1), reason: '_executeEmergency was renamed');
    final executeEnd = screen.indexOf(
      'Future<void> _showBlockingFailure',
      executeStart,
    );
    expect(executeEnd, greaterThan(executeStart));
    expect(
      screen.substring(executeStart, executeEnd),
      contains('dispatchEmergencySession'),
    );
  });

  test('the screen performs no emergency bookkeeping of its own', () {
    final executeStart = screen.indexOf('Future<void> _executeEmergency()');
    final executeEnd = screen.indexOf(
      'Future<void> _showBlockingFailure',
      executeStart,
    );
    final body = screen.substring(executeStart, executeEnd);
    for (final call in nonCriticalCalls) {
      expect(
        body,
        isNot(contains(call)),
        reason:
            'bookkeeping moved back into the screen, where it can neither be '
            'ordered nor given a per-target outcome',
      );
    }
    expect(body, contains('EmergencyBookkeeping.panicStepsWithDefaultCopy()'));
  });

  test('every bookkeeping call lives behind a labelled step', () {
    for (final call in nonCriticalCalls) {
      expect(bookkeeping, contains(call.split('(').first));
    }
    // A step without a target cannot appear in a per-target list.
    final steps = RegExp(r'BestEffortStep(\.effect)?\(').allMatches(bookkeeping);
    final targets = RegExp(r'target: DispatchTarget\.').allMatches(bookkeeping);
    expect(steps.length, nonCriticalCalls.length);
    expect(targets.length, steps.length);
  });

  test('the pipeline awaits the critical operation before any step', () {
    final critical = pipeline.indexOf('await criticalOperation()');
    final loop = pipeline.indexOf('for (final step in bestEffortOperations)');
    final run = pipeline.indexOf('await step.run()');
    expect(critical, isNot(-1));
    expect(loop, greaterThan(critical));
    expect(run, greaterThan(loop));
  });

  test('panic dispatch path never cancels the native session as cleanup', () {
    final makeCallStart = screen.indexOf('Future<void> _makeEmergencyCall()');
    final cancelStart = screen.indexOf(
      'Future<void> _cancelCountdownAndExit',
      makeCallStart,
    );
    final dispatchBody = screen.substring(makeCallStart, cancelStart);
    expect(dispatchBody, isNot(contains('cancelCountdownAlarm')));
    expect(dispatchBody, isNot(contains('cancelEmergencySession')));
  });
}
