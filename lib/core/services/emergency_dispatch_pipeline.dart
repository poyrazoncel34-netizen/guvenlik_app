import 'dart:async';

typedef BestEffortErrorHandler = void Function(Object error, StackTrace stack);

/// Preserves the safety ordering boundary between an emergency request and
/// non-critical local bookkeeping.
///
/// The critical operation is awaited exactly once. Only after its typed result
/// is available may queue/log/haptic/UI-notification work run. Each secondary
/// operation has an independent exception boundary, so one failure cannot skip
/// the remaining operations or erase the already-obtained dispatch result.
class EmergencyDispatchPipeline {
  const EmergencyDispatchPipeline({this.onBestEffortError});

  final BestEffortErrorHandler? onBestEffortError;

  Future<T> execute<T>({
    required Future<T> Function() criticalOperation,
    required bool Function(T result) shouldRunBestEffort,
    required Iterable<FutureOr<void> Function()> bestEffortOperations,
  }) async {
    final result = await criticalOperation();
    if (!shouldRunBestEffort(result)) return result;

    for (final operation in bestEffortOperations) {
      try {
        await operation();
      } catch (error, stackTrace) {
        onBestEffortError?.call(error, stackTrace);
      }
    }
    return result;
  }
}
