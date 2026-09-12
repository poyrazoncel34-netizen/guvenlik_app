import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/revenue_cat_service.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';
import 'package:guvenlik_app/presentation/providers/subscription_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('later denial waits for a delayed authorized evidence write', () async {
    final fake = _DelayedEvidenceService()..nextInfo = _verifiedProInfo();
    final provider = SubscriptionProvider(revenueCatService: fake);
    addTearDown(provider.dispose);
    final initializing = provider.initialize();
    await fake.started.future;
    fake.nextInfo = _verifiedFreeInfo();
    final denying = provider.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(provider.isPro, isFalse);
    fake.release.complete();
    await Future.wait([initializing, denying]);
    expect(fake.storedProAt, isNull);
    expect(fake.hintStored, isFalse);
    final restarted = SubscriptionProvider(
      revenueCatService: fake..nextInfo = null,
    );
    addTearDown(restarted.dispose);
    expect((await restarted.resolveAccess()).canUsePaidSafetyFeature, isFalse);
  });
  for (final evidence in <String, Map<String, Object>>{
    'absent': {},
    'hint only': {RevenueCatService.priorProInitializationHintKey: true},
    'anchor only': {RevenueCatService.lastVerifiedProAtKey: 1000},
    'corrupt anchor': {
      RevenueCatService.priorProInitializationHintKey: true,
      RevenueCatService.lastVerifiedProAtKey: 'not-a-timestamp',
    },
  }.entries) {
    test('offline persisted ${evidence.key} never invents access', () async {
      SharedPreferences.setMockInitialValues(evidence.value);
      final provider = SubscriptionProvider(
        revenueCatService: _OfflinePersistedService(),
      );
      addTearDown(provider.dispose);
      final access = await provider.resolveAccess();
      expect(access.canUsePaidSafetyFeature, isFalse);
      expect(access.canUseNonEmergencyPaidFeature, isFalse);
    });
  }

  test(
    'normal persisted anchor retains commercial grace on offline restart',
    () async {
      final anchor = DateTime.now().subtract(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues({
        RevenueCatService.priorProInitializationHintKey: true,
        RevenueCatService.lastVerifiedProAtKey: anchor.millisecondsSinceEpoch,
      });
      final provider = SubscriptionProvider(
        revenueCatService: _OfflinePersistedService(),
      );
      addTearDown(provider.dispose);
      final access = await provider.resolveAccess();
      expect(access.canUsePaidSafetyFeature, isTrue);
      expect(access.canUseNonEmergencyPaidFeature, isTrue);
      expect(
        access.lastVerifiedProAt?.millisecondsSinceEpoch,
        anchor.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'unparseable cache time cannot be stamped with the local clock',
    () async {
      final fake = _FakeRevenueCatService()
        ..nextInfo = _verifiedProInfo(requestDate: 'invalid');
      final provider = SubscriptionProvider(revenueCatService: fake);
      addTearDown(provider.dispose);
      await provider.initialize();
      expect(provider.access.canUsePaidSafetyFeature, isFalse);
      expect(fake.storedProAt, isNull);
    },
  );
  test(
    'cached trusted response preserves request time on repeated reads',
    () async {
      final fake = _FakeRevenueCatService()
        ..nextInfo = _verifiedProInfo(requestDate: '2026-07-18T00:00:00Z');
      final provider = SubscriptionProvider(revenueCatService: fake);
      addTearDown(provider.dispose);
      await provider.initialize();
      final requestAt = DateTime.parse(fake.nextInfo!.requestDate);
      expect(provider.access.lastVerifiedProAt, requestAt);
      expect(fake.storedProAt, requestAt);
      await provider.refresh();
      expect(provider.access.lastVerifiedProAt, requestAt);
      expect(fake.storedProAt, requestAt);
    },
  );

  test('real persisted future anchor survives offline cold start', () async {
    final future = DateTime.now().add(const Duration(days: 1));
    SharedPreferences.setMockInitialValues({
      RevenueCatService.priorProInitializationHintKey: true,
      RevenueCatService.lastVerifiedProAtKey: future.millisecondsSinceEpoch,
    });
    final provider = SubscriptionProvider(
      revenueCatService: _OfflinePersistedService(),
    );
    addTearDown(provider.dispose);
    final access = await provider.resolveAccess();
    expect(access.canUsePaidSafetyFeature, isTrue);
    expect(access.canUseNonEmergencyPaidFeature, isFalse);
  });

  test(
    'a failed refresh inside the grace window still authorizes a new arm',
    () async {
      // Previously this asserted the opposite. That was the documented bug:
      // a paying user whose phone lost signal could not arm at all. The window
      // is bounded and the transport truth is still reported separately.
      final fake = _FakeRevenueCatService()..nextInfo = _verifiedProInfo();
      final provider = SubscriptionProvider(revenueCatService: fake);
      addTearDown(provider.dispose);

      await provider.initialize();
      expect(provider.accessStatus, SubscriptionAccessStatus.verifiedPro);
      expect(provider.isPro, isTrue);
      expect(fake.storedProAt, isNotNull, reason: 'anchor must be persisted');
      expect(fake.hintStored, isTrue, reason: 'anchor needs corroboration');

      fake.nextInfo = null; // network/config/cache uncertainty
      final resolvedForNewArm = await provider.resolveAccess();

      // Transport failure is still reported as a transport failure...
      expect(provider.accessStatus, SubscriptionAccessStatus.unavailable);
      expect(
        provider.access.verifiedEntitlementDecision,
        EntitlementDecision.unknown,
      );
      // ...but the authorization every layer reads is now authorized, which is
      // what panic_button, CountdownScreen and the native side all require.
      expect(
        resolvedForNewArm.entitlementDecision,
        EntitlementDecision.authorized,
      );
      expect(resolvedForNewArm.canUsePaidSafetyFeature, isTrue);
      expect(provider.isPro, isTrue);
    },
  );

  test(
    'a cold start with an aged anchor still authorizes SOS (IR-04)',
    () async {
      // No in-process history at all: only what was persisted, and it is old.
      // This is the cold-start-with-no-signal case the policy exists for.
      final fake = _FakeRevenueCatService()
        ..nextInfo = null
        ..hintStored = true
        ..storedProAt = DateTime.now().subtract(
          SubscriptionAccessState.offlineGracePeriod + const Duration(days: 1),
        );
      final provider = SubscriptionProvider(revenueCatService: fake);
      addTearDown(provider.dispose);

      final resolved = await provider.resolveAccess();

      expect(resolved.entitlementDecision, EntitlementDecision.authorized);
      expect(resolved.canUsePaidSafetyFeature, isTrue);
      expect(resolved.canUseNonEmergencyPaidFeature, isFalse);
    },
  );

  test(
    'a cold start with an uncorroborated anchor does not authorize',
    () async {
      // A single forged integer in local storage must not claim a past answer.
      final fake = _FakeRevenueCatService()
        ..nextInfo = null
        ..hintStored = false
        ..storedProAt = DateTime.now().subtract(const Duration(days: 1));
      final provider = SubscriptionProvider(revenueCatService: fake);
      addTearDown(provider.dispose);

      final resolved = await provider.resolveAccess();

      expect(resolved.entitlementDecision, EntitlementDecision.unknown);
      expect(resolved.canUsePaidSafetyFeature, isFalse);
    },
  );

  test('a verified free answer erases the anchor durably', () async {
    final fake = _FakeRevenueCatService()..nextInfo = _verifiedProInfo();
    final provider = SubscriptionProvider(revenueCatService: fake);
    addTearDown(provider.dispose);

    await provider.initialize();
    expect(fake.storedProAt, isNotNull);

    fake.nextInfo = _verifiedFreeInfo();
    final resolved = await provider.resolveAccess();

    expect(resolved.entitlementDecision, EntitlementDecision.denied);
    expect(resolved.shouldShowPaywall, isTrue);
    // Erased by the time the caller sees the decision, so a process death here
    // cannot resurrect offline authorization for a lapsed subscriber.
    expect(fake.storedProAt, isNull);
    expect(fake.hintStored, isFalse);
  });
}

class _FakeRevenueCatService extends RevenueCatService {
  CustomerInfo? nextInfo;

  @override
  bool get isConfigured => false;

  @override
  Future<bool> ensureInitialized() async => true;

  @override
  Future<CustomerInfo?> getCustomerInfo() async => nextInfo;

  @override
  Future<Offerings?> getOfferings() async => null;

  @override
  Future<void> rememberVerifiedProInitializationHint() async {
    hintStored = true;
  }

  bool hintStored = false;
  DateTime? storedProAt;

  @override
  Future<bool> hasPriorProInitializationHint() async => hintStored;

  @override
  Future<DateTime?> readLastVerifiedProAt() async => storedProAt;

  @override
  Future<void> rememberVerifiedProAt(DateTime when) async {
    storedProAt = when;
  }

  @override
  Future<void> clearLastVerifiedProAt() async {
    storedProAt = null;
    hintStored = false;
  }
}

CustomerInfo _verifiedProInfo({String? requestDate}) {
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
  return CustomerInfo(
    const EntitlementInfos(
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
    requestDate ?? DateTime.now().toUtc().toIso8601String(),
  );
}

/// A trustworthy response that reports no active entitlement: the store did
/// answer, and the answer was "not subscribed".
CustomerInfo _verifiedFreeInfo() {
  return const CustomerInfo(
    EntitlementInfos({}, {}, verification: VerificationResult.verified),
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

class _OfflinePersistedService extends RevenueCatService {
  @override
  Future<bool> ensureInitialized() async => false;
}

class _DelayedEvidenceService extends _FakeRevenueCatService {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> rememberVerifiedProAt(DateTime when) async {
    started.complete();
    await release.future;
    await super.rememberVerifiedProAt(when);
  }
}
