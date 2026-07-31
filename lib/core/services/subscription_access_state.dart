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
  const SubscriptionAccessState({required this.status, this.lastVerifiedPro});

  const SubscriptionAccessState.uninitialized()
    : status = SubscriptionAccessStatus.uninitialized,
      lastVerifiedPro = null;

  final SubscriptionAccessStatus status;
  final bool? lastVerifiedPro;

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

  bool get shouldShowPaywall =>
      status == SubscriptionAccessStatus.verifiedFree &&
      lastVerifiedPro == false;

  bool get hasVerifiedResult => lastVerifiedPro != null;

  SubscriptionAccessState markLoading() => SubscriptionAccessState(
    status: SubscriptionAccessStatus.loading,
    lastVerifiedPro: lastVerifiedPro,
  );

  SubscriptionAccessState markVerified({required bool isPro}) =>
      SubscriptionAccessState(
        status: isPro
            ? SubscriptionAccessStatus.verifiedPro
            : SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: isPro,
      );

  SubscriptionAccessState markUnavailable() => SubscriptionAccessState(
    status: SubscriptionAccessStatus.unavailable,
    lastVerifiedPro: lastVerifiedPro,
  );
}
