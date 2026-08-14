/// Per-target outcome accounting for ONE emergency dispatch.
///
/// Why this file exists
/// --------------------
/// A single panic press fans out to several INDEPENDENT recipients: the call
/// request to the primary contact, the local alert notification, the safety
/// timeline row, the offline queue entry, the haptic confirmation. Before this
/// model existed, every recipient except the call collapsed into
/// `onBestEffortError -> debugPrint`, so `[reached, failed, reached]` reached
/// the user as one undifferentiated success screen. That is the exact shape of
/// failure a safety product must not have: the person believes their alert went
/// out three ways when it went out twice.
///
/// What the vocabulary deliberately does NOT contain
/// -------------------------------------------------
/// There is no `delivered`, `ringing`, `answered` or `callCompleted`. This app
/// hands an intent to Android; it never observes the far end. The strongest
/// honest statement is [DispatchTargetOutcome.handoffAccepted] -- "the platform
/// accepted the handoff" -- which is why `EmergencyCallResult.isConfirmed` is
/// hard-coded to false throughout the emergency path.
library;

import 'package:flutter/services.dart';

/// The independently observable recipients of one emergency dispatch.
///
/// A target is listed here only if its success and failure are separately
/// observable at the Dart boundary. Native-internal steps that the platform
/// reports as one atomic result (claim + fallback post) stay inside
/// [DispatchTarget.primaryCall].
enum DispatchTarget {
  /// The automatic call request to the armed primary contact.
  primaryCall,

  /// ACTION_DIAL handoff, used when the automatic request was not submitted.
  dialerHandoff,

  /// The local high-importance alert notification.
  alertNotification,

  /// The user's own safety timeline (`activity_events`).
  safetyTimeline,

  /// The offline queue entry replayed when connectivity returns.
  offlineQueue,

  /// The haptic confirmation felt by the user holding the device.
  haptic,
}

/// States an Android app can actually PROVE about one dispatch target.
enum DispatchTargetOutcome {
  /// A precondition was not met, so nothing was sent. Not a failure.
  notAttempted,

  /// The platform accepted the handoff. NOT proof of delivery or connection.
  handoffAccepted,

  /// Submitted, but the platform returned no acknowledgement (timeout, or a
  /// reconciliation that could neither confirm nor deny). Neither success nor
  /// failure -- and never rendered as either.
  handoffUnconfirmed,

  /// No component on the device can service the request (no dialer, plugin
  /// missing, activity not found).
  noCompatibleHandler,

  /// The OS refused for want of a runtime permission (CALL_PHONE,
  /// POST_NOTIFICATIONS).
  permissionDenied,

  /// The platform returned a definite refusal that is not a permission problem.
  platformRejected,

  /// The platform threw. Distinct from [platformRejected]: a rejection is an
  /// answer, an exception is a broken channel.
  platformException,

  /// The user cancelled before this target was attempted.
  cancelled,

  /// The user switched this surface off in app settings. Not a defect -- but it
  /// is definitively "did not reach", and rendering it as success would lie.
  suppressedByUserSetting,
}

/// How an outcome counts towards "did the alert reach anyone".
enum DispatchReachability {
  /// Handed off successfully.
  reached,

  /// Genuinely unknown; must never be rendered as either success or failure.
  unknown,

  /// Definitively did not reach.
  notReached,

  /// Never attempted, so it contributes to neither side.
  inapplicable,
}

extension DispatchTargetOutcomeReachability on DispatchTargetOutcome {
  DispatchReachability get reachability => switch (this) {
    DispatchTargetOutcome.handoffAccepted => DispatchReachability.reached,
    DispatchTargetOutcome.handoffUnconfirmed => DispatchReachability.unknown,
    DispatchTargetOutcome.noCompatibleHandler ||
    DispatchTargetOutcome.permissionDenied ||
    DispatchTargetOutcome.platformRejected ||
    DispatchTargetOutcome.platformException ||
    DispatchTargetOutcome.suppressedByUserSetting =>
      DispatchReachability.notReached,
    DispatchTargetOutcome.notAttempted ||
    DispatchTargetOutcome.cancelled => DispatchReachability.inapplicable,
  };

  /// Translation key for the outcome, used by the per-target result list.
  String get messageKey => switch (this) {
    DispatchTargetOutcome.notAttempted => 'dispatch_outcome_not_attempted',
    DispatchTargetOutcome.handoffAccepted => 'dispatch_outcome_handed_off',
    DispatchTargetOutcome.handoffUnconfirmed => 'dispatch_outcome_unconfirmed',
    DispatchTargetOutcome.noCompatibleHandler => 'dispatch_outcome_no_handler',
    DispatchTargetOutcome.permissionDenied =>
      'dispatch_outcome_permission_denied',
    DispatchTargetOutcome.platformRejected => 'dispatch_outcome_rejected',
    DispatchTargetOutcome.platformException => 'dispatch_outcome_exception',
    DispatchTargetOutcome.cancelled => 'dispatch_outcome_cancelled',
    DispatchTargetOutcome.suppressedByUserSetting =>
      'dispatch_outcome_suppressed',
  };
}

extension DispatchTargetLabel on DispatchTarget {
  String get labelKey => switch (this) {
    DispatchTarget.primaryCall => 'dispatch_target_primary_call',
    DispatchTarget.dialerHandoff => 'dispatch_target_dialer',
    DispatchTarget.alertNotification => 'dispatch_target_notification',
    DispatchTarget.safetyTimeline => 'dispatch_target_timeline',
    DispatchTarget.offlineQueue => 'dispatch_target_queue',
    DispatchTarget.haptic => 'dispatch_target_haptic',
  };
}

/// One target's result. Immutable; a ledger entry is never rewritten.
class DispatchTargetResult {
  const DispatchTargetResult({
    required this.target,
    required this.outcome,
    this.reasonCode,
  });

  final DispatchTarget target;
  final DispatchTargetOutcome outcome;

  /// Machine reason (platform error code, native reason string). Never carries
  /// contact data, location or PIN material -- this value reaches local logs.
  final String? reasonCode;

  DispatchReachability get reachability => outcome.reachability;

  Map<String, Object?> toMap() => <String, Object?>{
    'target': target.name,
    'outcome': outcome.name,
    'reachability': reachability.name,
    if (reasonCode != null) 'reasonCode': reasonCode,
  };

  @override
  String toString() =>
      'DispatchTargetResult(${target.name}, ${outcome.name}'
      '${reasonCode == null ? '' : ', $reasonCode'})';

  @override
  bool operator ==(Object other) =>
      other is DispatchTargetResult &&
      other.target == target &&
      other.outcome == outcome &&
      other.reasonCode == reasonCode;

  @override
  int get hashCode => Object.hash(target, outcome, reasonCode);
}

/// The shape of a completed dispatch, at the level a user can be told about.
enum DispatchOutcomeSummary {
  /// Nothing was attempted (cancelled before any handoff, or no preconditions).
  nothingAttempted,

  /// Every attempted target was handed off.
  everyTargetReached,

  /// Every attempted target definitively failed.
  noTargetReached,

  /// The case this whole file exists for: the outcomes were not the same.
  /// Includes any run containing an unconfirmed target.
  mixed,
}

/// Append-only record of every target attempted by ONE dispatch.
///
/// Not a singleton and deliberately not shared: each dispatch constructs its
/// own ledger, so two concurrent dispatches cannot interleave their entries.
class DispatchOutcomeLedger {
  DispatchOutcomeLedger({required this.dispatchId});

  /// The dispatch this ledger belongs to. Two concurrent dispatches carry two
  /// different ids, which is what makes cross-contamination detectable.
  final String dispatchId;

  final List<DispatchTargetResult> _results = <DispatchTargetResult>[];

  /// Every entry, in the order it was recorded. A repeated target is KEPT as a
  /// second entry rather than overwriting the first: silently collapsing two
  /// attempts into one is the same class of defect as collapsing two targets.
  List<DispatchTargetResult> get results =>
      List<DispatchTargetResult>.unmodifiable(_results);

  void record(DispatchTargetResult result) => _results.add(result);

  void recordOutcome(
    DispatchTarget target,
    DispatchTargetOutcome outcome, {
    String? reasonCode,
  }) => record(
    DispatchTargetResult(
      target: target,
      outcome: outcome,
      reasonCode: reasonCode,
    ),
  );

  int countWhere(DispatchReachability reachability) =>
      _results.where((r) => r.reachability == reachability).length;

  int get reachedCount => countWhere(DispatchReachability.reached);
  int get unknownCount => countWhere(DispatchReachability.unknown);
  int get notReachedCount => countWhere(DispatchReachability.notReached);
  int get attemptedCount =>
      _results.length - countWhere(DispatchReachability.inapplicable);

  /// Targets recorded more than once, in first-seen order.
  List<DispatchTarget> get duplicateTargets {
    final seen = <DispatchTarget>{};
    final duplicated = <DispatchTarget>[];
    for (final result in _results) {
      if (!seen.add(result.target) && !duplicated.contains(result.target)) {
        duplicated.add(result.target);
      }
    }
    return List<DispatchTarget>.unmodifiable(duplicated);
  }

  /// At least one target was handed off AND at least one definitively was not.
  /// This is the state that must never be rendered as plain success.
  bool get isPartial => reachedCount > 0 && notReachedCount > 0;

  /// At least one target's fate is genuinely unknown.
  bool get hasUnconfirmedTarget => unknownCount > 0;

  DispatchOutcomeSummary get summary {
    if (attemptedCount == 0) return DispatchOutcomeSummary.nothingAttempted;
    if (reachedCount == attemptedCount) {
      return DispatchOutcomeSummary.everyTargetReached;
    }
    if (notReachedCount == attemptedCount) {
      return DispatchOutcomeSummary.noTargetReached;
    }
    return DispatchOutcomeSummary.mixed;
  }

  /// Bounded projection for local logging and the KVKK export. Values are
  /// enum names and platform codes only.
  Map<String, Object?> toMap() => <String, Object?>{
    'dispatchId': dispatchId,
    'summary': summary.name,
    'isPartial': isPartial,
    'reached': reachedCount,
    'unknown': unknownCount,
    'notReached': notReachedCount,
    'attempted': attemptedCount,
    'results': _results.map((r) => r.toMap()).toList(growable: false),
  };
}

/// Maps a thrown object onto the outcome vocabulary.
///
/// The mapping is a visible table rather than a catch-all, because "something
/// went wrong" is precisely the aggregate this model replaces. Anything not
/// named here is [DispatchTargetOutcome.platformException] -- the loudest of the
/// failure states, so a new failure mode is never quietly demoted.
abstract final class DispatchOutcomeClassifier {
  static final RegExp _permissionPattern = RegExp(
    'permission',
    caseSensitive: false,
  );

  /// Platform error codes that mean "nothing on this device can service it".
  static const Set<String> noHandlerCodes = <String>{
    'no_handler',
    'ACTIVITY_NOT_FOUND',
    'activity_not_found',
    'unimplemented',
    'UNIMPLEMENTED',
  };

  /// Platform error codes that mean "refused for want of a permission".
  static const Set<String> permissionCodes = <String>{
    'permission_denied',
    'PERMISSION_DENIED',
    'missing_permission',
    'SecurityException',
  };

  static DispatchTargetOutcome classifyError(Object error) {
    if (error is MissingPluginException) {
      return DispatchTargetOutcome.noCompatibleHandler;
    }
    if (error is PlatformException) {
      final code = error.code;
      // Case-insensitive MATCH rather than a case-fold: Dart's invariant
      // casing is wrong for Turkish, and turkish_casing_test.dart guards the
      // whole of lib/ against new folds regardless of receiver.
      if (permissionCodes.contains(code) || _permissionPattern.hasMatch(code)) {
        return DispatchTargetOutcome.permissionDenied;
      }
      if (noHandlerCodes.contains(code)) {
        return DispatchTargetOutcome.noCompatibleHandler;
      }
      return DispatchTargetOutcome.platformRejected;
    }
    return DispatchTargetOutcome.platformException;
  }

  /// Reason code recorded alongside the outcome. Platform codes only -- never
  /// the message, which can contain caller-supplied text.
  static String reasonFor(Object error) {
    if (error is PlatformException) return error.code;
    if (error is MissingPluginException) return 'missingPlugin';
    return error.runtimeType.toString();
  }
}
