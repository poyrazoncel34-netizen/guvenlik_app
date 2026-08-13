import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/feature_access_matrix.dart';
import '../navigation/app_navigator.dart';
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

  /// The ONE authorization rule. Every surface -- the gate below, the home
  /// quick-action lock badges, the panic button's locked state, the quick-access
  /// trigger host -- must ask this function rather than reimplementing the
  /// policy or reading a nearby boolean.
  ///
  /// Emergency-capable features follow the unbounded offline policy; every other
  /// paid feature keeps the bounded grace (IR-04 product decision). Splitting
  /// that decision across call sites is what let the UI report a feature as
  /// available while the gate refused it (INDEPENDENT_REVIEW_ROUND_2.md R2-04).
  static bool isAuthorized(
    SubscriptionAccessState access,
    PremiumFeature feature,
  ) {
    if (isFreeFeature(feature)) return true;
    return FeatureAccessMatrix.isEmergencyCapable(feature)
        ? access.canUsePaidSafetyFeature
        : access.canUseNonEmergencyPaidFeature;
  }

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
    if (isAuthorized(access, feature)) return true;

    await reportRejection(context, access, feature);
    return false;
  }

  /// The ONE rejection surface for a refused paid action.
  ///
  /// Both [ensureAccess] (panic button, contacts, settings) and
  /// `EmergencyTriggerHost` (home-screen widget, Quick Settings tile, volume
  /// keys) route here. The quick-access entries used to reject with a bare
  /// `return`, so a user in that state saw the app open and nothing happen --
  /// indistinguishable from a crash, on the one control that exists for the
  /// moment they cannot afford ambiguity (INDEPENDENT_REVIEW_ROUND_2.md R2-03).
  ///
  /// Loading/unavailable is not evidence of a free account. Only a real
  /// CustomerInfo response that verified "free" may route to the paywall;
  /// everything else gets the explain-and-retry message.
  static Future<void> reportRejection(
    BuildContext context,
    SubscriptionAccessState access,
    PremiumFeature feature,
  ) async {
    if (access.shouldShowPaywall) {
      await showPaywall(context, lockedFeature: feature);
      return;
    }
    showEntitlementUnverified(context);
  }

  /// Visible, non-silent rejection for an unresolved entitlement.
  ///
  /// Falls back to the app-level messenger when the calling context has none of
  /// its own: `EmergencyTriggerHost` is mounted ABOVE `MaterialApp`, where
  /// `ScaffoldMessenger.maybeOf` can only ever return null.
  ///
  /// The message is a plain `Text`, so TalkBack announces the SnackBar as a
  /// live region without any extra wiring; the 5-second duration is long enough
  /// to be read aloud.
  static void showEntitlementUnverified(BuildContext context) {
    final messenger =
        ScaffoldMessenger.maybeOf(context) ??
        rootScaffoldMessengerKey.currentState;
    // One message at a time: rapid repeat presses must not queue a stack of
    // identical SnackBars that outlive the situation.
    messenger?.removeCurrentSnackBar();
    messenger?.showSnackBar(
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
