import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCat subscription contract', () {
    late String pubspec;
    late String service;
    late String provider;
    late String paywall;

    setUp(() {
      pubspec = File('pubspec.yaml').readAsStringSync();
      service = File(
        'lib/core/services/revenue_cat_service.dart',
      ).readAsStringSync();
      provider = File(
        'lib/presentation/providers/subscription_provider.dart',
      ).readAsStringSync();
      paywall = File(
        'lib/screens/subscription/paywall_screen.dart',
      ).readAsStringSync();
    });

    test('RevenueCat SDK dependencies and entitlement are present', () {
      expect(pubspec, contains('purchases_flutter:'));
      expect(pubspec, contains('purchases_ui_flutter:'));
      expect(service, contains("entitlementId = 'KoruBeni Pro'"));
    });

    test(
      'RevenueCat service keeps configure, offerings, purchase and restore flows',
      () {
        expect(service, contains('Purchases.configure'));
        expect(service, contains('Purchases.getOfferings'));
        expect(service, contains('Purchases.purchasePackage'));
        expect(service, contains('Purchases.restorePurchases'));
      },
    );

    test(
      'provider resolves current offering and monthly/annual packages centrally',
      () {
        expect(provider, contains('Offering? get currentOffering'));
        expect(provider, contains('_offerings?.current'));
        expect(provider, contains('bool get hasCurrentOffering'));
        expect(provider, contains('bool get hasAnyPackages'));
        expect(provider, contains('Package? get monthlyPackage'));
        expect(provider, contains('currentOffering?.monthly'));
        expect(provider, contains('PackageType.monthly'));
        expect(provider, contains('Package? get annualPackage'));
        expect(provider, contains('currentOffering?.annual'));
        expect(provider, contains('PackageType.annual'));
        expect(provider, contains('bool get hasRequiredPackages'));
      },
    );

    test('custom paywall does not use RevenueCat PaywallView', () {
      expect(paywall, isNot(contains('PaywallView')));
      expect(paywall, isNot(contains('purchases_ui_flutter')));
      expect(paywall, contains('subscription.monthlyPackage'));
      expect(paywall, contains('subscription.annualPackage'));
      expect(paywall, contains('subscription.hasRequiredPackages'));
    });

    test('paywall has annual highlight, restore CTA and fail-safe state', () {
      expect(paywall, contains('subscription_plan_best_value'));
      expect(paywall, contains('subscription_restore_title'));
      expect(paywall, contains('subscription_plans_unavailable_title'));
      expect(paywall, contains('subscription_plans_unavailable_body'));
      expect(paywall, contains('refreshOfferings'));
    });

    test('user-facing subscription errors are sanitized translation keys', () {
      expect(provider, contains("'subscription_error_entitlement'"));
      expect(provider, contains("'subscription_error_purchase'"));
      expect(provider, contains("'subscription_error_restore'"));
      expect(provider, contains("'subscription_error_offline'"));
      expect(provider, contains("'subscription_error_no_offering'"));
      expect(provider, contains("'subscription_error_no_packages'"));
      expect(provider, contains("'subscription_error_packages_unavailable'"));
      expect(provider, isNot(contains('e.message')));
      expect(paywall, isNot(contains('PlatformException')));
      expect(paywall, isNot(contains('RevenueCatPurchaseException')));
    });

    test('billing docs keep every external purchase flow as not run', () {
      final billing = File(
        'store/BILLING_RELEASE_CHECKLIST.md',
      ).readAsStringSync();

      for (final item in [
        'Google Play app created',
        'Signed AAB uploaded',
        'License tester account added',
        'Test device uses the intended Google account',
        'RevenueCat Android app configured',
        'RevenueCat service credentials configured',
        'Current offering active',
        'Monthly package mapped',
        'Annual package mapped',
        'Monthly purchase tested with license tester',
        'Annual purchase tested with license tester',
        'Restore active purchase tested',
        'Restore with no active purchase tested',
        'Cancel/manage subscription tested',
        'Expired/lapsed entitlement tested',
        'Renewal/lapse behavior tested in sandbox',
        'Account hold/paused tested if available',
        'No-offering fallback tested',
        'Network failure fallback tested',
      ]) {
        expect(billing, contains(item), reason: item);
      }
      expect(billing, contains('REVENUECAT'));
      expect(billing, isNot(contains('| PASS |')));
    });
  });
}
