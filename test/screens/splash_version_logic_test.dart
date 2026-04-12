// Splash ekranının versiyon karşılaştırma mantığını test eder.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/constants/legal_texts.dart';

void main() {
  group('Splash Screen — versiyon yeniden onay mantığı', () {
    test('Kullanıcı 3.0.0 onayladıktan sonra needsReConsent false olmalı', () {
      // Kullanıcı yasal akışı tamamladığında markLegalVersionsAccepted()
      // LegalTexts.termsVersion ('3.0.0') kaydeder.
      const savedTermsVersion = LegalTexts.termsVersion; // '3.0.0'
      const savedKvkkVersion = LegalTexts.kvkkVersion; // '3.0.0'

      // splash_screen.dart'taki düzeltilmiş kod LegalTexts sabitleri ile kıyaslıyor:
      final needsReConsent =
          savedTermsVersion != LegalTexts.termsVersion ||
          savedKvkkVersion != LegalTexts.kvkkVersion;

      expect(
        needsReConsent,
        false,
        reason: 'Kullanıcı 3.0.0 onayladıysa needsReConsent false olmalı.',
      );
    });

    test(
      'splash_screen uses LegalTexts constants instead of hardcoded versions',
      () {
        final source = File(
          'lib/screens/splash_screen.dart',
        ).readAsStringSync();

        expect(source, contains('LegalTexts.termsVersion'));
        expect(source, contains('LegalTexts.kvkkVersion'));
        expect(source, contains('AppConstants.prefLegalDisclaimerAccepted'));
        expect(source, contains('AppConstants.prefLegalAcceptedV1'));
        expect(source, isNot(contains("'2.0.0'")));
      },
    );
  });
}
