// IR-04 policy cover: network unavailability alone must never disable the
// emergency action for a last-confirmed-active subscriber.
//
// PRODUCT POLICY (owner decision, 2026-08-13): failure to refresh entitlement
// is NOT equivalent to confirmed expiry. UNKNOWN is never silently converted to
// EXPIRED. A positively confirmed inactive subscription still denies.
//
// Non-emergency paid features keep the bounded offline grace, so billing
// integrity is preserved where nobody's safety is at stake.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/feature_access_matrix.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

SubscriptionAccessState offlineSubscriber(Duration age, {required DateTime now}) =>
    SubscriptionAccessState(
      status: SubscriptionAccessStatus.unavailable,
      lastVerifiedPro: true,
      lastVerifiedProAt: now.subtract(age),
    );

void main() {
  final now = DateTime(2026, 8, 13, 12);

  group('1. active subscriber, online verification', () {
    test('confirmed active authorizes the emergency action', () {
      final s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedPro,
        lastVerifiedPro: true,
        lastVerifiedProAt: now,
      );
      expect(s.entitlementDecision, EntitlementDecision.authorized);
      expect(s.canUsePaidSafetyFeature, isTrue);
      expect(s.canUseNonEmergencyPaidFeature, isTrue);
      expect(s.isTemporarilyUnverifiable, isFalse);
      expect(s.isConfirmedInactive, isFalse);
    });
  });

  group('2. active subscriber, offline 3 days', () {
    test('emergency AND non-emergency both remain available', () {
      final s = offlineSubscriber(const Duration(days: 3), now: now);
      expect(s.canUsePaidSafetyFeature, isTrue);
      expect(s.canUseNonEmergencyPaidFeature, isTrue);
    });
  });

  group('3. active subscriber, offline BEYOND the old 7-day threshold', () {
    test('SOS stays available at 8 days -- the IR-04 regression', () {
      final s = offlineSubscriber(const Duration(days: 8), now: now);
      expect(
        s.entitlementDecision,
        EntitlementDecision.authorized,
        reason:
            'This is the exact state the independent reviewer reproduced. '
            'A paying subscriber must not lose SOS because the store was '
            'unreachable.',
      );
      expect(s.canUsePaidSafetyFeature, isTrue);
    });

    test('SOS stays available at 90 days -- the policy is unbounded', () {
      final s = offlineSubscriber(const Duration(days: 90), now: now);
      expect(s.canUsePaidSafetyFeature, isTrue);
    });

    test('non-emergency paid features DO lapse, preserving billing integrity', () {
      final s = offlineSubscriber(const Duration(days: 8), now: now);
      expect(
        s.canUseNonEmergencyPaidFeature,
        isFalse,
        reason:
            'The unbounded policy covers safety, not convenience features.',
      );
      expect(
        s.nonEmergencyEntitlementDecision,
        EntitlementDecision.unknown,
      );
    });
  });

  group('4. entitlement refresh failure', () {
    test('a failed refresh is UNKNOWN, never EXPIRED', () {
      final s = offlineSubscriber(const Duration(days: 30), now: now);
      expect(s.isTemporarilyUnverifiable, isTrue);
      expect(
        s.isConfirmedInactive,
        isFalse,
        reason: 'an unreachable store never means "not a subscriber"',
      );
      expect(
        s.verifiedEntitlementDecision,
        EntitlementDecision.unknown,
        reason: 'store truth is still unknown...',
      );
      expect(
        s.entitlementDecision,
        EntitlementDecision.authorized,
        reason: '...but the emergency action is still authorized',
      );
    });

    test('loading is also treated as unverifiable, not as denial', () {
      final s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.loading,
        lastVerifiedPro: true,
        lastVerifiedProAt: now.subtract(const Duration(days: 40)),
      );
      expect(s.canUsePaidSafetyFeature, isTrue);
    });
  });

  group('5. entitlement later positively confirmed expired', () {
    test('a confirmed-inactive answer DOES deny the emergency action', () {
      const s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: false,
      );
      expect(s.isConfirmedInactive, isTrue);
      expect(s.entitlementDecision, EntitlementDecision.denied);
      expect(s.canUsePaidSafetyFeature, isFalse);
      expect(s.shouldShowPaywall, isTrue);
    });

    test('a confirmed-inactive answer overrides a stale active anchor', () {
      final s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: false,
        lastVerifiedProAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        s.entitlementDecision,
        EntitlementDecision.denied,
        reason:
            'The store answered. An answer beats an absence of one -- the '
            'policy widens UNKNOWN, not DENIED.',
      );
    });
  });

  group('6. app restart while entitlement is unverifiable', () {
    test('a persisted active anchor survives a cold start with no signal', () {
      // Cold start: status resets to uninitialized, but the persisted anchor
      // is what the offline case exists for.
      final s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.uninitialized,
        lastVerifiedPro: true,
        lastVerifiedProAt: now.subtract(const Duration(days: 20)),
      );
      expect(s.canUsePaidSafetyFeature, isTrue);
    });

    test('a fresh install with NO anchor cannot arm offline', () {
      const s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
      );
      expect(
        s.canUsePaidSafetyFeature,
        isFalse,
        reason:
            'Never confirmed active, so there is nothing to preserve. This is '
            'the one refusal the policy does not widen.',
      );
      expect(s.entitlementDecision, EntitlementDecision.unknown);
    });
  });

  group('7. SOS availability across every state', () {
    final matrix = <String, (SubscriptionAccessState, bool)>{
      'confirmed active': (
        SubscriptionAccessState(
          status: SubscriptionAccessStatus.verifiedPro,
          lastVerifiedPro: true,
          lastVerifiedProAt: now,
        ),
        true,
      ),
      'confirmed inactive': (
        const SubscriptionAccessState(
          status: SubscriptionAccessStatus.verifiedFree,
          lastVerifiedPro: false,
        ),
        false,
      ),
      'unverifiable, was active': (
        offlineSubscriber(const Duration(days: 400), now: now),
        true,
      ),
      'unverifiable, never active': (
        const SubscriptionAccessState(
          status: SubscriptionAccessStatus.unavailable,
        ),
        false,
      ),
    };

    matrix.forEach((name, pair) {
      test('SOS available in "$name" == ${pair.$2}', () {
        expect(pair.$1.canUsePaidSafetyFeature, pair.$2);
      });
    });
  });

  group('feature classification', () {
    test('every emergency-capable feature is covered by the policy', () {
      expect(
        FeatureAccessMatrix.emergencyCapableFeatures,
        containsAll(<PremiumFeature>[
          PremiumFeature.panic,
          PremiumFeature.safeWalk,
          PremiumFeature.checkIn,
          PremiumFeature.volumeTrigger,
        ]),
      );
    });

    test('convenience features are NOT emergency-capable', () {
      expect(FeatureAccessMatrix.isEmergencyCapable(PremiumFeature.timeline), isFalse);
      expect(
        FeatureAccessMatrix.isEmergencyCapable(PremiumFeature.advancedAutomation),
        isFalse,
      );
    });
  });

  group('an already-armed session is never revoked mid-emergency', () {
    test('confirmed-inactive does not tear down a running session', () {
      const s = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: true,
      );
      expect(s.canUsePaidSafetyFeature, isFalse, reason: 'cannot arm anything new');
      expect(
        s.canContinueAlreadyArmedSession,
        isTrue,
        reason:
            'an emergency already in flight must not be cancelled because a '
            'billing check changed',
      );
    });
  });
}
