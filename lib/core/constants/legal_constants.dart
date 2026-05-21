// ============================================================================
// LEGAL CONSTANTS — Yasal metin versiyonları
// ============================================================================
// Bu versiyonlar değiştiğinde uygulama kullanıcıyı tekrar onay akışına yönlendirir.

class LegalConstants {
  LegalConstants._();

  /// Kullanım Sözleşmesi (EULA) versiyonu
  static const String termsVersion = '3.1.0';

  /// KVKK Aydınlatma Metni versiyonu
  static const String kvkkDisclosureVersion = '3.1.1';

  /// Rıza Formu versiyonu
  static const String consentFormVersion = '3.1.1';

  /// Gizlilik Politikası versiyonu
  static const String privacyPolicyVersion = '3.1.1';

  /// Son güncelleme tarihi
  static const String lastUpdated = '2026-05-21';

  /// Veri Sorumlusu bilgileri
  static const String dataControllerName = 'KoruBeni';
  static const String dataControllerTitle = 'KoruBeni';
  static const String dataControllerCity = 'İzmir';
  static const String dataControllerEmail = 'korubeni.destek@gmail.com';

  /// Yetkili mahkeme
  static const String jurisdictionCourt = 'İzmir Mahkemeleri ve İcra Daireleri';

  /// KVKK başvuru yanıt süresi (gün)
  static const int kvkkResponseDays = 30;
}
