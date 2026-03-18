// ============================================================================
// YASAL METİN VERSİYON KONTROLÜ
// Uygulama açılışında sürüm değişikliği varsa re-consent akışını tetikler.
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import '../constants/legal_texts.dart';

class LegalVersionChecker {
  /// Kaydedilmiş versiyonları mevcut versiyonlarla karşılaştırır.
  /// true → yeniden onay gerekiyor
  static Future<bool> needsReConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final legalAccepted =
        prefs.getBool('pref_legal_disclaimer_accepted') ?? false;
    if (!legalAccepted) return true;

    final savedTerms = prefs.getString('pref_terms_version') ?? '';
    final savedKvkk = prefs.getString('pref_kvkk_version') ?? '';

    return savedTerms != LegalTexts.termsVersion ||
        savedKvkk != LegalTexts.kvkkVersion;
  }

  /// Onboarding tamamlandı mı?
  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pref_onboarding_done') ?? false;
  }

  /// Legal akış tamamlandı mı (ilk kurulum veya re-consent olmadan)?
  static Future<bool> isLegalFlowComplete() async {
    final needsConsent = await needsReConsent();
    return !needsConsent;
  }
}
