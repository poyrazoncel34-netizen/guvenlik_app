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

  /// How long a panic press may wait on entitlement resolution before deciding
  /// from the last known state instead.
  ///
  /// Without it the wait is unbounded: the store call has no app-level limit,
  /// and on weak signal (one bar, captive portal) it is slow rather than
  /// failing fast. An unbounded wait in front of a panic button is a delayed
  /// emergency call, which this project treats as CRITICAL.
  static const Duration entitlementResolveTimeout = Duration(
    milliseconds: 1800,
  );

  /// Bound for the purely local anchor read. Separate from the network budget
  /// above because it must NOT be skipped when the network is what is failing.
  static const Duration offlineAnchorLoadTimeout = Duration(milliseconds: 400);

  static Future<bool> ensureAccess(
    BuildContext context,
    PremiumFeature feature,
  ) async {
    if (isFreeFeature(feature)) return true;

    final provider = context.read<SubscriptionProvider>();
    // Local anchor first, on its own short budget: on a cold start with no
    // signal this is the only thing that can still authorize the press.
    try {
      await provider.ensureOfflineGraceLoaded().timeout(
        offlineAnchorLoadTimeout,
      );
    } on TimeoutException {
      // Degrades to "no anchor"; never blocks the press.
    }
    SubscriptionAccessState access;
    try {
      access = await provider.resolveAccess().timeout(
        entitlementResolveTimeout,
      );
    } on TimeoutException {
      // A slow store answer is treated as unresolved, which is exactly what the
      // grace window inside `entitlementDecision` is for.
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
    // resolved at all (first launch offline, store/RevenueCat unreachable).
    // The authorization decision stays fail-closed, but a safety control must
    // never read as "broken button" — an unexplained no-op is indistinguishable
    // from a crash to someone who is about to need it.
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
