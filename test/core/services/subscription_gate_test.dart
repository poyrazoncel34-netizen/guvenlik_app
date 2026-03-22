import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/subscription_gate.dart';

void main() {
  group('SubscriptionGate.canAddContact', () {
    test('free user with 0 contacts can add', () {
      expect(SubscriptionGate.canAddContact(currentCount: 0, isPro: false), isTrue);
    });

    test('free user with 1 contact cannot add more', () {
      expect(SubscriptionGate.canAddContact(currentCount: 1, isPro: false), isFalse);
    });

    test('pro user with 1 contact can add more', () {
      expect(SubscriptionGate.canAddContact(currentCount: 1, isPro: true), isTrue);
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
