import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

void main() {
  test('loading and unavailable are never misclassified as verified free', () {
    const loading = SubscriptionAccessState(
      status: SubscriptionAccessStatus.loading,
    );
    const unavailable = SubscriptionAccessState(
      status: SubscriptionAccessStatus.unavailable,
    );

    expect(loading.canUsePaidSafetyFeature, isFalse);
    expect(loading.shouldShowPaywall, isFalse);
    expect(unavailable.canUsePaidSafetyFeature, isFalse);
    expect(unavailable.shouldShowPaywall, isFalse);
  });

  test(
    'transient verification failure preserves only an already-armed lease',
    () {
      const verified = SubscriptionAccessState(
        status: SubscriptionAccessStatus.verifiedPro,
        lastVerifiedPro: true,
      );
      final unavailable = verified.markUnavailable();

      expect(unavailable.status, SubscriptionAccessStatus.unavailable);
      expect(
        unavailable.canUsePaidSafetyFeature,
        isFalse,
        reason: 'unknown verification must never authorize a new safety arm',
      );
      expect(unavailable.entitlementDecision, EntitlementDecision.unknown);
      expect(unavailable.canContinueAlreadyArmedSession, isTrue);
      expect(unavailable.shouldShowPaywall, isFalse);
    },
  );

  test('only an actual verified-free result routes to paywall', () {
    const free = SubscriptionAccessState(
      status: SubscriptionAccessStatus.verifiedFree,
      lastVerifiedPro: false,
    );

    expect(free.canUsePaidSafetyFeature, isFalse);
    expect(free.entitlementDecision, EntitlementDecision.denied);
    expect(free.shouldShowPaywall, isTrue);
  });

  test('gate awaits subscription resolution before deciding', () {
    final gate = File(
      'lib/core/services/subscription_gate.dart',
    ).readAsStringSync();
    expect(gate, contains('await provider.resolveAccess()'));
    expect(gate, contains('access.shouldShowPaywall'));
  });
}
