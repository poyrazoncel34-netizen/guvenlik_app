/// What the user is told after ONE emergency dispatch, derived from the call
/// result AND the per-target ledger (MP-01-027).
///
/// Why this file exists
/// --------------------
/// `DispatchOutcomeLedger` made every target's fate separately observable, and
/// `EmergencyCallScreen` renders it. But the panic path never reached that
/// screen when the phone handoff failed: it branched on `callResult.isFailed`
/// alone, showed "Hicbir islem tamamlanmadi" / "No action completed", and
/// returned -- while its own ledger recorded four bookkeeping targets handed
/// off. A failed phone handoff is not a failed dispatch, and the absolute claim
/// was false in exactly the shape MP-01-027 exists to remove, inverted:
/// successful handoffs collapsing into "nothing happened".
///
/// The invariant, stated once and enforced by construction
/// ------------------------------------------------------
/// **User-facing emergency outcome copy must agree with the ledger.** An
/// absolute "nothing completed" claim is permitted ONLY when no target was
/// reached AND no target's fate is unknown. [EmergencyFailureCopy] cannot be
/// built any other way -- it has no public constructor, so a caller cannot pair
/// total-failure copy with a ledger that contradicts it.
///
/// Why `unknownCount` is part of the guard (RER-05)
/// -----------------------------------------------
/// The guard used to read `reachedCount == 0` alone, and a test asserted that
/// an unknown-only ledger DOES support the absolute claim, reasoning that
/// "unknown is neither reached nor a licence to deny it happened". That
/// reasoning is right about the ledger and wrong about a headline. With four
/// targets returning [DispatchTargetOutcome.handoffUnconfirmed] the user was
/// shown "Hicbir islem tamamlanmadi" over four targets that may well have
/// succeeded -- while the rows underneath correctly read "belirsiz". A headline
/// that contradicts its own list is the exact defect MP-01-027 exists to
/// remove, and it also contradicted `dispatch_outcome.dart`, which states that
/// an unconfirmed handoff is "Neither success nor failure -- and never rendered
/// as either".
///
/// So there are THREE claims, not two, and each is true of a different ledger:
///
/// | reached | unknown | claim                                    |
/// |---------|---------|------------------------------------------|
/// | 0       | 0       | absolute: nothing completed              |
/// | 0       | > 0     | unconfirmed: nothing is KNOWN to have    |
/// | > 0     | any     | partial: some steps did complete         |
///
/// The middle row is why a third copy pair exists. Reusing the partial copy
/// there would have said "bazi adimlar tamamlandi" ("some steps completed")
/// over a ledger where nothing is known to have completed -- trading a false
/// negative claim for a false positive one.
///
/// Why a policy rather than a branch in each screen
/// -----------------------------------------------
/// The claim was already computed twice: `countdown_screen.dart` decided it
/// from the call result, `emergency_call_screen.dart` from the ledger. Two
/// copies of one decision is how they came to disagree. Both entry points now
/// ask this file, so the panic path and the Check-In escalation cannot drift
/// apart again without changing a shared rule.
library;

import 'call_service.dart';
import 'dispatch_outcome.dart';

/// Why the emergency path fell back to the blocking fail-safe surface.
///
/// Named rather than boolean because the four reasons carry different amounts
/// of knowledge about what was attempted, and that is precisely what decides
/// which claim is honest.
enum EmergencyFailureReason {
  /// Native arming was rejected before the countdown started. No target was
  /// ever attempted, so there is no ledger and nothing completed -- true.
  armRejected,

  /// The dispatch threw before returning. The critical operation is awaited
  /// BEFORE any bookkeeping step runs (`EmergencyDispatchPipeline.execute`),
  /// so a throw means zero targets were attempted.
  dispatchThrew,

  /// The call path definitively failed: no automatic request, no dialer. The
  /// bookkeeping targets still ran, so the ledger decides the claim.
  callFailed,

  /// The call was handed off but the result screen could not be shown. The
  /// ledger holds reached targets; "nothing completed" would be false here too.
  resultScreenUnavailable,
}

/// Which surface the user gets after a dispatch.
enum EmergencyResultSurface {
  /// Nothing to show -- the dispatch was cancelled before any target.
  none,

  /// The full result screen, which renders the per-target ledger itself.
  resultScreen,

  /// The blocking fail-safe dialog carrying the manual-call affordance.
  blockingFailure,
}

/// The copy one failure surface is allowed to use, plus the ledger it must
/// render beside it.
///
/// Constructed only by [EmergencyResultPolicy]. That is the enforcement: there
/// is no way to hand the dialog absolute copy together with a ledger that
/// records a reached target.
class EmergencyFailureCopy {
  const EmergencyFailureCopy._({
    required this.titleKey,
    required this.bodyKey,
    required this.claimsNothingCompleted,
    required this.ledger,
  });

  /// Translation key for the heading.
  final String titleKey;

  /// Translation key for the body sentence.
  final String bodyKey;

  /// True when the copy asserts that NO action completed. Only ever true when
  /// [ledger] is null (nothing was attempted), or records neither a reached
  /// target nor an unknown one -- an unknown target makes the absolute claim
  /// unprovable, not merely impolite.
  final bool claimsNothingCompleted;

  /// The per-target ledger to render beside the copy, so reached and
  /// not-reached targets stay distinguishable on the failure surface too.
  final DispatchOutcomeLedger? ledger;

  /// How many targets the copy is allowed to say were reached.
  int get reachedCount => ledger?.reachedCount ?? 0;
}

/// One dispatch's user-facing outcome, decided from the call result AND the
/// ledger rather than from the call result alone.
class EmergencyResultDecision {
  const EmergencyResultDecision._({required this.surface, this.failureCopy});

  final EmergencyResultSurface surface;

  /// Present exactly when [surface] is [EmergencyResultSurface.blockingFailure].
  final EmergencyFailureCopy? failureCopy;
}

abstract final class EmergencyResultPolicy {
  /// Absolute claim: nothing at all completed.
  static const String totalFailureTitleKey = 'emergency_total_failure_title';
  static const String totalFailureBodyKey = 'emergency_total_failure_body';

  /// Qualified claim: the call did not go out, but other targets did.
  static const String partialFailureTitleKey =
      'emergency_partial_failure_title';
  static const String partialFailureBodyKey = 'emergency_partial_failure_body';

  /// Honest claim for a ledger that reached nothing but does not KNOW that it
  /// failed either. Neither "nothing completed" nor "some steps completed" is
  /// true of this ledger; both would be a guess presented as a fact.
  static const String unconfirmedFailureTitleKey =
      'emergency_unconfirmed_failure_title';
  static const String unconfirmedFailureBodyKey =
      'emergency_unconfirmed_failure_body';

  /// The invariant in one expression: an absolute "nothing completed" claim is
  /// supported only by a ledger that reached nothing AND left nothing unknown
  /// (or by no ledger at all, which means no target was attempted).
  ///
  /// Both counts are required. `reachedCount == 0` alone permits the absolute
  /// claim over a ledger of pure unknowns, which is a statement the app cannot
  /// support -- see the table in this library's header comment.
  static bool supportsTotalFailureClaim(DispatchOutcomeLedger? ledger) =>
      ledger == null || (ledger.reachedCount == 0 && ledger.unknownCount == 0);

  /// The copy for a blocking failure surface.
  ///
  /// [bodyKeyOverride] lets the arm-rejection path keep its specific reason
  /// sentence. It is honoured ONLY while the total-failure claim holds: an
  /// override cannot be used to reintroduce an absolute statement over a ledger
  /// that reached targets.
  static EmergencyFailureCopy failureCopy({
    required EmergencyFailureReason reason,
    DispatchOutcomeLedger? ledger,
    String? bodyKeyOverride,
  }) {
    // armRejected and dispatchThrew both mean "no target was attempted", so a
    // ledger handed in for them is not evidence of anything reaching anyone.
    final effectiveLedger = switch (reason) {
      EmergencyFailureReason.armRejected ||
      EmergencyFailureReason.dispatchThrew => null,
      EmergencyFailureReason.callFailed ||
      EmergencyFailureReason.resultScreenUnavailable => ledger,
    };

    if (!supportsTotalFailureClaim(effectiveLedger)) {
      // Nothing reached, but something is unknown: say exactly that. Saying
      // "some steps completed" here would be as false as saying "none did".
      final bool nothingKnownToHaveCompleted =
          effectiveLedger != null && effectiveLedger.reachedCount == 0;
      return EmergencyFailureCopy._(
        titleKey: nothingKnownToHaveCompleted
            ? unconfirmedFailureTitleKey
            : partialFailureTitleKey,
        bodyKey: nothingKnownToHaveCompleted
            ? unconfirmedFailureBodyKey
            : partialFailureBodyKey,
        claimsNothingCompleted: false,
        ledger: effectiveLedger,
      );
    }
    return EmergencyFailureCopy._(
      titleKey: totalFailureTitleKey,
      bodyKey: bodyKeyOverride ?? totalFailureBodyKey,
      claimsNothingCompleted: true,
      ledger: effectiveLedger,
    );
  }

  /// The surface for a completed dispatch.
  ///
  /// A null [callResult] is a dispatch the user cancelled: neither a success
  /// screen nor a failure dialog, because nothing was claimed.
  static EmergencyResultDecision decide({
    required EmergencyCallResult? callResult,
    DispatchOutcomeLedger? ledger,
  }) {
    if (callResult == null) {
      return const EmergencyResultDecision._(
        surface: EmergencyResultSurface.none,
      );
    }
    if (callResult.isFailed) {
      return EmergencyResultDecision._(
        surface: EmergencyResultSurface.blockingFailure,
        failureCopy: failureCopy(
          reason: EmergencyFailureReason.callFailed,
          ledger: ledger,
        ),
      );
    }
    // Handed off (automatic request or dialer): the result screen renders the
    // per-target list itself, so the ledger is carried, not summarised here.
    return const EmergencyResultDecision._(
      surface: EmergencyResultSurface.resultScreen,
    );
  }
}
