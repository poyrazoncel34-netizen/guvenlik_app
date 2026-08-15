import 'dispatch_outcome.dart';
import 'local_logger_service.dart';
import 'notification_service.dart';

/// Posts a safety WARNING notification and REPORTS what happened to it.
///
/// Why this exists
/// ---------------
/// Two safety warnings -- the Check-In grace notice and the Safe Walk
/// pre-expiry notice -- are the user's last cue before a session escalates to
/// a call. Both used to discard `showEmergencyAlert`'s typed outcome: the
/// Check-In one awaited it inside `catch (_) { // Notification not critical }`,
/// the Safe Walk one neither awaited nor captured it. A warning the user had
/// switched off was therefore indistinguishable from one Android displayed, at
/// the exact moment the difference decides whether they are called.
///
/// The contract
/// ------------
/// * The outcome is always returned. Callers decide what to SAY about it; this
///   file decides nothing about presentation.
/// * A not-reached outcome is recorded once, here, under an allowlisted code
///   carrying no channel, session or contact data.
/// * It never throws. Its callers are a grace ticker and a session timer; a
///   notification bug must not be able to stop either.
abstract final class SafetyAlertDispatch {
  static Future<DispatchTargetOutcome> postWarning({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final outcome = await NotificationService.instance.showEmergencyAlert(
        id: id,
        title: title,
        body: body,
      );
      await _record(outcome);
      return outcome;
    } on Exception catch (error) {
      return _recordFailure(error);
    } on Error catch (error) {
      // The same deliberate exception EmergencyDispatchPipeline documents:
      // catching Error is allowed in the dispatch fan-out and nowhere else,
      // because losing the grace ticker over a bug in one notification would
      // trade a small defect for a large one. It is RECORDED, never swallowed.
      return _recordFailure(error);
    }
  }

  static Future<DispatchTargetOutcome> _recordFailure(Object error) async {
    final outcome = DispatchOutcomeClassifier.classifyError(error);
    await _record(outcome);
    return outcome;
  }

  static Future<void> _record(DispatchTargetOutcome outcome) async {
    if (outcome.reachability == DispatchReachability.reached) return;
    await LocalLoggerService.instance.warningCode(
      LocalWarningCode.safetyAlertNotDelivered,
    );
  }
}
