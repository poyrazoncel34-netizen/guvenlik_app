// ============================================================================
// SORUMLULUK REDDİ EKRANI — İlk kurulumda bir kez gösterilir
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import 'onboarding_screen.dart';

class LegalDisclaimerScreen extends StatefulWidget {
  const LegalDisclaimerScreen({super.key});

  @override
  State<LegalDisclaimerScreen> createState() => _LegalDisclaimerScreenState();
}

class _LegalDisclaimerScreenState extends State<LegalDisclaimerScreen> {
  bool _accepted = false;
  bool _kvkkAccepted = false;
  bool _saving = false;

  // Şartlar değiştiğinde bu versiyonu artırın; kullanıcıdan tekrar onay alınır.
  static const String _currentTermsVersion = '1.1';

  static const String _disclaimerText =
      'KORUBENİ - YASAL UYARI VE KULLANIM ŞARTLARI\n\n'
      '1. Acil Servis Değildir\n'
      'KoruBeni bir yardımcı güvenlik aracıdır. Resmi acil servisler (112, polis, itfaiye) '
      'veya profesyonel güvenlik hizmetlerinin yerini tutmaz ve tutamaz. '
      'Gerçek bir acil durumda her zaman önce resmi acil servisleri arayın.\n\n'
      '2. Çalışma Garantisi Yoktur\n'
      'Uygulama; internet bağlantısı kesintileri, cihaz arızaları, pil bitmesi, '
      'işletim sistemi kısıtlamaları veya kullanıcı hatası gibi nedenlerle beklendiği '
      'gibi çalışmayabilir. Geliştirici, uygulamanın her koşulda kesintisiz çalışacağını '
      'garanti etmez.\n\n'
      '3. Sorumluluk Reddi\n'
      'Uygulamanın çalışmaması, geç çalışması veya hatalı çalışması sonucunda doğabilecek '
      'hiçbir can kaybı, yaralanma, mal kaybı veya başka bir zarardan geliştirici '
      'hukuki veya cezai olarak sorumlu tutulamaz.\n\n'
      '4. Kullanıcı Sorumluluğu\n'
      'Bu uygulamayı kullanmak tamamen sizin tercihinizdedir. Yukarıdaki riskleri '
      'anlıyor ve kabul ediyor olarak uygulamayı kullanıyorsunuz. '
      'Kullanım riski tamamen size aittir.\n\n'
      '5. Mücbir Sebep (Force Majeure)\n'
      'Türk Borçlar Kanunu Madde 136 kapsamında; deprem, sel, elektrik kesintisi, '
      'şebeke arızası, işletim sistemi güncellemesi gibi öngörülemeyen ve önlenemeyen '
      'durumlarda uygulamanın çalışmamasından doğan zararlar için geliştirici '
      'sorumlu tutulamaz.\n\n'
      '6. Yasal Çerçeve\n'
      'Bu kullanım koşulları Türk Hukuku\'na tabidir. Taraflar arasında doğabilecek '
      'anlaşmazlıklarda İstanbul Mahkemeleri ve İcra Daireleri yetkilidir.';

  Future<void> _onAccept() async {
    if (!_accepted || !_kvkkAccepted || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefLegalDisclaimerAccepted, true);
    await prefs.setBool(AppConstants.prefKvkkHealthConsentAccepted, true);
    await prefs.setString(AppConstants.prefTermsVersion, _currentTermsVersion);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                const Icon(
                  Icons.gavel_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Yasal Uyarı ve Kullanım Şartları',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Scrollable disclaimer text ──
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _disclaimerText,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Checkbox 1: Genel sorumluluk reddi ──
                GestureDetector(
                  onTap: () => setState(() => _accepted = !_accepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _accepted,
                        onChanged: (v) =>
                            setState(() => _accepted = v ?? false),
                        activeColor: AppColors.primary,
                        side: BorderSide(
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Okudum, anladım ve tüm riskleri kabul ediyorum.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // ── Checkbox 2: KVKK açık rıza ──
                GestureDetector(
                  onTap: () =>
                      setState(() => _kvkkAccepted = !_kvkkAccepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _kvkkAccepted,
                        onChanged: (v) =>
                            setState(() => _kvkkAccepted = v ?? false),
                        activeColor: AppColors.primary,
                        side: BorderSide(
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Sağlık verilerimin (kan grubu, alerji) ve biyometrik verimim '
                            'yalnızca cihazımda işlenmesine KVKK Madde 6 kapsamında açıkça '
                            'rıza gösteriyorum.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Button — disabled until checkbox is checked ──
                AnimatedOpacity(
                  opacity: (_accepted && _kvkkAccepted) ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_accepted && _kvkkAccepted) ? _onAccept : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Devam Et',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
