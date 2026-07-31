import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/core/services/subscription_gate.dart';

/// A paying Pro user whose phone lost signal must still be able to arm a panic
/// session, and a user the store actually reported as free must still not.
void main() {
  final now = DateTime.utc(2026, 7, 31, 12);

  SubscriptionAccessState unresolved({
    required bool? lastPro,
    DateTime? verifiedAt,
  }) => SubscriptionAccessState(
    status: SubscriptionAccessStatus.unavailable,
    lastVerifiedPro: lastPro,
    lastVerifiedProAt: verifiedAt,
  );

  group('offline grace window', () {
    test('a verified Pro inside the window may arm while unresolved', () {
      final state = unresolved(
        lastPro: true,
        verifiedAt: now.subtract(const Duration(days: 6, hours: 23)),
      );

      expect(state.entitlementDecision, EntitlementDecision.unknown);
      expect(state.canUsePaidSafetyFeature, isFalse); // strict rule unchanged
      expect(state.canArmWithinOfflineGrace(now: now), isTrue);
      expect(SubscriptionGate.canArmSafetySession(state, now: now), isTrue);
    });

    test('the window closes exactly at seven days', () {
      final atEdge = unresolved(
        lastPro: true,
        verifiedAt: now.subtract(SubscriptionAccessState.offlineGracePeriod),
      );
      final pastEdge = unresolved(
        lastPro: true,
        verifiedAt: now.subtract(
          SubscriptionAccessState.offlineGracePeriod +
              const Duration(seconds: 1),
        ),
      );

      expect(atEdge.canArmWithinOfflineGrace(now: now), isTrue);
      expect(pastEdge.canArmWithinOfflineGrace(now: now), isFalse);
      expect(SubscriptionGate.canArmSafetySession(pastEdge, now: now), isFalse);
    });

    test('a future anchor is rejected, not trusted', () {
      // Rolled-back clock or a tampered store must not widen the window.
      final state = unresolved(
        lastPro: true,
        verifiedAt: now.add(const Duration(days: 1)),
      );

      expect(state.canArmWithinOfflineGrace(now: now), isFalse);
    });

    test('no anchor means no grace', () {
      expect(
        unresolved(lastPro: true).canArmWithinOfflineGrace(now: now),
        isFalse,
      );
    });

    test('a previously verified FREE user gets no grace', () {
      final state = unresolved(lastPro: false, verifiedAt: now);

      expect(state.canArmWithinOfflineGrace(now: now), isFalse);
      expect(SubscriptionGate.canArmSafetySession(state, now: now), isFalse);
    });
  });

  group('fail-closed is preserved for answers that actually arrived', () {
    test('a verified-free answer denies even with a fresh anchor', () {
      // The store answered "not subscribed". That is evidence, not a failure,
      // so the grace window must never be consulted.
      const state = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: false,
      );

      expect(state.shouldShowPaywall, isTrue);
      expect(SubscriptionGate.canArmSafetySession(state, now: now), isFalse);
    });

    test('markVerified(free) retires the anchor', () {
      final pro = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: true,
        at: now,
      );
      expect(pro.lastVerifiedProAt, now);

      final lapsed = pro.markVerified(isPro: false);
      expect(lapsed.lastVerifiedProAt, isNull);
      expect(SubscriptionGate.canArmSafetySession(lapsed, now: now), isFalse);
    });

    test('a verified Pro answer arms without needing the window', () {
      final pro = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: true,
        at: now,
      );

      expect(pro.canUsePaidSafetyFeature, isTrue);
      expect(SubscriptionGate.canArmSafetySession(pro, now: now), isTrue);
    });
  });

  group('state transitions carry the anchor', () {
    test('markLoading and markUnavailable preserve it', () {
      final pro = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: true,
        at: now,
      );

      expect(pro.markLoading().lastVerifiedProAt, now);
      expect(pro.markUnavailable().lastVerifiedProAt, now);
      expect(pro.markUnavailable().canArmWithinOfflineGrace(now: now), isTrue);
    });

    test('withRestoredProAnchor rebuilds grace after a cold start', () {
      // Cold start with no network: status resolves to unavailable and the
      // in-process lastVerifiedPro is null, so only the persisted anchor can
      // authorize the press.
      const coldStart = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
      );
      expect(coldStart.canArmWithinOfflineGrace(now: now), isFalse);

      final restored = coldStart.withRestoredProAnchor(
        now.subtract(const Duration(days: 2)),
      );
      expect(restored.status, SubscriptionAccessStatus.unavailable);
      expect(restored.canArmWithinOfflineGrace(now: now), isTrue);
    });

    test('withRestoredProAnchor never overrides a resolved answer', () {
      final free = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: false,
      );

      final restored = free.withRestoredProAnchor(now);
      expect(restored.lastVerifiedPro, isFalse);
      expect(SubscriptionGate.canArmSafetySession(restored, now: now), isFalse);
    });
  });

  test('the panic press has a bounded entitlement wait', () {
    // An unbounded wait in front of a panic button is a delayed emergency call.
    expect(SubscriptionGate.entitlementResolveTimeout, isNotNull);
    expect(
      SubscriptionGate.entitlementResolveTimeout,
      lessThanOrEqualTo(const Duration(seconds: 2)),
    );
    expect(
      SubscriptionGate.entitlementResolveTimeout,
      greaterThan(Duration.zero),
    );
  });
}
