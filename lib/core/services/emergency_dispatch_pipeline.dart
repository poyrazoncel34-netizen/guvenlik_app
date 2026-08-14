import 'dart:async';

import 'dispatch_outcome.dart';

typedef BestEffortErrorHandler = void Function(Object error, StackTrace stack);

/// One non-critical dispatch step, named by the target it serves.
///
/// The step is labelled rather than anonymous because an unlabelled failure can
/// only be reported as "something failed" -- which is the aggregate this whole
/// model exists to replace. [run] may return an explicit outcome when the step
/// can distinguish more than "it worked / it threw" (e.g. a notification the
/// user has switched off is [DispatchTargetOutcome.suppressedByUserSetting],
/// not a failure and not a success). Returning null means the handoff was
/// accepted.
class BestEffortStep {
  const BestEffortStep({required this.target, required this.run});

  /// For steps whose only signal is "it completed or it threw". The adapter is
  /// explicit rather than implicit so that a step CAPABLE of reporting a richer
  /// outcome cannot silently be treated as a binary one.
  factory BestEffortStep.effect({
    required DispatchTarget target,
    required Future<void> Function() run,
  }) => BestEffortStep(
    target: target,
    run: () async {
      await run();
      return null;
    },
  );

  final DispatchTarget target;
  final FutureOr<DispatchTargetOutcome?> Function() run;
}

/// Result of one dispatch: the critical value plus the per-target ledger.
class DispatchExecution<T> {
  const DispatchExecution({required this.result, required this.ledger});

  final T result;
  final DispatchOutcomeLedger ledger;
}

/// Preserves the safety ordering boundary between an emergency request and
/// non-critical local bookkeeping.
///
/// The critical operation is awaited exactly once. Only after its typed result
/// is available may queue/log/haptic/UI-notification work run. Each secondary
/// operation has an independent exception boundary, so one failure cannot skip
/// the remaining operations or erase the already-obtained dispatch result --
/// and, since MP-01-027, cannot vanish either: every step's outcome lands in
/// the ledger the caller renders.
class EmergencyDispatchPipeline {
  const EmergencyDispatchPipeline({this.onBestEffortError});

  final BestEffortErrorHandler? onBestEffortError;

  Future<DispatchExecution<T>> execute<T>({
    required String dispatchId,
    required Future<T> Function() criticalOperation,
    required bool Function(T result) shouldRunBestEffort,
    required Iterable<BestEffortStep> bestEffortOperations,
    void Function(DispatchOutcomeLedger ledger, T result)? recordCriticalOutcome,
  }) async {
    final ledger = DispatchOutcomeLedger(dispatchId: dispatchId);
    final result = await criticalOperation();
    recordCriticalOutcome?.call(ledger, result);

    if (!shouldRunBestEffort(result)) {
      // The remaining targets were never attempted. Recording that explicitly
      // is what stops a cancelled dispatch from reading as a failed one.
      for (final step in bestEffortOperations) {
        ledger.recordOutcome(step.target, DispatchTargetOutcome.cancelled);
      }
      return DispatchExecution<T>(result: result, ledger: ledger);
    }

    for (final step in bestEffortOperations) {
      try {
        final outcome = await step.run();
        ledger.recordOutcome(
          step.target,
          outcome ?? DispatchTargetOutcome.handoffAccepted,
        );
      } on Exception catch (error, stackTrace) {
        _recordFailure(ledger, step, error, stackTrace);
      } on Error catch (error, stackTrace) {
        // Catching Error is normally forbidden (dart/coding-style.md). It is
        // deliberate here and nowhere else: an Error thrown by a best-effort
        // step is a bug in bookkeeping, and aborting the remaining emergency
        // targets because the timeline row had a bug would trade a small defect
        // for a large one. It is recorded as a FAILED target, never swallowed.
        _recordFailure(ledger, step, error, stackTrace);
      }
    }
    return DispatchExecution<T>(result: result, ledger: ledger);
  }

  void _recordFailure(
    DispatchOutcomeLedger ledger,
    BestEffortStep step,
    Object error,
    StackTrace stackTrace,
  ) {
    ledger.recordOutcome(
      step.target,
      DispatchOutcomeClassifier.classifyError(error),
      reasonCode: DispatchOutcomeClassifier.reasonFor(error),
    );
    onBestEffortError?.call(error, stackTrace);
  }
}
