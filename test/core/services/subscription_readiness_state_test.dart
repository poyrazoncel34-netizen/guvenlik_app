// The state model behind INDEPENDENT_REVIEW_ROUND_2.md R2-01.
//
// The defect: `isTemporarilyUnverifiable` is TRUE in the default uninitialized
// state, and the home readiness card was bound to it. A user who had never
// subscribed -- online, provider simply never initialised -- was therefore
// shown a permanent notice saying the device was offline and that emergency
// features keep working, while `PremiumFeature.panic` is Pro-gated and their
// `canUsePaidSafetyFeature` was false.
//
// The fix is a state model, not new copy: "not initialised yet" and "previously
// confirmed, currently unverifiable" are different facts and must classify
// differently. This file pins that separation across every persisted and
// forged shape the state can take (scenarios A-N of the convergence brief) and
// asserts the coupling invariant that makes UI/authorization disagreement
// unrepresentable.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

/// One row of the scenario table. Every field is asserted, so a change that
/// widens authorization without widening the UI category (or vice versa) fails.
class _Scenario {
  const _Scenario(
    this.id,
    this.state, {
    required this.readiness,
    required this.emergency,
    required this.nonEmergency,
    required this.notice,
  });

  final String id;
  final SubscriptionAccessState state;
  final SubscriptionReadiness readiness;
  final bool emergency;
  final bool nonEmergency;
  final SubscriptionNotice notice;
}

void main() {
  final now = DateTime(2026, 8, 13, 12);
  DateTime ago(Duration d) => now.subtract(d);

  SubscriptionAccessState at(
    SubscriptionAccessStatus status, {
    bool? verified,
    DateTime? verifiedAt,
  }) => SubscriptionAccessState(
    status: status,
    lastVerifiedPro: verified,
    lastVerifiedProAt: verifiedAt,
  );

  final scenarios = <_Scenario>[
    // ---- A: brand-new, never subscribed. THE R2-01 STATE. ------------------
    const _Scenario(
      'A brand-new never-subscribed',
      SubscriptionAccessState.uninitialized(),
      readiness: SubscriptionReadiness.uninitialized,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- B: never subscribed, and the store is unreachable too. -----------
    _Scenario(
      'B never-subscribed offline',
      at(SubscriptionAccessStatus.unavailable),
      readiness: SubscriptionReadiness.unknownNoEntitlement,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- C: resolution in flight, nothing decided yet. ---------------------
    _Scenario(
      'C resolving, no anchor',
      at(SubscriptionAccessStatus.loading),
      readiness: SubscriptionReadiness.resolving,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- D/H: the store positively answered "not a subscriber". -----------
    _Scenario(
      'D confirmed free',
      at(SubscriptionAccessStatus.verifiedFree, verified: false),
      readiness: SubscriptionReadiness.notEntitledConfirmed,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    _Scenario(
      'H confirmed expired after a prior Pro answer',
      at(SubscriptionAccessStatus.verifiedFree, verified: false),
      readiness: SubscriptionReadiness.notEntitledConfirmed,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- E: confirmed active. ---------------------------------------------
    _Scenario(
      'E confirmed active Pro',
      at(SubscriptionAccessStatus.verifiedPro, verified: true, verifiedAt: now),
      readiness: SubscriptionReadiness.entitledConfirmed,
      emergency: true,
      nonEmergency: true,
      // Nothing is stale: an answer exists.
      notice: SubscriptionNotice.none,
    ),
    // ---- F: confirmed active, then a transient network failure. -----------
    _Scenario(
      'F prior-confirmed Pro + brief network failure',
      at(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: ago(const Duration(hours: 2)),
      ),
      readiness: SubscriptionReadiness.entitledUnverifiable,
      emergency: true,
      nonEmergency: true,
      notice: SubscriptionNotice.verificationPending,
    ),
    // ---- F2: the same, inside the 48h advance-warning threshold. ----------
    _Scenario(
      'F2 prior-confirmed Pro, 6 days offline (24h of grace left)',
      at(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: ago(const Duration(days: 6)),
      ),
      readiness: SubscriptionReadiness.entitledUnverifiable,
      emergency: true,
      nonEmergency: true,
      notice: SubscriptionNotice.verificationPendingGraceExpiring,
    ),
    // ---- G: long offline. Emergency is UNBOUNDED (IR-04); the rest lapses. -
    _Scenario(
      'G prior-confirmed Pro, 90 days offline',
      at(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: ago(const Duration(days: 90)),
      ),
      readiness: SubscriptionReadiness.entitledUnverifiable,
      emergency: true,
      nonEmergency: false,
      notice: SubscriptionNotice.nonEmergencyGraceLapsed,
    ),
    // ---- I: cold restart with the anchor still on disk, before init. ------
    _Scenario(
      'I restart from persisted Pro anchor, before initialization',
      at(
        SubscriptionAccessStatus.uninitialized,
        verified: true,
        verifiedAt: ago(const Duration(hours: 3)),
      ),
      readiness: SubscriptionReadiness.entitledUnverifiable,
      emergency: true,
      nonEmergency: true,
      notice: SubscriptionNotice.verificationPending,
    ),
    // ---- J: persisted fields missing entirely. -----------------------------
    _Scenario(
      'J persisted fields missing',
      at(SubscriptionAccessStatus.unavailable),
      readiness: SubscriptionReadiness.unknownNoEntitlement,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- K: corrupted anchor -- a future timestamp (rolled-back clock). ---
    _Scenario(
      'K corrupted anchor (future timestamp)',
      at(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: DateTime(2026, 8, 23, 12),
      ),
      readiness: SubscriptionReadiness.entitledUnverifiable,
      // Documented policy: a wrong device clock must never remove SOS from a
      // confirmed subscriber. Billing-side access IS withdrawn.
      emergency: true,
      nonEmergency: false,
      notice: SubscriptionNotice.nonEmergencyGraceLapsed,
    ),
    // ---- L: single-value forgery -- flag without corroborating timestamp. -
    _Scenario(
      'L forged lastVerifiedPro flag alone',
      at(SubscriptionAccessStatus.unavailable, verified: true),
      readiness: SubscriptionReadiness.unknownNoEntitlement,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- M: single-value forgery -- timestamp without the flag. -----------
    _Scenario(
      'M forged timestamp alone',
      at(
        SubscriptionAccessStatus.unavailable,
        verifiedAt: ago(const Duration(hours: 1)),
      ),
      readiness: SubscriptionReadiness.unknownNoEntitlement,
      emergency: false,
      nonEmergency: false,
      notice: SubscriptionNotice.none,
    ),
    // ---- N: a genuine, corroborated prior entitlement. --------------------
    _Scenario(
      'N corroborated prior entitlement restored',
      const SubscriptionAccessState.uninitialized().withRestoredProAnchor(
        DateTime(2026, 8, 13, 6),
        corroborated: true,
      ),
      readiness: SubscriptionReadiness.entitledUnverifiable,
      emergency: true,
      nonEmergency: true,
      notice: SubscriptionNotice.verificationPending,
    ),
  ];

  group('subscription readiness state model (R2-01)', () {
    for (final scenario in scenarios) {
      test('${scenario.id}: classifies and authorizes consistently', () {
        expect(
          scenario.state.readiness,
          scenario.readiness,
          reason: '${scenario.id}: wrong semantic category',
        );
        expect(
          scenario.state.canUsePaidSafetyFeature,
          scenario.emergency,
          reason: '${scenario.id}: wrong EMERGENCY authorization',
        );
        expect(
          scenario.state.canUseNonEmergencyPaidFeature,
          scenario.nonEmergency,
          reason: '${scenario.id}: wrong NON-EMERGENCY authorization',
        );
        expect(
          scenario.state.noticeFor(now: now),
          scenario.notice,
          reason: '${scenario.id}: wrong readiness notice',
        );
      });
    }

    test(
      'INVARIANT: a notice is emitted ONLY where the emergency path is '
      'actually authorized',
      () {
        // This is the whole of R2-01 in one assertion. Every notice variant
        // asserts "emergency features keep working"; if any state could emit a
        // notice without emergency authorization, the app would be lying.
        for (final scenario in scenarios) {
          final emits =
              scenario.state.noticeFor(now: now) != SubscriptionNotice.none;
          if (emits) {
            expect(
              scenario.state.canUsePaidSafetyFeature,
              isTrue,
              reason:
                  '${scenario.id} emits a continuity notice while '
                  'canUsePaidSafetyFeature is false -- the R2-01 defect.',
            );
          }
        }
      },
    );

    test('INVARIANT: readiness category and emergency authorization agree', () {
      for (final scenario in scenarios) {
        final entitled =
            scenario.state.readiness ==
                SubscriptionReadiness.entitledConfirmed ||
            scenario.state.readiness ==
                SubscriptionReadiness.entitledUnverifiable;
        expect(
          entitled,
          scenario.state.canUsePaidSafetyFeature,
          reason:
              '${scenario.id}: readiness says ${scenario.state.readiness} but '
              'canUsePaidSafetyFeature is '
              '${scenario.state.canUsePaidSafetyFeature}',
        );
      }
    });

    test(
      'NEGATIVE CONTROL: the boolean the old UI was bound to is still true '
      'for the unprotected states -- only the new derivation separates them',
      () {
        // If this ever passes trivially (because isTemporarilyUnverifiable
        // stopped being true by default), the rest of this file would still be
        // green while proving nothing. Assert the hazard is real.
        const fresh = SubscriptionAccessState.uninitialized();
        expect(
          fresh.isTemporarilyUnverifiable,
          isTrue,
          reason:
              'The old home wiring read exactly this boolean. It is TRUE '
              'here -- that is why binding UI to it produced a false claim.',
        );
        expect(fresh.canUsePaidSafetyFeature, isFalse);
        expect(
          fresh.noticeFor(now: now),
          SubscriptionNotice.none,
          reason:
              'Restoring the uninitialized -> temporarily-unverifiable '
              'equivalence must fail here.',
        );

        // Same hazard for the never-subscribed offline user.
        final offlineStranger = at(SubscriptionAccessStatus.unavailable);
        expect(offlineStranger.isTemporarilyUnverifiable, isTrue);
        expect(offlineStranger.canUsePaidSafetyFeature, isFalse);
        expect(offlineStranger.noticeFor(now: now), SubscriptionNotice.none);
      },
    );

    test('unknown is never converted into a confirmed-free answer', () {
      for (final scenario in scenarios) {
        if (scenario.state.status == SubscriptionAccessStatus.verifiedFree) {
          continue;
        }
        expect(
          scenario.state.isConfirmedInactive,
          isFalse,
          reason: '${scenario.id} must not read as a positive "free" answer',
        );
        expect(
          scenario.state.shouldShowPaywall,
          isFalse,
          reason:
              '${scenario.id} must not route an unresolved state to the '
              'paywall',
        );
      }
    });

    test('the advance warning reports the remaining window, not a constant', () {
      final sixDays = at(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: ago(const Duration(days: 6)),
      );
      expect(sixDays.remainingOfflineGraceHours(now: now), 24);

      final ninetyMinutes = at(
        SubscriptionAccessStatus.unavailable,
        verified: true,
        verifiedAt: ago(const Duration(days: 7) - const Duration(minutes: 90)),
      );
      // 90 minutes left must round UP to 2, never down to 1.
      expect(ninetyMinutes.remainingOfflineGraceHours(now: now), 2);

      // No window at all where there is no genuine anchor.
      expect(
        const SubscriptionAccessState.uninitialized().remainingOfflineGraceHours(
          now: now,
        ),
        isNull,
      );
    });

    test('entitlementDecision stays unknown, never denied, without an anchor', () {
      expect(
        at(SubscriptionAccessStatus.unavailable).entitlementDecision,
        EntitlementDecision.unknown,
      );
      expect(
        at(
          SubscriptionAccessStatus.verifiedFree,
          verified: false,
        ).entitlementDecision,
        EntitlementDecision.denied,
      );
    });
  });
}
