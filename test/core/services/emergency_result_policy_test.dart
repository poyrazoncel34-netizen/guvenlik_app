// MP-01-027 / FIR-01 -- the join between the dispatch ledger and the copy the
// user is actually shown.
//
// Why this file exists, in the reviewer's words: "A test of DispatchLedger
// alone is insufficient. A renderer test alone is insufficient. You must test
// the production branch joining the two." The ledger tests
// (emergency_dispatch_pipeline_test.dart) prove the DATA stays distinguishable;
// emergency_per_target_outcome_test.dart proves the RESULT SCREEN renders it.
// Neither could see the panic path's failure branch, which returned before any
// renderer and told the user "Hicbir islem tamamlanmadi" while its own ledger
// recorded four targets reached.
//
// Every scenario below builds its ledger by RUNNING the real
// EmergencyDispatchPipeline with the real recorder, then asks the real
// production decision function what the user is told.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/call_service.dart';
import 'package:guvenlik_app/core/services/dispatch_ledger_recorder.dart';
import 'package:guvenlik_app/core/services/dispatch_outcome.dart';
import 'package:guvenlik_app/core/services/emergency_dispatch_pipeline.dart';
import 'package:guvenlik_app/core/services/emergency_result_policy.dart';

/// Runs the REAL pipeline the panic path runs, with the same
/// `shouldRunBestEffort` predicate `countdown_screen.dart` passes.
Future<DispatchExecution<EmergencyCallResult?>> runPanicDispatch({
  required EmergencyCallResult? callResult,
  required List<BestEffortStep> steps,
}) {
  const pipeline = EmergencyDispatchPipeline();
  return pipeline.execute<EmergencyCallResult?>(
    dispatchId: 'fir01',
    criticalOperation: () async => callResult,
    recordCriticalOutcome: DispatchLedgerRecorder.recordCallTargets,
    shouldRunBestEffort: (result) => result != null,
    bestEffortOperations: steps,
  );
}

BestEffortStep reached(DispatchTarget target) =>
    BestEffortStep.effect(target: target, run: () async {});

BestEffortStep threw(DispatchTarget target, Object error) =>
    BestEffortStep(target: target, run: () async => throw error);

BestEffortStep outcome(DispatchTarget target, DispatchTargetOutcome value) =>
    BestEffortStep(target: target, run: () async => value);

/// The four bookkeeping targets the panic path actually fans out to.
const _panicTargets = <DispatchTarget>[
  DispatchTarget.offlineQueue,
  DispatchTarget.safetyTimeline,
  DispatchTarget.haptic,
  DispatchTarget.alertNotification,
];

void main() {
  group('the claim never contradicts the ledger', () {
    test('A. call failed + every bookkeeping target failed -> absolute copy is '
        'permitted, because it is TRUE', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [for (final t in _panicTargets) threw(t, StateError('down'))],
      );
      final ledger = execution.ledger;
      expect(ledger.reachedCount, 0);
      expect(ledger.summary, DispatchOutcomeSummary.noTargetReached);

      final decision = EmergencyResultPolicy.decide(
        callResult: execution.result,
        ledger: ledger,
      );
      expect(decision.surface, EmergencyResultSurface.blockingFailure);
      final copy = decision.failureCopy;
      expect(copy, isNotNull);
      expect(copy!.claimsNothingCompleted, isTrue);
      expect(copy.titleKey, EmergencyResultPolicy.totalFailureTitleKey);
      expect(copy.bodyKey, EmergencyResultPolicy.totalFailureBodyKey);
    });

    test('B. call failed + SOME bookkeeping reached -> the absolute claim is '
        'forbidden (the exact reproduced defect)', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [
          reached(DispatchTarget.offlineQueue),
          reached(DispatchTarget.safetyTimeline),
          threw(DispatchTarget.haptic, StateError('no vibrator')),
          outcome(DispatchTarget.alertNotification,
              DispatchTargetOutcome.suppressedByUserSetting),
        ],
      );
      final ledger = execution.ledger;
      // The state the reviewer reproduced at HEAD, minus the two extra reached
      // targets their four-step run produced: reached > 0 with a failed call.
      expect(ledger.reachedCount, greaterThan(0));
      expect(ledger.isPartial, isTrue);
      expect(ledger.summary, DispatchOutcomeSummary.mixed);

      final decision = EmergencyResultPolicy.decide(
        callResult: execution.result,
        ledger: ledger,
      );
      final copy = decision.failureCopy;
      expect(copy, isNotNull);
      expect(copy!.claimsNothingCompleted, isFalse,
          reason: 'four targets were handed off; "no action completed" is a '
              'false statement about this dispatch');
      expect(copy.titleKey, isNot(EmergencyResultPolicy.totalFailureTitleKey));
      expect(copy.bodyKey, isNot(EmergencyResultPolicy.totalFailureBodyKey));
      expect(copy.ledger, same(ledger),
          reason: 'the failure surface must carry the ledger, not discard it');
    });

    test('B2. the reviewer\'s exact ledger shape: reached 4, notReached 2',
        () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [for (final t in _panicTargets) reached(t)],
      );
      final ledger = execution.ledger;
      // primaryCall platformRejected + dialerHandoff noCompatibleHandler = 2
      // notReached; the four bookkeeping targets = 4 reached.
      expect(ledger.reachedCount, 4);
      expect(ledger.notReachedCount, 2);
      expect(ledger.isPartial, isTrue);
      expect(ledger.summary, DispatchOutcomeSummary.mixed);

      final copy = EmergencyResultPolicy.decide(
        callResult: execution.result,
        ledger: ledger,
      ).failureCopy;
      expect(copy!.claimsNothingCompleted, isFalse);
      expect(copy.reachedCount, 4);
    });

    test('C. call failed + EVERY bookkeeping target reached', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [for (final t in _panicTargets) reached(t)],
      );
      final copy = EmergencyResultPolicy.decide(
        callResult: execution.result,
        ledger: execution.ledger,
      ).failureCopy;
      expect(copy!.claimsNothingCompleted, isFalse);
    });

    test('D. handoff accepted + mixed bookkeeping -> the result screen, which '
        'renders the ledger itself', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.requested('+905001234567'),
        steps: [
          reached(DispatchTarget.offlineQueue),
          threw(DispatchTarget.safetyTimeline, StateError('db')),
          reached(DispatchTarget.haptic),
          outcome(DispatchTarget.alertNotification,
              DispatchTargetOutcome.permissionDenied),
        ],
      );
      expect(execution.ledger.isPartial, isTrue);
      final decision = EmergencyResultPolicy.decide(
        callResult: execution.result,
        ledger: execution.ledger,
      );
      expect(decision.surface, EmergencyResultSurface.resultScreen);
      expect(decision.failureCopy, isNull);
    });

    test('D2. dialer handoff is not a failure', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.dialer('+905001234567'),
        steps: [for (final t in _panicTargets) reached(t)],
      );
      expect(
        EmergencyResultPolicy.decide(
          callResult: execution.result,
          ledger: execution.ledger,
        ).surface,
        EmergencyResultSurface.resultScreen,
      );
    });

    test('E. nothing attempted (cancelled dispatch) shows neither surface',
        () async {
      final execution = await runPanicDispatch(
        callResult: null,
        steps: [for (final t in _panicTargets) reached(t)],
      );
      final ledger = execution.ledger;
      expect(ledger.summary, DispatchOutcomeSummary.nothingAttempted);
      expect(ledger.reachedCount, 0);

      final decision = EmergencyResultPolicy.decide(
        callResult: execution.result,
        ledger: ledger,
      );
      expect(decision.surface, EmergencyResultSurface.none,
          reason: 'a cancelled dispatch claims nothing at all');
      expect(decision.failureCopy, isNull);
    });

    test('F. platform rejection of a bookkeeping target is notReached, and a '
        'failed call beside it still forbids nothing-completed only when it is '
        'the ONLY thing that happened', () async {
      final rejected = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [
          threw(DispatchTarget.offlineQueue,
              PlatformException(code: 'io_error')),
          threw(DispatchTarget.safetyTimeline,
              PlatformException(code: 'ACTIVITY_NOT_FOUND')),
          threw(DispatchTarget.haptic, MissingPluginException('no haptics')),
          outcome(DispatchTarget.alertNotification,
              DispatchTargetOutcome.platformRejected),
        ],
      );
      expect(rejected.ledger.reachedCount, 0);
      expect(
        EmergencyResultPolicy.decide(
          callResult: rejected.result,
          ledger: rejected.ledger,
        ).failureCopy!.claimsNothingCompleted,
        isTrue,
      );
    });

    test('G. permission denial alone does not license the absolute claim when '
        'another target was reached', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [
          outcome(DispatchTarget.alertNotification,
              DispatchTargetOutcome.permissionDenied),
          reached(DispatchTarget.safetyTimeline),
        ],
      );
      expect(execution.ledger.notReachedCount, greaterThan(0));
      expect(execution.ledger.reachedCount, greaterThan(0));
      expect(
        EmergencyResultPolicy.decide(
          callResult: execution.result,
          ledger: execution.ledger,
        ).failureCopy!.claimsNothingCompleted,
        isFalse,
      );
    });

    test('an unconfirmed target is not a reached one', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.failed('+905001234567'),
        steps: [
          outcome(DispatchTarget.alertNotification,
              DispatchTargetOutcome.handoffUnconfirmed),
        ],
      );
      expect(execution.ledger.unknownCount, 1);
      expect(execution.ledger.reachedCount, 0);
      expect(
        EmergencyResultPolicy.decide(
          callResult: execution.result,
          ledger: execution.ledger,
        ).failureCopy!.claimsNothingCompleted,
        isTrue,
        reason: 'unknown is neither reached nor a licence to deny it happened; '
            'the ledger is still rendered beside the copy',
      );
    });
  });

  group('the other three failure surfaces the panic path can reach', () {
    test('arm rejection keeps its specific reason sentence and may claim '
        'nothing completed -- nothing was attempted', () {
      final copy = EmergencyResultPolicy.failureCopy(
        reason: EmergencyFailureReason.armRejected,
        bodyKeyOverride: 'panic_arm_blocked_entitlement',
      );
      expect(copy.claimsNothingCompleted, isTrue);
      expect(copy.titleKey, EmergencyResultPolicy.totalFailureTitleKey);
      expect(copy.bodyKey, 'panic_arm_blocked_entitlement');
      expect(copy.ledger, isNull);
    });

    test('a body override cannot smuggle an absolute claim over a ledger that '
        'reached targets', () {
      final ledger = DispatchOutcomeLedger(dispatchId: 'override')
        ..recordOutcome(DispatchTarget.safetyTimeline,
            DispatchTargetOutcome.handoffAccepted);
      final copy = EmergencyResultPolicy.failureCopy(
        reason: EmergencyFailureReason.callFailed,
        ledger: ledger,
        bodyKeyOverride: 'emergency_total_failure_body',
      );
      expect(copy.claimsNothingCompleted, isFalse);
      expect(copy.bodyKey, EmergencyResultPolicy.partialFailureBodyKey,
          reason: 'the override is honoured only while the absolute claim is '
              'still true');
    });

    test('a dispatch that threw has no ledger, so the absolute claim holds', () {
      final copy = EmergencyResultPolicy.failureCopy(
        reason: EmergencyFailureReason.dispatchThrew,
      );
      expect(copy.claimsNothingCompleted, isTrue);
      expect(copy.ledger, isNull);
    });

    test('navigation failure AFTER a handed-off call must not claim nothing '
        'completed either', () async {
      final execution = await runPanicDispatch(
        callResult: EmergencyCallResult.requested('+905001234567'),
        steps: [for (final t in _panicTargets) reached(t)],
      );
      final copy = EmergencyResultPolicy.failureCopy(
        reason: EmergencyFailureReason.resultScreenUnavailable,
        ledger: execution.ledger,
      );
      expect(copy.claimsNothingCompleted, isFalse,
          reason: 'the call WAS handed off; only the screen failed');
      expect(copy.ledger, isNotNull);
    });
  });

  group('the invariant itself', () {
    test('supportsTotalFailureClaim is exactly "no target reached"', () {
      expect(EmergencyResultPolicy.supportsTotalFailureClaim(null), isTrue);

      final empty = DispatchOutcomeLedger(dispatchId: 'e');
      expect(EmergencyResultPolicy.supportsTotalFailureClaim(empty), isTrue);

      for (final value in DispatchTargetOutcome.values) {
        final ledger = DispatchOutcomeLedger(dispatchId: value.name)
          ..recordOutcome(DispatchTarget.alertNotification, value);
        expect(
          EmergencyResultPolicy.supportsTotalFailureClaim(ledger),
          value.reachability != DispatchReachability.reached,
          reason: 'only a REACHED target may forbid the absolute claim; '
              '${value.name} is ${value.reachability.name}',
        );
      }
    });
  });
}
