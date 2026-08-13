import 'emergency_session_contract.dart';

enum SubscriptionAccessStatus {
  uninitialized,
  loading,
  verifiedPro,
  verifiedFree,
  unavailable,
}

/// The semantically distinct situations the UI and the authorization path must
/// agree on.
///
/// This exists because a single "cannot verify right now" boolean conflated two
/// opposite worlds: a subscriber whose store call failed (protected) and a
/// person who has never subscribed and whose provider was simply never
/// initialised (NOT protected). The home screen read that boolean and told the
/// second group that "emergency features keep working" -- a safety claim that
/// was false for exactly the users who most needed it to be true
/// (INDEPENDENT_REVIEW_ROUND_2.md R2-01).
///
/// Absence of an answer is not an answer. [uninitialized] and [resolving] are
/// therefore never merged into [entitledUnverifiable]: the latter asserts a
/// POSITIVE PRIOR CONFIRMATION that is merely stale, and only that state may
/// carry continuity messaging.
enum SubscriptionReadiness {
  /// Nothing has been asked of the store yet in this process, and no prior
  /// entitlement anchor was found. Authorization: none.
  uninitialized,

  /// A resolution attempt is in flight and no anchor authorizes meanwhile.
  resolving,

  /// The store positively answered: entitlement active. Authorization: full.
  entitledConfirmed,

  /// The store cannot be reached, but a genuine prior confirmation (flag AND
  /// corroborating timestamp) anchors the emergency authorization.
  /// This -- and only this -- is the state the offline-continuity notice
  /// describes truthfully.
  entitledUnverifiable,

  /// The store positively answered: not a subscriber. Authorization: none.
  notEntitledConfirmed,

  /// The store cannot be reached and there is no prior confirmation to fall
  /// back on. Indistinguishable from "never subscribed" as far as the app can
  /// prove, so it must never be described as protected.
  unknownNoEntitlement,
}

/// What, if anything, the readiness surface may truthfully tell the user about
/// entitlement verification.
///
/// Deliberately computed here rather than in the widget: the notice is a
/// statement about authorization, so it must be derived from the same state the
/// authorization is derived from, not from a loosely related boolean passed
/// down the widget tree.
enum SubscriptionNotice {
  /// Say nothing. Either everything is confirmed, or nothing is confirmed and
  /// the locked controls already say so.
  none,

  /// Entitled, store unreachable, the non-safety grace window is comfortable.
  verificationPending,

  /// Entitled, store unreachable, the non-safety grace window is about to
  /// lapse. This is the advance warning: it is shown while the user can still
  /// act on it.
  verificationPendingGraceExpiring,

  /// Entitled for safety, but the non-safety grace window has lapsed: paid
  /// convenience features are paused while the emergency path continues.
  nonEmergencyGraceLapsed,
}

/// Separates commercial entitlement truth from transport/loading failures.
///
/// A missing RevenueCat response is not proof that the user is free or Pro.
/// A transient failure may preserve a previously verified Pro fact solely for
/// an already-armed in-process session lease; it cannot authorize a new arm.
class SubscriptionAccessState {
  const SubscriptionAccessState({
    required this.status,
    this.lastVerifiedPro,
    this.lastVerifiedProAt,
  });

  const SubscriptionAccessState.uninitialized()
    : status = SubscriptionAccessStatus.uninitialized,
      lastVerifiedPro = null,
      lastVerifiedProAt = null;

  /// How long a previously verified Pro entitlement keeps authorizing while the
  /// store cannot be reached at all.
  ///
  /// A safety control that refuses because the phone has no signal fails at
  /// exactly the moment it is needed: signal loss correlates with the situations
  /// this app exists for -- basement, car park, rural road. This window bounds
  /// that fallback rather than removing it, and never applies to a *verified*
  /// free answer.
  static const Duration offlineGracePeriod = Duration(days: 7);

  final SubscriptionAccessStatus status;
  final bool? lastVerifiedPro;

  /// When the last verified-Pro answer was observed. Persisted, because an
  /// in-process-only fact is gone after a restart -- the cold-start-with-no-
  /// signal case the window exists for.
  final DateTime? lastVerifiedProAt;

  /// Strictly what the store answered. Never widened by the grace window.
  /// Use this for anything that must reflect store truth rather than
  /// authorization (and to avoid recursing through [entitlementDecision]).
  EntitlementDecision get verifiedEntitlementDecision => switch (status) {
    SubscriptionAccessStatus.verifiedPro => EntitlementDecision.authorized,
    SubscriptionAccessStatus.verifiedFree => EntitlementDecision.denied,
    _ => EntitlementDecision.unknown,
  };

  /// True only when the store POSITIVELY answered that the user is not a
  /// subscriber. An unreachable store is never this.
  bool get isConfirmedInactive =>
      status == SubscriptionAccessStatus.verifiedFree;

  /// True when entitlement cannot be resolved right now (offline, store down,
  /// cold start with no signal) as opposed to being confirmed either way.
  bool get isTemporarilyUnverifiable =>
      verifiedEntitlementDecision == EntitlementDecision.unknown;

  /// The authorization the EMERGENCY path acts on (panic/SOS, check-in,
  /// safe-walk).
  ///
  /// PRODUCT POLICY (owner decision, 2026-08-13, closing INDEPENDENT_REVIEW.md
  /// IR-04): failure to refresh entitlement is NOT equivalent to confirmed
  /// expiry. A subscriber whose last CONFIRMED answer was active keeps the
  /// emergency action while the store is merely unreachable, with no time
  /// limit. Losing SOS because a phone had no signal for a week fails at
  /// exactly the moment this product exists for -- and signal loss correlates
  /// with the situations it exists for.
  ///
  /// This getter -- not a separate boolean -- is deliberately the single place
  /// the policy is applied. The panic path checks entitlement in three
  /// independent places (`panic_button` re-reads it after the gate,
  /// `CountdownScreen` gates the native alarm on it, and the Kotlin side
  /// rejects `unknown` again). Widening only a gate's return value leaves the
  /// other two refusing, which is exactly how an earlier attempt failed.
  ///
  /// A positively confirmed inactive subscription still denies: the store said
  /// no, which is an answer, not an absence of one.
  EntitlementDecision get entitlementDecision {
    final verified = verifiedEntitlementDecision;
    if (verified != EntitlementDecision.unknown) return verified;
    // UNKNOWN is never silently converted to EXPIRED -- but the policy widens
    // only a GENUINE prior confirmation. Both the flag and its corroborating
    // timestamp must be present: a lone boolean written into local storage
    // must not be able to forge an entitlement that never happened
    // (see subscription_offline_grace_test.dart).
    final confirmedBefore =
        lastVerifiedPro == true && lastVerifiedProAt != null;
    return confirmedBefore
        ? EntitlementDecision.authorized
        : EntitlementDecision.unknown;
  }

  /// The authorization NON-emergency paid features act on (timeline, advanced
  /// automation, and anything else that is convenience rather than safety).
  ///
  /// Billing integrity still applies here: an unverifiable entitlement only
  /// carries these features for [offlineGracePeriod], because nobody's safety
  /// depends on them.
  EntitlementDecision get nonEmergencyEntitlementDecision {
    final verified = verifiedEntitlementDecision;
    if (verified != EntitlementDecision.unknown) return verified;
    return canArmWithinOfflineGrace()
        ? EntitlementDecision.authorized
        : EntitlementDecision.unknown;
  }

  /// Bounded fallback for an entitlement that could not be resolved at all.
  /// Reads [verifiedEntitlementDecision], never [entitlementDecision].
  bool canArmWithinOfflineGrace({DateTime? now}) {
    if (lastVerifiedPro != true) return false;
    if (verifiedEntitlementDecision != EntitlementDecision.unknown) return false;
    final verifiedAt = lastVerifiedProAt;
    if (verifiedAt == null) return false;
    final moment = now ?? DateTime.now();
    // A future anchor means a rolled-back clock or a tampered store.
    if (verifiedAt.isAfter(moment)) return false;
    return moment.difference(verifiedAt) <= offlineGracePeriod;
  }

  /// How much of the offline grace window remains, or null when the window
  /// does not apply (no verified-Pro anchor, or the store answered).
  ///
  /// Exists so the product can warn BEFORE the cliff. Previously
  /// [offlineGracePeriod] was referenced only inside this file, which meant a
  /// paying subscriber discovered their panic button was disabled at the moment
  /// they pressed it -- the worst possible moment. See PRODUCTION_AUDIT.md
  /// MP-22-001 / MP-54-029 and INDEPENDENT_REVIEW.md IR-04.
  Duration? remainingOfflineGrace({DateTime? now}) {
    if (lastVerifiedPro != true) return null;
    final verifiedAt = lastVerifiedProAt;
    if (verifiedAt == null) return null;
    final moment = now ?? DateTime.now();
    // A future anchor is a rolled-back clock or a tampered store: report it as
    // fully expired rather than as an unbounded grant.
    if (verifiedAt.isAfter(moment)) return Duration.zero;
    final elapsed = moment.difference(verifiedAt);
    if (elapsed >= offlineGracePeriod) return Duration.zero;
    return offlineGracePeriod - elapsed;
  }

  /// [remainingOfflineGrace] rounded UP to whole hours, for user-facing copy.
  /// Rounding up so "1 hour left" is never displayed as "0".
  int? remainingOfflineGraceHours({DateTime? now}) {
    final remaining = remainingOfflineGrace(now: now);
    if (remaining == null) return null;
    return (remaining.inMinutes / 60).ceil();
  }

  /// True when the store is unreachable AND the grace window is close enough to
  /// expiry that the user should be told while they can still act on it.
  bool isOfflineGraceExpiring({
    Duration threshold = const Duration(hours: 48),
    DateTime? now,
  }) {
    if (verifiedEntitlementDecision != EntitlementDecision.unknown) return false;
    final remaining = remainingOfflineGrace(now: now);
    if (remaining == null) return false;
    return remaining > Duration.zero && remaining <= threshold;
  }

  /// True when a previously verified Pro user has passed the non-emergency
  /// grace window purely because the store could not be reached.
  ///
  /// NOTE: since the IR-04 policy change this no longer means the panic button
  /// is disabled -- the emergency path is unbounded. It means non-safety paid
  /// features have lapsed and verification is overdue.
  bool hasLostAccessToOfflineGraceExpiry({DateTime? now}) {
    if (lastVerifiedPro != true) return false;
    if (verifiedEntitlementDecision != EntitlementDecision.unknown) return false;
    final remaining = remainingOfflineGrace(now: now);
    return remaining != null && remaining <= Duration.zero;
  }

  /// Authorization for SAFETY work (the emergency path). Unbounded while the
  /// entitlement is merely unverifiable -- see [entitlementDecision].
  bool get canUsePaidSafetyFeature =>
      entitlementDecision == EntitlementDecision.authorized &&
      lastVerifiedPro == true;

  /// Authorization for non-safety paid features. Bounded by
  /// [offlineGracePeriod] so billing integrity is preserved where no one's
  /// safety is at stake.
  bool get canUseNonEmergencyPaidFeature =>
      nonEmergencyEntitlementDecision == EntitlementDecision.authorized &&
      lastVerifiedPro == true;

  /// The single semantic classification every surface must agree on.
  ///
  /// INVARIANT (asserted in subscription_readiness_state_test.dart):
  ///   canUsePaidSafetyFeature == (readiness == entitledConfirmed ||
  ///                               readiness == entitledUnverifiable)
  ///
  /// Read that as: the UI can never describe a state as protected unless the
  /// authorization path agrees, because both are computed from this one place.
  SubscriptionReadiness get readiness {
    switch (status) {
      case SubscriptionAccessStatus.verifiedPro:
        return SubscriptionReadiness.entitledConfirmed;
      case SubscriptionAccessStatus.verifiedFree:
        return SubscriptionReadiness.notEntitledConfirmed;
      case SubscriptionAccessStatus.uninitialized:
      case SubscriptionAccessStatus.loading:
      case SubscriptionAccessStatus.unavailable:
        // A genuine prior confirmation outranks the transport state: this is
        // the subscriber whose store call failed, not someone who never
        // subscribed.
        if (canUsePaidSafetyFeature) {
          return SubscriptionReadiness.entitledUnverifiable;
        }
        if (status == SubscriptionAccessStatus.uninitialized) {
          return SubscriptionReadiness.uninitialized;
        }
        if (status == SubscriptionAccessStatus.loading) {
          return SubscriptionReadiness.resolving;
        }
        return SubscriptionReadiness.unknownNoEntitlement;
    }
  }

  /// What the readiness surface may truthfully say about verification.
  ///
  /// Only [SubscriptionReadiness.entitledUnverifiable] produces a notice. Every
  /// other state either has an answer (nothing to warn about) or has no
  /// entitlement to keep alive, and telling that second group their emergency
  /// features "keep working" is the R2-01 defect.
  ///
  /// Within the entitled-unverifiable state the notice escalates with the
  /// REMAINING non-safety grace, which is what [isOfflineGraceExpiring] and
  /// [hasLostAccessToOfflineGraceExpiry] were built for. Before this they were
  /// never called from production code and the shipped notice carried no notion
  /// of "remaining" at all (R2-05).
  SubscriptionNotice noticeFor({
    Duration threshold = const Duration(hours: 48),
    DateTime? now,
  }) {
    if (readiness != SubscriptionReadiness.entitledUnverifiable) {
      return SubscriptionNotice.none;
    }
    if (hasLostAccessToOfflineGraceExpiry(now: now)) {
      return SubscriptionNotice.nonEmergencyGraceLapsed;
    }
    if (isOfflineGraceExpiring(threshold: threshold, now: now)) {
      return SubscriptionNotice.verificationPendingGraceExpiring;
    }
    return SubscriptionNotice.verificationPending;
  }

  /// Historical in-process evidence may keep an already-armed session alive.
  /// Callers must never use this getter to arm a new session.
  bool get canContinueAlreadyArmedSession => lastVerifiedPro == true;

  bool get shouldShowPaywall =>
      status == SubscriptionAccessStatus.verifiedFree &&
      lastVerifiedPro == false;

  bool get hasVerifiedResult => lastVerifiedPro != null;

  SubscriptionAccessState markLoading() => SubscriptionAccessState(
    status: SubscriptionAccessStatus.loading,
    lastVerifiedPro: lastVerifiedPro,
    lastVerifiedProAt: lastVerifiedProAt,
  );

  /// A verified answer is authoritative both ways: Pro stamps a fresh anchor,
  /// free clears it so a lapsed subscriber cannot keep arming offline.
  SubscriptionAccessState markVerified({required bool isPro, DateTime? at}) =>
      SubscriptionAccessState(
        status: isPro
            ? SubscriptionAccessStatus.verifiedPro
            : SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: isPro,
        lastVerifiedProAt: isPro ? (at ?? DateTime.now()) : null,
      );

  SubscriptionAccessState markUnavailable() => SubscriptionAccessState(
    status: SubscriptionAccessStatus.unavailable,
    lastVerifiedPro: lastVerifiedPro,
    lastVerifiedProAt: lastVerifiedProAt,
  );

  /// Restores the persisted anchor after a cold start.
  ///
  /// [corroborated] must come from the independently written prior-Pro hint.
  /// A timestamp ALONE never manufactures `lastVerifiedPro`: otherwise writing
  /// one integer into local storage would be enough to claim a past verified
  /// answer that never happened. Two agreeing keys is not tamper-proof -- an
  /// offline app with no backend cannot be -- but it stops the single-value
  /// forgery, and the window still expires on its own.
  SubscriptionAccessState withRestoredProAnchor(
    DateTime? at, {
    required bool corroborated,
  }) {
    // Already resolved in-process, either way: the persisted anchor is stale by
    // definition and must not be patched back in field by field. Restoring only
    // `lastVerifiedProAt` after a verified-free answer (possible when a slow
    // anchor read lands after the answer) would leave the state internally
    // inconsistent -- `lastVerifiedPro == false` alongside a live anchor --
    // which today is harmless only because two downstream guards happen to
    // catch it. Enforce the invariant here instead of relying on that.
    if (lastVerifiedPro != null) return this;
    if (at == null || !corroborated) return this;
    return SubscriptionAccessState(
      status: status,
      lastVerifiedPro: true,
      lastVerifiedProAt: at,
    );
  }
}
