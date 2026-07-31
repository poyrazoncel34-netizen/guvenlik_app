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

  /// How long a *previously verified* Pro entitlement may still authorize a new
  /// safety session while the entitlement cannot be resolved at all.
  ///
  /// A safety control that refuses because the phone has no signal fails at
  /// exactly the moment it is needed: signal loss correlates with the situations
  /// this app exists for (basement, car park, rural). This window bounds that
  /// fallback instead of removing it. It never applies to a *verified* free
  /// answer -- that stays fail-closed.
  static const Duration offlineGracePeriod = Duration(days: 7);

  final SubscriptionAccessStatus status;
  final bool? lastVerifiedPro;

  /// When the last Trusted-Entitlements verified-Pro answer was observed.
  /// Persisted, because an in-process-only fact is gone after a restart -- the
  /// exact case (cold start with no network) the grace window exists for.
  final DateTime? lastVerifiedProAt;

  EntitlementDecision get entitlementDecision => switch (status) {
    SubscriptionAccessStatus.verifiedPro => EntitlementDecision.authorized,
    SubscriptionAccessStatus.verifiedFree => EntitlementDecision.denied,
    _ => EntitlementDecision.unknown,
  };

  /// New safety work requires a current trustworthy authorization.
  bool get canUsePaidSafetyFeature =>
      entitlementDecision == EntitlementDecision.authorized &&
      lastVerifiedPro == true;

  /// Historical in-process evidence may keep an already-armed session alive.
  /// Callers must never use this getter to arm a new session.
  bool get canContinueAlreadyArmedSession => lastVerifiedPro == true;

  /// Bounded fallback for a *unresolved* entitlement: the last verified answer
  /// was Pro and it is still inside [offlineGracePeriod].
  ///
  /// Deliberately separate from [canUsePaidSafetyFeature] so that every other
  /// call site keeps the strict rule unless it opts in. A timestamp in the
  /// future means a rolled-back clock or a tampered store and is rejected.
  bool canArmWithinOfflineGrace({DateTime? now}) {
    if (lastVerifiedPro != true) return false;
    if (entitlementDecision != EntitlementDecision.unknown) return false;
    final verifiedAt = lastVerifiedProAt;
    if (verifiedAt == null) return false;
    final moment = now ?? DateTime.now();
    if (verifiedAt.isAfter(moment)) return false;
    return moment.difference(verifiedAt) <= offlineGracePeriod;
  }

  bool get shouldShowPaywall =>
      status == SubscriptionAccessStatus.verifiedFree &&
      lastVerifiedPro == false;

  bool get hasVerifiedResult => lastVerifiedPro != null;

  SubscriptionAccessState markLoading() => SubscriptionAccessState(
    status: SubscriptionAccessStatus.loading,
    lastVerifiedPro: lastVerifiedPro,
    lastVerifiedProAt: lastVerifiedProAt,
  );

  /// A verified answer is authoritative in both directions: Pro stamps a fresh
  /// grace anchor, free clears it so a lapsed subscriber cannot keep arming.
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

  /// Restores the persisted grace anchor read back at startup. Never upgrades
  /// the resolved [status]; it only supplies the timestamp the in-process state
  /// cannot know after a cold start.
  SubscriptionAccessState withRestoredProAnchor(DateTime? at) =>
      SubscriptionAccessState(
        status: status,
        lastVerifiedPro: lastVerifiedPro ?? (at == null ? null : true),
        lastVerifiedProAt: lastVerifiedProAt ?? at,
      );
}
