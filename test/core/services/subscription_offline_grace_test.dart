import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

/// The grace window has to reach the *authorization* every layer reads, not
/// just a gate's return value.
///
/// The panic path checks entitlement three independent times -- `panic_button`
/// re-reads `entitlementDecision` after the gate, `CountdownScreen` gates the
/// native alarm on it, and the Kotlin side rejects `unknown` again. An earlier
/// attempt widened only the gate's bool and changed nothing, so these tests
/// assert on `entitlementDecision` itself.
void main() {
  final now = DateTime.utc(2026, 7, 31, 12);

  SubscriptionAccessState unresolved({
    bool? lastPro,
    DateTime? verifiedAt,
  }) => SubscriptionAccessState(
    status: SubscriptionAccessStatus.unavailable,
    lastVerifiedPro: lastPro,
    lastVerifiedProAt: verifiedAt,
  );

  group('grace reaches entitlementDecision', () {
    test('an unresolved entitlement inside the window reads as authorized', () {
      final state = unresolved(
        lastPro: true,
        verifiedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      // What the store said: nothing.
      expect(state.verifiedEntitlementDecision, EntitlementDecision.unknown);
      // What every layer acts on: authorized.
      expect(state.entitlementDecision, EntitlementDecision.authorized);
      expect(state.canUsePaidSafetyFeature, isTrue);
    });

    test('an aged anchor still authorizes the EMERGENCY path (IR-04)', () {
      final state = unresolved(
        lastPro: true,
        verifiedAt: DateTime.now().subtract(
          SubscriptionAccessState.offlineGracePeriod +
              const Duration(days: 1),
        ),
      );

      // Superseded behaviour: this used to fall back to unknown and disable
      // the panic button. Owner product decision 2026-08-13 -- a failed
      // refresh is not a confirmed expiry, so a corroborated prior
      // confirmation keeps the emergency path open indefinitely.
      expect(state.entitlementDecision, EntitlementDecision.authorized);
      expect(state.canUsePaidSafetyFeature, isTrue);
      // Non-emergency paid features still lapse: billing integrity is intact
      // where nobody's safety is at stake.
      expect(
        state.nonEmergencyEntitlementDecision,
        EntitlementDecision.unknown,
      );
      expect(state.canUseNonEmergencyPaidFeature, isFalse);
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
    });

    test('a future anchor is rejected, not trusted', () {
      final state = unresolved(
        lastPro: true,
        verifiedAt: now.add(const Duration(days: 1)),
      );

      expect(state.canArmWithinOfflineGrace(now: now), isFalse);
    });
  });

  group('fail-closed for answers that actually arrived', () {
    test('a verified-free answer stays denied and never consults the window', () {
      const state = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedFree,
        lastVerifiedPro: false,
      );

      expect(state.entitlementDecision, EntitlementDecision.denied);
      expect(state.shouldShowPaywall, isTrue);
      expect(state.canArmWithinOfflineGrace(now: now), isFalse);
    });

    test('markVerified(free) retires the anchor', () {
      final pro = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: true,
        at: now,
      );
      expect(pro.lastVerifiedProAt, now);

      final lapsed = pro.markVerified(isPro: false);
      expect(lapsed.lastVerifiedProAt, isNull);
      expect(lapsed.entitlementDecision, EntitlementDecision.denied);
    });

    test('an unresolved entitlement with no anchor stays unknown', () {
      expect(
        unresolved(lastPro: true).entitlementDecision,
        EntitlementDecision.unknown,
      );
      expect(unresolved().entitlementDecision, EntitlementDecision.unknown);
    });
  });

  group('the anchor cannot be forged from a single value', () {
    test('an uncorroborated timestamp grants nothing', () {
      // Writing one integer into local storage must not claim a verified answer
      // that never happened.
      const coldStart = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
      );

      final forged = coldStart.withRestoredProAnchor(
        DateTime.now().subtract(const Duration(days: 1)),
        corroborated: false,
      );

      expect(forged.lastVerifiedPro, isNull);
      expect(forged.lastVerifiedProAt, isNull);
      expect(forged.entitlementDecision, EntitlementDecision.unknown);
    });

    test('a corroborated anchor restores grace after a cold start', () {
      const coldStart = SubscriptionAccessState(
        status: SubscriptionAccessStatus.unavailable,
      );
      expect(coldStart.entitlementDecision, EntitlementDecision.unknown);

      final restored = coldStart.withRestoredProAnchor(
        DateTime.now().subtract(const Duration(days: 2)),
        corroborated: true,
      );

      expect(restored.status, SubscriptionAccessStatus.unavailable);
      expect(restored.verifiedEntitlementDecision, EntitlementDecision.unknown);
      expect(restored.entitlementDecision, EntitlementDecision.authorized);
    });

    test('a late anchor read cannot resurrect a cleared timestamp', () {
      // A verified-free answer clears the anchor. If the persisted read is
      // still in flight and lands afterwards, it must change nothing -- not
      // even the timestamp on its own.
      final free = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: false,
      );
      expect(free.lastVerifiedProAt, isNull);

      final late = free.withRestoredProAnchor(
        DateTime.now().subtract(const Duration(hours: 1)),
        corroborated: true,
      );

      expect(late.lastVerifiedProAt, isNull, reason: 'anchor stays cleared');
      expect(late.lastVerifiedPro, isFalse);
      expect(late.entitlementDecision, EntitlementDecision.denied);
    });

    test('a restored anchor never overrides a resolved answer', () {
      final free = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: false,
      );

      final restored = free.withRestoredProAnchor(now, corroborated: true);
      expect(restored.lastVerifiedPro, isFalse);
      expect(restored.entitlementDecision, EntitlementDecision.denied);
    });
  });

  group('transitions carry the anchor', () {
    test('markLoading and markUnavailable preserve it', () {
      final pro = const SubscriptionAccessState.uninitialized().markVerified(
        isPro: true,
        at: DateTime.now(),
      );

      expect(pro.markLoading().lastVerifiedProAt, isNotNull);
      expect(
        pro.markUnavailable().entitlementDecision,
        EntitlementDecision.authorized,
      );
    });
  });
}
