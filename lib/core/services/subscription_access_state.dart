import 'emergency_session_contract.dart';

enum SubscriptionAccessStatus {
  uninitialized,
  loading,
  verifiedPro,
  verifiedFree,
  unavailable,
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

  /// The authorization every layer acts on.
  ///
  /// This getter -- not a separate boolean -- is deliberately the single place
  /// the grace window is applied. The panic path checks entitlement in three
  /// independent places (`panic_button` re-reads it after the gate,
  /// `CountdownScreen` gates the native alarm on it, and the Kotlin side
  /// rejects `unknown` again). Widening only a gate's return value leaves the
  /// other two refusing, which is exactly how an earlier attempt at this fix
  /// failed. Resolving it here means no wire or native contract has to change.
  EntitlementDecision get entitlementDecision {
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

  /// New safety work requires a current trustworthy authorization.
  bool get canUsePaidSafetyFeature =>
      entitlementDecision == EntitlementDecision.authorized &&
      lastVerifiedPro == true;

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
