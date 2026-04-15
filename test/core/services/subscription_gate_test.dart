import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/subscription_gate.dart';

void main() {
  group('SubscriptionGate policy', () {
    test('location, fakeCall, siren and contacts are free', () {
      expect(
        SubscriptionGate.freeFeatures,
        equals({
          PremiumFeature.location,
          PremiumFeature.fakeCall,
          PremiumFeature.siren,
          PremiumFeature.contacts,
        }),
      );

      for (final feature in PremiumFeature.values) {
        expect(
          SubscriptionGate.canUseFeature(feature: feature, isPro: false),
          SubscriptionGate.freeFeatures.contains(feature),
          reason: '$feature free/pro policy drifted.',
        );
      }
    });

    test('all non-free features are Pro', () {
      final proFeatures = PremiumFeature.values.where(
        (feature) => !SubscriptionGate.freeFeatures.contains(feature),
      );

      expect(
        proFeatures,
        containsAll([
          PremiumFeature.panic,
          PremiumFeature.safeWalk,
          PremiumFeature.timeline,
          PremiumFeature.checkIn,
          PremiumFeature.emergencyContactAdd,
          PremiumFeature.emergencyContactSelect,
          PremiumFeature.volumeTrigger,
          PremiumFeature.testMode,
          PremiumFeature.other,
        ]),
      );

      // siren and contacts are now free — must NOT appear in pro features
      expect(proFeatures, isNot(contains(PremiumFeature.siren)));
      expect(proFeatures, isNot(contains(PremiumFeature.contacts)));

      for (final feature in proFeatures) {
        expect(SubscriptionGate.isProFeature(feature), isTrue);
      }
    });

    test('pro user can use every feature', () {
      for (final feature in PremiumFeature.values) {
        expect(
          SubscriptionGate.canUseFeature(feature: feature, isPro: true),
          isTrue,
        );
      }
    });
  });

  group('SubscriptionGate.canAddContact', () {
    test('free user cannot add emergency contacts', () {
      expect(
        SubscriptionGate.canAddContact(currentCount: 0, isPro: false),
        isFalse,
      );
    });

    test('free user with existing contacts cannot add more', () {
      expect(
        SubscriptionGate.canAddContact(currentCount: 1, isPro: false),
        isFalse,
      );
    });

    test('pro user can add emergency contacts', () {
      expect(
        SubscriptionGate.canAddContact(currentCount: 1, isPro: true),
        isTrue,
      );
    });
  });

  group('SubscriptionGate.canUseProFeature', () {
    test('free user cannot use pro features', () {
      expect(SubscriptionGate.canUseProFeature(isPro: false), isFalse);
    });

    test('pro user can use pro features', () {
      expect(SubscriptionGate.canUseProFeature(isPro: true), isTrue);
    });
  });
}
