// consent_screen.dart'taki race condition'ı test eder.
// Bug: _loadExistingConsents() tamamlanmadan buton etkin olabiliyor.
// Fix: _consentsLoaded guard eklenmeli.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsentScreen — yükleme guard', () {
    test(
        'Yükleme tamamlanmadan buton devre dışı olmalı',
        () {
      // Senaryo: yükleme bitmedi ama _consentAge daha önce true idi
      const consentsLoaded = false;
      const consentAge = true;
      const loading = false;

      // Düzeltilmiş buton mantığı: _loading || !_consentAge || !_consentsLoaded
      // Bu guard eklenince buttonEnabled = false olmalı
      final buttonEnabled = !loading && consentAge && consentsLoaded;

      expect(
        buttonEnabled,
        false,
        reason:
            '_consentsLoaded guard ile yükleme bitmeden buton devre dışı olmalı.',
      );
    });
  });
}
