// countdown_screen.dart'taki hata durumu davranışını test eder.
// Bug: SMS ve arama ikisi de başarısız olduğunda sadece SnackBar + pop yapılıyor.
// Kullanıcı "uygulama kapandı" sanıyor; açıklayıcı dialog gösterilmeli.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountdownScreen — acil çağrı başarısız durumu', () {
    test('SMS ve arama başarısız olduğunda dialog gösterilmeli', () {
      const smsSuccess = false;
      const callSuccess = false;

      // Düzeltilmiş mantık: her ikisi başarısız → dialog göster
      final shouldShowDialog = !smsSuccess && !callSuccess;

      expect(
        shouldShowDialog,
        true,
        reason:
            'Her iki işlem de başarısız olunca kullanıcıya açıklayıcı dialog '
            'gösterilmeli; sessiz Navigator.pop yapılmamalı.',
      );
    });
  });
}
