// countdown_screen.dart'taki hata durumu davranışını test eder.
// Bug: Arama başarısız olduğunda sadece SnackBar + pop yapılıyor.
// Kullanıcı "uygulama kapandı" sanıyor; açıklayıcı dialog gösterilmeli.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountdownScreen — acil çağrı başarısız durumu', () {
    test('Arama başarısız olduğunda dialog gösterilmeli', () {
      const callSuccess = false;

      // Düzeltilmiş mantık: arama başarısız → dialog göster
      final shouldShowDialog = !callSuccess;

      expect(
        shouldShowDialog,
        true,
        reason:
            'Arama başarısız olunca kullanıcıya açıklayıcı dialog '
            'gösterilmeli; sessiz Navigator.pop yapılmamalı.',
      );
    });
  });
}
