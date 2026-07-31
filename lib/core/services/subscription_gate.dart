import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/feature_access_matrix.dart';
import 'subscription_access_state.dart';
import '../../presentation/providers/subscription_provider.dart';
import '../../screens/subscription/paywall_screen.dart';

export '../constants/feature_access_matrix.dart';

class SubscriptionGate {
  SubscriptionGate._();

  static Set<PremiumFeature> get freeFeatures =>
      FeatureAccessMatrix.freeFeatures;

  static bool isFreeFeature(PremiumFeature feature) =>
      FeatureAccessMatrix.isFreeFeature(feature);

  static bool isProFeature(PremiumFeature feature) =>
      FeatureAccessMatrix.isProFeature(feature);

  static bool canUseFeature({
    required PremiumFeature feature,
    required bool isPro,
  }) {
    return isPro || isFreeFeature(feature);
  }

  static bool canAddContact({required int currentCount, required bool isPro}) {
    return canUseFeature(
      feature: PremiumFeature.emergencyContactAdd,
      isPro: isPro,
    );
  }

  static bool canUseProFeature({required bool isPro}) => isPro;

  /// How long a panic press may wait on entitlement resolution before the
  /// decision is made from the last known state instead.
  ///
  /// Without this the wait is unbounded: RevenueCat's call has no app-level
  /// limit, and on weak signal (one bar, captive portal) it is slow rather than
  /// failing fast. An unbounded wait in front of a panic button is a delayed
  /// emergency call, which this project treats as CRITICAL.
  static const Duration entitlementResolveTimeout = Duration(
    milliseconds: 1800,
  );

  /// Authorization for a NEW safety session, including the bounded offline
  /// fallback. Pure decision, no UI -- callers that must show a rejection use
  /// [ensureAccess].
  ///
  /// Order is deliberate: a *verified* free answer denies before the grace
  /// window is ever consulted, so fail-closed still holds for the case where
  /// the store actually answered "not subscribed".
  static bool canArmSafetySession(
    SubscriptionAccessState access, {
    DateTime? now,
  }) {
    if (access.canUsePaidSafetyFeature) return true;
    if (access.shouldShowPaywall) return false;
    return access.canArmWithinOfflineGrace(now: now);
  }

  static Future<bool> ensureAccess(
    BuildContext context,
    PremiumFeature feature,
  ) async {
    if (isFreeFeature(feature)) return true;

    final provider = context.read<SubscriptionProvider>();
    // The local grace anchor is loaded outside the timeout: on a cold start with
    // no signal the network call is exactly what stalls, and the anchor is the
    // only thing left that can authorize this press.
    await provider.ensureOfflineGraceLoaded();
    SubscriptionAccessState access;
    try {
      access = await provider.resolveAccess().timeout(
        entitlementResolveTimeout,
      );
    } on TimeoutException {
      // Not an error path: a slow store answer is treated as "unresolved", which
      // is what the grace window below is for.
      access = provider.access;
    }
    if (!context.mounted) return false;
    if (access.canUsePaidSafetyFeature) return true;

    // Loading/unavailable is not evidence of a free account. Only a real
    // CustomerInfo response that verified "free" may route to the paywall.
    if (access.shouldShowPaywall) {
      await showPaywall(context, lockedFeature: feature);
      return false;
    }

    // Neither verified-Pro nor verified-free: the entitlement could not be
    // resolved at all (first launch offline, store/RevenueCat unreachable, or
    // the resolve timed out). A previously verified Pro inside the grace window
    // still arms, silently — refusing a paying user because the phone lost
    // signal fails at exactly the moment the button exists for.
    if (canArmSafetySession(access)) return true;

    // No usable evidence at all. The decision stays fail-closed, but a safety
    // control must never read as "broken button" — an unexplained no-op is
    // indistinguishable from a crash to someone who is about to need it.
    showEntitlementUnverified(context);
    return false;
  }

  /// Visible, non-silent rejection for an unresolved entitlement.
  static void showEntitlementUnverified(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('subscription_entitlement_unverified'.tr()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static Future<void> showPaywall(
    BuildContext context, {
    PremiumFeature? lockedFeature,
  }) async {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          lockedFeatureTitleKey: lockedFeature == null
              ? null
              : featureTitleKey(lockedFeature),
        ),
      ),
    );
    if (context.mounted) {
      await context.read<SubscriptionProvider>().refresh();
    }
  }

  static String featureTitleKey(PremiumFeature feature) {
    return FeatureAccessMatrix.titleKey(feature);
  }
}
