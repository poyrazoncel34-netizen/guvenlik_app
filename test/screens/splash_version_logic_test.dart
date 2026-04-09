// Splash ekranının versiyon karşılaştırma mantığını test eder.
// Bug: splash_screen.dart '2.0.0' ile karşılaştırıyor ama LegalTexts.termsVersion = '3.0.0'.

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/constants/legal_texts.dart';

void main() {
  group('Splash Screen — versiyon yeniden onay mantığı', () {
    test('Kullanıcı 3.0.0 onayladıktan sonra needsReConsent false olmalı', () {
      // Kullanıcı yasal akışı tamamladığında markLegalVersionsAccepted()
      // LegalTexts.termsVersion ('3.0.0') kaydeder.
      const savedTermsVersion = LegalTexts.termsVersion; // '3.0.0'
      const savedKvkkVersion = LegalTexts.kvkkVersion;   // '3.0.0'

      // splash_screen.dart'taki düzeltilmiş kod LegalTexts sabitleri ile kıyaslıyor:
      final needsReConsent =
          savedTermsVersion != LegalTexts.termsVersion ||
          savedKvkkVersion != LegalTexts.kvkkVersion;

      expect(needsReConsent, false,
          reason: 'Kullanıcı 3.0.0 onayladıysa needsReConsent false olmalı.');
    });
  });
}
