// Regression cover for the offline-grace-expiry path on the panic entitlement.
//
// WHY THIS FILE EXISTS -- an independent reviewer reproduced a state in which a
// PAYING subscriber loses the SOS/panic button purely because the store has
// been unreachable for longer than `offlineGracePeriod` (7 days). Nothing
// warned them beforehand: `offlineGracePeriod` was referenced only inside its
// own file, so the first signal was the button refusing to arm.
//
// For this product the catastrophic failure is "the panic button does not
// dial". These cases pin the exact transition so it can never drift silently,
// and pin the new pre-expiry signal that makes it visible in advance.
//
// NOTE ON SCOPE: whether panic should be Pro-gated AT ALL is a product/business
// decision and is deliberately NOT decided here. See PRODUCTION_AUDIT.md
// MP-22-001 / MP-54-029.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

/// A subscriber whose last verified-Pro answer is [age] old and whose store is
/// now unreachable.
SubscriptionAccessState offlineSubscriber(Duration age, {DateTime? now}) {
  final moment = now ?? DateTime.now();
  return SubscriptionAccessState(
    status: SubscriptionAccessStatus.unavailable,
    lastVerifiedPro: true,
    lastVerifiedProAt: moment.subtract(age),
  );
}

void main() {
  final now = DateTime(2026, 8, 13, 12);

  group('the reproduced transition', () {
    test('3 days offline: a paying subscriber can still arm', () {
      final state = offlineSubscriber(const Duration(days: 3), now: now);
      expect(state.canArmWithinOfflineGrace(now: now), isTrue);
      expect(state.entitlementDecision, EntitlementDecision.authorized);
    });

    test('8 days offline: the SAME subscriber loses the panic button', () {
      final state = offlineSubscriber(const Duration(days: 8), now: now);
      expect(
        state.canArmWithinOfflineGrace(now: now),
        isFalse,
        reason:
            'This is the reproduced state: a paying user, offline past the '
            'grace window, whose panic button now refuses to arm.',
      );
      expect(state.entitlementDecision, EntitlementDecision.unknown);
      expect(state.hasLostAccessToOfflineGraceExpiry(now: now), isTrue);
    });

    test('the boundary is exactly 7 days, inclusive', () {
      expect(
        offlineSubscriber(SubscriptionAccessState.offlineGracePeriod, now: now)
            .canArmWithinOfflineGrace(now: now),
        isTrue,
      );
      expect(
        offlineSubscriber(
          SubscriptionAccessState.offlineGracePeriod +
              const Duration(seconds: 1),
          now: now,
        ).canArmWithinOfflineGrace(now: now),
        isFalse,
      );
    });

    test('a future anchor (rolled-back clock) does not grant access', () {
      final state = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
        lastVerifiedPro: true,
        lastVerifiedProAt: now.add(const Duration(days: 1)),
      );
      expect(state.canArmWithinOfflineGrace(now: now), isFalse);
      expect(state.remainingOfflineGrace(now: now), Duration.zero);
    });

    test('a fresh install with no anchor cannot arm offline', () {
      const state = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
      );
      expect(state.canArmWithinOfflineGrace(), isFalse);
      expect(state.remainingOfflineGrace(), isNull);
    });
  });

  group('advance warning -- the gap the review identified', () {
    test('remaining grace is reported so the UI can warn before the cliff', () {
      final state = offlineSubscriber(const Duration(days: 6), now: now);
      expect(state.remainingOfflineGrace(now: now), const Duration(days: 1));
    });

    test('expiring within 48h is flagged', () {
      expect(
        offlineSubscriber(const Duration(days: 6), now: now)
            .isOfflineGraceExpiring(now: now),
        isTrue,
      );
    });

    test('a comfortable window is NOT flagged, so the warning stays meaningful', () {
      expect(
        offlineSubscriber(const Duration(days: 2), now: now)
            .isOfflineGraceExpiring(now: now),
        isFalse,
      );
    });

    test('an already-expired window is not reported as "expiring"', () {
      final state = offlineSubscriber(const Duration(days: 9), now: now);
      expect(state.isOfflineGraceExpiring(now: now), isFalse);
      expect(state.hasLostAccessToOfflineGraceExpiry(now: now), isTrue);
    });

    test('a verified store answer suppresses the warning entirely', () {
      final verified = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedPro,
        lastVerifiedPro: true,
        lastVerifiedProAt: now.subtract(const Duration(days: 6)),
      );
      expect(
        verified.isOfflineGraceExpiring(now: now),
        isFalse,
        reason:
            'The window only matters while the store is unreachable; warning a '
            'user whose entitlement just verified would be noise.',
      );
      expect(verified.hasLostAccessToOfflineGraceExpiry(now: now), isFalse);
    });

    test('a verified FREE user is never told about a grace window', () {
      const free = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: false,
      );
      expect(free.isOfflineGraceExpiring(), isFalse);
      expect(free.remainingOfflineGrace(), isNull);
    });
  });

  group('an already-armed session is not revoked mid-emergency', () {
    test('expiry does not tear down a session that is already running', () {
      final state = offlineSubscriber(const Duration(days: 9), now: now);
      expect(
        state.canUsePaidSafetyFeature,
        isFalse,
        reason: 'cannot arm anything NEW',
      );
      expect(
        state.canContinueAlreadyArmedSession,
        isTrue,
        reason:
            'but an emergency already in flight must not be cancelled because '
            'a billing refresh failed.',
      );
    });
  });
}
