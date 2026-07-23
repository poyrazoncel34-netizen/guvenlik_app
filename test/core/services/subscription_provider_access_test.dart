import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/revenue_cat_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test(
    'failed refresh preserves an armed lease but resolveAccess stays unknown',
    () async {
      final fake = _FakeRevenueCatService()..nextInfo = _verifiedProInfo();
      final provider = SubscriptionProvider(revenueCatService: fake);
      addTearDown(provider.dispose);

      await provider.initialize();
      expect(provider.accessStatus, SubscriptionAccessStatus.verifiedPro);
      expect(provider.isPro, isTrue);
      expect(
        provider.access.entitlementDecision,
        EntitlementDecision.authorized,
      );

      fake.nextInfo = null; // network/config/cache uncertainty
      final resolvedForNewArm = await provider.resolveAccess();

      expect(provider.accessStatus, SubscriptionAccessStatus.unavailable);
      expect(provider.isPro, isFalse);
      expect(provider.access.entitlementDecision, EntitlementDecision.unknown);
      expect(provider.access.canContinueAlreadyArmedSession, isTrue);
      expect(
        resolvedForNewArm.entitlementDecision,
        EntitlementDecision.unknown,
      );
      expect(resolvedForNewArm.canUsePaidSafetyFeature, isFalse);
    },
  );

  test('older refresh cannot overwrite a newer verified revocation', () async {
    final fake = _FakeRevenueCatService()..nextInfo = _verifiedProInfo();
    final provider = SubscriptionProvider(revenueCatService: fake);
    addTearDown(provider.dispose);
    await provider.initialize();
    expect(provider.isPro, isTrue);

    final staleRefresh = Completer<CustomerInfo?>();
    fake.customerInfoCompleter = staleRefresh;
    final refreshFuture = provider.refresh();
    await Future<void>.delayed(Duration.zero);

    fake.restoreInfo = _verifiedFreeInfo();
    await provider.restorePurchases();
    expect(provider.accessStatus, SubscriptionAccessStatus.verifiedFree);

    staleRefresh.complete(_verifiedProInfo());
    await refreshFuture;

    expect(provider.accessStatus, SubscriptionAccessStatus.verifiedFree);
    expect(provider.entitlementDecision, EntitlementDecision.denied);
  });
}

class _FakeRevenueCatService extends RevenueCatService {
  CustomerInfo? nextInfo;
  CustomerInfo? restoreInfo;
  Completer<CustomerInfo?>? customerInfoCompleter;

  @override
  bool get isConfigured => false;

  @override
  Future<bool> ensureInitialized() async => true;

  @override
  Future<CustomerInfo?> getCustomerInfo() async =>
      customerInfoCompleter?.future ?? nextInfo;

  @override
  Future<Offerings?> getOfferings() async => null;

  @override
  Future<CustomerInfo> restorePurchases() async => restoreInfo!;

  @override
  Future<void> rememberVerifiedProInitializationHint() async {}
}

CustomerInfo _verifiedProInfo() {
  const entitlement = EntitlementInfo(
    RevenueCatService.entitlementId,
    true,
    false,
    '2026-07-18T00:00:00Z',
    '2026-07-18T00:00:00Z',
    'korubeni_pro_monthly',
    false,
    verification: VerificationResult.verified,
  );
  return const CustomerInfo(
    EntitlementInfos(
      {RevenueCatService.entitlementId: entitlement},
      {RevenueCatService.entitlementId: entitlement},
      verification: VerificationResult.verified,
    ),
    {},
    [],
    [],
    [],
    '2026-07-18T00:00:00Z',
    'anonymous',
    {},
    '2026-07-18T00:00:00Z',
  );
}

CustomerInfo _verifiedFreeInfo() => const CustomerInfo(
  EntitlementInfos({}, {}, verification: VerificationResult.verified),
  {},
  [],
  [],
  [],
  '2026-07-19T00:00:00Z',
  'anonymous',
  {},
  '2026-07-19T00:00:00Z',
);
