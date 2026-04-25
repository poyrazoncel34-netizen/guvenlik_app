import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/feature_access_matrix.dart';
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

  static Future<bool> ensureAccess(
    BuildContext context,
    PremiumFeature feature,
  ) async {
    final isPro = context.read<SubscriptionProvider>().isPro;
    if (canUseFeature(feature: feature, isPro: isPro)) {
      return true;
    }

    await showPaywall(context, lockedFeature: feature);
    return false;
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
