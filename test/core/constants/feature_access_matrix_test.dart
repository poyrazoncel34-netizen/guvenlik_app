import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/constants/feature_access_matrix.dart';

void main() {
  group('FeatureAccessMatrix', () {
    test('panic remains Pro-only', () {
      expect(FeatureAccessMatrix.isProFeature(PremiumFeature.panic), isTrue);
      expect(
        FeatureAccessMatrix.freeFeatures,
        isNot(contains(PremiumFeature.panic)),
      );
    });

    test('paywall benefit keys do not sell free contact or siren features', () {
      expect(
        FeatureAccessMatrix.proBenefitKeys,
        isNot(contains('subscription_value_contacts')),
      );
      expect(
        FeatureAccessMatrix.proBenefitKeys.join('\n').toLowerCase(),
        isNot(contains('siren')),
      );
    });
  });
}
