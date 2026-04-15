import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/subscription_provider.dart';
import '../../screens/subscription/paywall_screen.dart';

enum PremiumFeature {
  location,
  fakeCall,
  panic,
  contacts,
  siren,
  safeWalk,
  timeline,
  checkIn,
  emergencyContactAdd,
  emergencyContactSelect,
  volumeTrigger,
  testMode,
  other,
}

class SubscriptionGate {
  SubscriptionGate._();

  static const Set<PremiumFeature> freeFeatures = {
    PremiumFeature.location,
    PremiumFeature.fakeCall,
    PremiumFeature.siren,
    PremiumFeature.contacts,
  };

  static bool isFreeFeature(PremiumFeature feature) =>
      freeFeatures.contains(feature);

  static bool isProFeature(PremiumFeature feature) => !isFreeFeature(feature);

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
    switch (feature) {
      case PremiumFeature.location:
        return 'location';
      case PremiumFeature.fakeCall:
        return 'fake_call';
      case PremiumFeature.panic:
        return 'premium_feature_panic';
      case PremiumFeature.contacts:
        return 'contacts';
      case PremiumFeature.siren:
        return 'siren';
      case PremiumFeature.safeWalk:
        return 'safe_walk';
      case PremiumFeature.timeline:
        return 'timeline';
      case PremiumFeature.checkIn:
        return 'check_in';
      case PremiumFeature.emergencyContactAdd:
        return 'premium_feature_emergency_contact_add';
      case PremiumFeature.emergencyContactSelect:
        return 'premium_feature_emergency_contact_select';
      case PremiumFeature.volumeTrigger:
        return 'premium_feature_volume_trigger';
      case PremiumFeature.testMode:
        return 'test_mode_no_real_call';
      case PremiumFeature.other:
        return 'subscription_section_title';
    }
  }
}
