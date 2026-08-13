import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Panic button Pro-only honesty', () {
    late String source;

    setUp(() {
      source = File('lib/widgets/panic_button.dart').readAsStringSync();
    });

    test('free users see locked Pro copy before long press', () {
      expect(source, contains('panic_button_locked_title'));
      expect(source, contains('panic_button_locked_subtitle'));
      expect(source, contains('subscription_badge_pro'));
      // Deliberately the EMERGENCY getter, not the commercial `isPro`: this
      // control follows the unbounded offline policy, so a subscriber whose
      // store call is failing must still see an armed button. Reading `isPro`
      // here would lock the SOS button for a user the gate would authorize
      // (INDEPENDENT_REVIEW_ROUND_2.md R2-04).
      expect(
        source,
        contains(
          'context.watch<SubscriptionProvider>().canUseEmergencyFeature',
        ),
      );
      expect(
        source,
        isNot(contains('context.watch<SubscriptionProvider>().isPro')),
        reason:
            'the commercial getter is bounded by the 7-day grace and must not '
            'gate an emergency control',
      );
    });

    test('free hold uses SubscriptionGate and cannot open countdown', () {
      final startIndex = source.indexOf('Future<void> _armPress');
      final openIndex = source.indexOf('Future<void> _openCountdownScreen');
      final pressStart = source.substring(startIndex, openIndex);

      expect(pressStart, contains('PremiumFeature.panic'));
      expect(pressStart, contains('SubscriptionGate.ensureAccess'));
      expect(
        pressStart,
        contains(
          'if (!mounted || !allowed || !_isCurrentPress(epoch)) return;',
        ),
      );
    });

    test('Pro users retain active panic copy and countdown route', () {
      expect(source, contains('panic_button_hold_title'));
      expect(source, contains('panic_button_hold_subtitle'));
      expect(
        source,
        contains('CountdownScreen(entitlementDecision: entitlementDecision)'),
      );
    });
  });
}
