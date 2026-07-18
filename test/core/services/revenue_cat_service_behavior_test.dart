import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/constants/legal_texts.dart';
import 'package:guvenlik_app/core/constants/app_constants.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/revenue_cat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RevenueCat trusted entitlement evaluation', () {
    final service = RevenueCatService();

    test('verified active Pro is authorized', () {
      expect(
        service.evaluateEntitlement(
          _customerInfo(
            verification: VerificationResult.verified,
            entitlementVerification: VerificationResult.verified,
            hasEntitlement: true,
            active: true,
          ),
        ),
        EntitlementDecision.authorized,
      );
    });

    test('verified-on-device active Pro is authorized', () {
      expect(
        service.evaluateEntitlement(
          _customerInfo(
            verification: VerificationResult.verifiedOnDevice,
            entitlementVerification: VerificationResult.verifiedOnDevice,
            hasEntitlement: true,
            active: true,
          ),
        ),
        EntitlementDecision.authorized,
      );
    });

    test('verified inactive or absent Pro is denied', () {
      final inactive = _customerInfo(
        verification: VerificationResult.verified,
        entitlementVerification: VerificationResult.verified,
        hasEntitlement: true,
        active: false,
      );
      final absent = _customerInfo(
        verification: VerificationResult.verified,
        entitlementVerification: VerificationResult.verified,
        hasEntitlement: false,
        active: false,
      );

      expect(service.evaluateEntitlement(inactive), EntitlementDecision.denied);
      expect(service.evaluateEntitlement(absent), EntitlementDecision.denied);
    });

    test(
      'failed or not-requested verification is unknown even when active',
      () {
        for (final verification in [
          VerificationResult.failed,
          VerificationResult.notRequested,
        ]) {
          expect(
            service.evaluateEntitlement(
              _customerInfo(
                verification: verification,
                entitlementVerification: verification,
                hasEntitlement: true,
                active: true,
              ),
            ),
            EntitlementDecision.unknown,
            reason: verification.name,
          );
        }
      },
    );

    test('untrusted target cannot hide inside a verified response', () {
      expect(
        service.evaluateEntitlement(
          _customerInfo(
            verification: VerificationResult.verified,
            entitlementVerification: VerificationResult.failed,
            hasEntitlement: true,
            active: true,
          ),
        ),
        EntitlementDecision.unknown,
      );
    });

    test('inconsistent active/all maps fail closed as unknown', () {
      final activeButMissingFromActiveMap = _customerInfo(
        verification: VerificationResult.verified,
        entitlementVerification: VerificationResult.verified,
        hasEntitlement: true,
        active: true,
        includeInActiveMap: false,
      );

      expect(
        service.evaluateEntitlement(activeButMissingFromActiveMap),
        EntitlementDecision.unknown,
      );
    });
  });

  group('RevenueCat legal and initialization hints', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'requires acceptance of both current legal document versions',
      () async {
        final service = RevenueCatService();
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool(AppConstants.prefLegalDisclaimerAccepted, true);
        await prefs.setString(
          AppConstants.prefTermsVersion,
          LegalTexts.termsVersion,
        );
        expect(await service.hasCurrentLegalAcceptance(), isFalse);

        await prefs.setString(
          AppConstants.prefKvkkVersion,
          LegalTexts.kvkkVersion,
        );
        expect(await service.hasCurrentLegalAcceptance(), isTrue);

        await prefs.setString(AppConstants.prefTermsVersion, 'stale-version');
        expect(await service.hasCurrentLegalAcceptance(), isFalse);
      },
    );

    test(
      'prior-Pro hint is absent by default and persists only as a hint',
      () async {
        final service = RevenueCatService();

        expect(await service.hasPriorProInitializationHint(), isFalse);
        await service.rememberVerifiedProInitializationHint();
        expect(await service.hasPriorProInitializationHint(), isTrue);

        // The hint does not manufacture a CustomerInfo or entitlement decision.
        expect(service.evaluateEntitlement(null), EntitlementDecision.unknown);
      },
    );
  });
}

CustomerInfo _customerInfo({
  required VerificationResult verification,
  required VerificationResult entitlementVerification,
  required bool hasEntitlement,
  required bool active,
  bool? includeInActiveMap,
}) {
  final entitlement = EntitlementInfo(
    RevenueCatService.entitlementId,
    active,
    false,
    '2026-07-18T00:00:00Z',
    '2026-07-18T00:00:00Z',
    'korubeni_pro_monthly',
    false,
    verification: entitlementVerification,
  );
  final all = hasEntitlement
      ? <String, EntitlementInfo>{RevenueCatService.entitlementId: entitlement}
      : <String, EntitlementInfo>{};
  final activeEntitlements = hasEntitlement && (includeInActiveMap ?? active)
      ? <String, EntitlementInfo>{RevenueCatService.entitlementId: entitlement}
      : <String, EntitlementInfo>{};

  return CustomerInfo(
    EntitlementInfos(all, activeEntitlements, verification: verification),
    const {},
    const [],
    const [],
    const [],
    '2026-07-18T00:00:00Z',
    'anonymous',
    const {},
    '2026-07-18T00:00:00Z',
  );
}
