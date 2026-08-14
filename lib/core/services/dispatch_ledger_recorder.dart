import 'call_service.dart';
import 'dispatch_outcome.dart';

/// Records dispatch targets into a [DispatchOutcomeLedger].
///
/// Lives in its own service rather than inside `countdown_screen.dart` and
/// `check_in_service.dart` for two reasons. Both are files the size ratchet
/// already holds as accepted debt, so new logic must not grow them; and the
/// panic path and the Check-In escalation path must project the SAME call
/// result onto the SAME vocabulary. When that projection existed twice, the two
/// copies were one edit away from disagreeing about what "the call failed"
/// means.
abstract final class DispatchLedgerRecorder {
  /// Projects a call result onto the per-target vocabulary.
  ///
  /// A dialer handoff is deliberately TWO entries, not one: the automatic
  /// request genuinely did not go through, and saying only "dialer: ok" would
  /// hide that the user must now press the call button themselves.
  static void recordCallTargets(
    DispatchOutcomeLedger ledger,
    EmergencyCallResult? callResult,
  ) {
    if (callResult == null) {
      ledger.recordOutcome(
        DispatchTarget.primaryCall,
        DispatchTargetOutcome.cancelled,
      );
      return;
    }
    switch (callResult.status) {
      case EmergencyCallStatus.callRequested:
        ledger.recordOutcome(
          DispatchTarget.primaryCall,
          DispatchTargetOutcome.handoffAccepted,
        );
      case EmergencyCallStatus.dialerRequested:
        ledger.recordOutcome(
          DispatchTarget.primaryCall,
          DispatchTargetOutcome.platformRejected,
          reasonCode: 'automaticRequestNotSubmitted',
        );
        ledger.recordOutcome(
          DispatchTarget.dialerHandoff,
          DispatchTargetOutcome.handoffAccepted,
        );
      case EmergencyCallStatus.failed:
        ledger.recordOutcome(
          DispatchTarget.primaryCall,
          DispatchTargetOutcome.platformRejected,
          reasonCode: 'automaticRequestNotSubmitted',
        );
        ledger.recordOutcome(
          DispatchTarget.dialerHandoff,
          DispatchTargetOutcome.noCompatibleHandler,
        );
    }
  }

  /// Runs one bookkeeping target and records its outcome instead of discarding
  /// it. Used by callers that do not go through [EmergencyDispatchPipeline].
  static Future<void> runRecorded(
    DispatchOutcomeLedger ledger,
    DispatchTarget target,
    Future<DispatchTargetOutcome?> Function() operation,
  ) async {
    try {
      final outcome = await operation();
      ledger.recordOutcome(
        target,
        outcome ?? DispatchTargetOutcome.handoffAccepted,
      );
    } on Exception catch (error) {
      _recordFailure(ledger, target, error);
    } on Error catch (error) {
      // See emergency_dispatch_pipeline.dart: catching Error is deliberate in
      // the dispatch fan-out and nowhere else, and it is RECORDED as a failed
      // target rather than swallowed.
      _recordFailure(ledger, target, error);
    }
  }

  static void _recordFailure(
    DispatchOutcomeLedger ledger,
    DispatchTarget target,
    Object error,
  ) => ledger.recordOutcome(
    target,
    DispatchOutcomeClassifier.classifyError(error),
    reasonCode: DispatchOutcomeClassifier.reasonFor(error),
  );
}
