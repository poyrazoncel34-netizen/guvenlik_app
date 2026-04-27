import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Paywall compliance source contract', () {
    late String paywall;
    late String tr;
    late String en;

    setUp(() {
      paywall = File(
        'lib/screens/subscription/paywall_screen.dart',
      ).readAsStringSync();
      tr = File('assets/translations/tr-TR.json').readAsStringSync();
      en = File('assets/translations/en-US.json').readAsStringSync();
    });

    test('shows price, period, disclosure, legal links and restore action', () {
      expect(paywall, contains('package.storeProduct.priceString'));
      expect(paywall, contains('_periodText(package)'));
      expect(paywall, contains('subscription_renewal_disclosure'));
      expect(paywall, contains('legal_link_privacy'));
      expect(paywall, contains('legal_link_terms'));
      expect(paywall, contains('_buildRestoreButton'));
    });

    test('uses feature matrix benefit keys', () {
      expect(paywall, contains('FeatureAccessMatrix.proBenefitKeys'));
      expect(paywall, isNot(contains("'subscription_value_contacts'")));
    });

    test('Turkish auto-renewal disclosure is present', () {
      expect(tr, contains('Abonelik dönem sonunda otomatik olarak yenilenir.'));
      expect(tr, contains('Google Play > Abonelikler'));
    });

    test('empty priceString uses localized unavailable fallback', () {
      expect(paywall, contains('package.storeProduct.priceString.trim()'));
      expect(paywall, contains('subscription_price_unavailable'));
      expect(
        tr,
        contains('"subscription_price_unavailable": "Fiyat alınamadı"'),
      );
      expect(
        en,
        contains('"subscription_price_unavailable": "Price unavailable"'),
      );
    });
  });
}
