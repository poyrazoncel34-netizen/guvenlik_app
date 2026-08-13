import 'package:flutter/foundation.dart';

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
  advancedAutomation,
}

enum FeatureAccessLevel { free, pro }

class FeatureAccessEntry {
  final PremiumFeature feature;
  final FeatureAccessLevel access;
  final String titleKey;
  final String verificationLabel;

  const FeatureAccessEntry({
    required this.feature,
    required this.access,
    required this.titleKey,
    required this.verificationLabel,
  });

  bool get isFree => access == FeatureAccessLevel.free;
  bool get isPro => access == FeatureAccessLevel.pro;
}

class FeatureAccessMatrix {
  FeatureAccessMatrix._();

  static const entries = <PremiumFeature, FeatureAccessEntry>{
    PremiumFeature.location: FeatureAccessEntry(
      feature: PremiumFeature.location,
      access: FeatureAccessLevel.free,
      titleKey: 'location',
      verificationLabel: 'Basic map/location view',
    ),
    PremiumFeature.fakeCall: FeatureAccessEntry(
      feature: PremiumFeature.fakeCall,
      access: FeatureAccessLevel.free,
      titleKey: 'fake_call',
      verificationLabel: 'Fake call immediate',
    ),
    PremiumFeature.siren: FeatureAccessEntry(
      feature: PremiumFeature.siren,
      access: FeatureAccessLevel.free,
      titleKey: 'siren',
      verificationLabel: 'Siren',
    ),
    PremiumFeature.contacts: FeatureAccessEntry(
      feature: PremiumFeature.contacts,
      access: FeatureAccessLevel.free,
      titleKey: 'contacts',
      verificationLabel: 'Emergency contact management',
    ),
    PremiumFeature.emergencyContactAdd: FeatureAccessEntry(
      feature: PremiumFeature.emergencyContactAdd,
      access: FeatureAccessLevel.free,
      titleKey: 'premium_feature_emergency_contact_add',
      verificationLabel: 'Emergency contact add',
    ),
    PremiumFeature.emergencyContactSelect: FeatureAccessEntry(
      feature: PremiumFeature.emergencyContactSelect,
      access: FeatureAccessLevel.free,
      titleKey: 'premium_feature_emergency_contact_select',
      verificationLabel: 'Emergency contact primary selection',
    ),
    // Free on purpose: test mode IS the demonstration of the panic flow. It
    // dials nothing and sends nothing, so paywalling it only forced a trust
    // product to be bought on faith. It is also the only way a user can find
    // out their setup is broken before they need it.
    PremiumFeature.testMode: FeatureAccessEntry(
      feature: PremiumFeature.testMode,
      access: FeatureAccessLevel.free,
      titleKey: 'test_mode_no_real_call',
      verificationLabel: 'Test mode rehearsal (no real call)',
    ),
    // Free on purpose: this is the user's own local record of their own
    // events, and the plan-note it carries is the only repeatable non-emergency
    // reason to open the app at all.
    PremiumFeature.timeline: FeatureAccessEntry(
      feature: PremiumFeature.timeline,
      access: FeatureAccessLevel.free,
      titleKey: 'timeline',
      verificationLabel: 'Activity timeline / safety history / plan note',
    ),
    PremiumFeature.panic: FeatureAccessEntry(
      feature: PremiumFeature.panic,
      access: FeatureAccessLevel.pro,
      titleKey: 'premium_feature_panic',
      verificationLabel: 'Panic/SOS button',
    ),
    PremiumFeature.safeWalk: FeatureAccessEntry(
      feature: PremiumFeature.safeWalk,
      access: FeatureAccessLevel.pro,
      titleKey: 'safe_walk',
      verificationLabel: 'Safe Walk',
    ),
    PremiumFeature.checkIn: FeatureAccessEntry(
      feature: PremiumFeature.checkIn,
      access: FeatureAccessLevel.pro,
      titleKey: 'check_in',
      verificationLabel: 'Check-in',
    ),
    PremiumFeature.volumeTrigger: FeatureAccessEntry(
      feature: PremiumFeature.volumeTrigger,
      access: FeatureAccessLevel.pro,
      titleKey: 'premium_feature_volume_trigger',
      verificationLabel: 'Volume trigger',
    ),
    PremiumFeature.advancedAutomation: FeatureAccessEntry(
      feature: PremiumFeature.advancedAutomation,
      access: FeatureAccessLevel.pro,
      titleKey: 'premium_feature_advanced_automation',
      verificationLabel: 'Advanced safety automation',
    ),
  };

  static const proBenefitKeys = <String>[
    'subscription_value_panic',
    'subscription_value_walk',
    'subscription_value_checkin',
    'subscription_value_volume_trigger',
    'subscription_value_automation',
  ];

  static Set<PremiumFeature> get freeFeatures => entries.values
      .where((entry) => entry.isFree)
      .map((entry) => entry.feature)
      .toSet();

  static Set<PremiumFeature> get proFeatures => entries.values
      .where((entry) => entry.isPro)
      .map((entry) => entry.feature)
      .toSet();

  /// Paid features that can place, or directly trigger, an emergency call.
  ///
  /// These are the only features covered by the unbounded offline entitlement
  /// policy (see SubscriptionAccessState.entitlementDecision): losing them
  /// because a phone had no signal defeats the product. Every other paid
  /// feature keeps the bounded offline grace so billing integrity is intact.
  static const Set<PremiumFeature> emergencyCapableFeatures = <PremiumFeature>{
    PremiumFeature.panic,
    PremiumFeature.safeWalk,
    PremiumFeature.checkIn,
    // The volume trigger exists only to fire the panic flow, so gating it more
    // strictly than panic itself would be incoherent.
    PremiumFeature.volumeTrigger,
  };

  static bool isEmergencyCapable(PremiumFeature feature) =>
      emergencyCapableFeatures.contains(feature);

  static FeatureAccessEntry entryFor(PremiumFeature feature) =>
      entries[feature] ??
      (throw ArgumentError('Unknown premium feature: $feature'));

  static bool isFreeFeature(PremiumFeature feature) => entryFor(feature).isFree;

  static bool isProFeature(PremiumFeature feature) => entryFor(feature).isPro;

  static String titleKey(PremiumFeature feature) => entryFor(feature).titleKey;

  static String debugMatrixText() {
    final lines = entries.values
        .map((entry) {
          final tier = entry.isFree ? 'FREE' : 'PRO';
          return '$tier | ${entry.feature.name} | ${entry.verificationLabel}';
        })
        .join('\n');
    return 'KoruBeni feature access matrix\n$lines';
  }

  static void debugPrintMatrix() {
    assert(() {
      debugPrint(debugMatrixText());
      return true;
    }());
  }
}
