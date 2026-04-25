// ============================================================================
// İLK AÇILIŞ ONAY EKRANI — KVKK Kurul Kararı 2018/90 uyumlu
// Aydınlatma ve açık rıza AYRI AYRI alınır. 3 checkbox zorunlu.
// TBK Md. 20 — Genel işlem koşulları karşı tarafın onayı olmadan geçerli olmaz.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/legal_log_service.dart';
import 'onboarding_screen.dart';

class LegalDisclaimerScreen extends StatefulWidget {
  const LegalDisclaimerScreen({super.key});

  @override
  State<LegalDisclaimerScreen> createState() => _LegalDisclaimerScreenState();
}

class _LegalDisclaimerScreenState extends State<LegalDisclaimerScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _emergencyAccepted = false;
  bool _ageAccepted = false;
  bool _liabilityAccepted = false;
  bool _saving = false;

  bool get _allAccepted =>
      _termsAccepted &&
      _privacyAccepted &&
      _emergencyAccepted &&
      _ageAccepted &&
      _liabilityAccepted;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _onAccept() async {
    if (!_allAccepted || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    await prefs.setBool(AppConstants.prefLegalAcceptedV1, true);
    await prefs.setString(
      AppConstants.prefLegalTimestamp,
      DateTime.now().toIso8601String(),
    );
    await prefs.setString(
      AppConstants.prefLegalAppVersion,
      packageInfo.version,
    );
    // Geriye dönük uyumluluk (eski splash_screen kontrolü için)
    await prefs.setBool(AppConstants.prefLegalDisclaimerAccepted, true);

    await LegalLogService.instance.logEvent(
      'terms_accepted',
      checkboxes: [
        'terms',
        'privacy',
        'emergency_disclaimer',
        'age_confirmation',
        'liability_acceptance',
      ],
    );

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
    return PopScope(
      canPop: false,
      child: Scaffold(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──
                  const Icon(
                    Icons.shield_outlined,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'KoruBeni',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kişisel Güvenlik Uygulaması',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Kırmızı uyarı kutusu ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE53E3E)),
                    ),
                    child: const Text(
                      '⚠️ Bu uygulama 112 ve diğer resmi acil servislerin YERİNİ TUTMAZ. '
                      'İnternet kesintisi, GPS hatası veya teknik arızalar nedeniyle çalışmayabilir.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF742A2A),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Checkbox 1: Kullanım Şartları ──
                  _buildCheckboxTile(
                    value: _termsAccepted,
                    onChanged: (v) =>
                        setState(() => _termsAccepted = v ?? false),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Uygulamanın '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () =>
                                  _launchUrl(AppConstants.termsOfServiceUrl),
                              child: const Text(
                                'Kullanım Şartları',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: "'nı okudum ve kabul ediyorum."),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Checkbox 2: Gizlilik + Aydınlatma Metni ──
                  _buildCheckboxTile(
                    value: _privacyAccepted,
                    onChanged: (v) =>
                        setState(() => _privacyAccepted = v ?? false),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () =>
                                  _launchUrl(AppConstants.privacyPolicyWebUrl),
                              child: const Text(
                                'Gizlilik Politikası',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: "'nı ve "),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () =>
                                  _launchUrl(AppConstants.aydinlatmaMetniUrl),
                              child: const Text(
                                'KVKK Aydınlatma Metni',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: "'ni okudum."),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Checkbox 3: Acil servis uyarısı ──
                  _buildCheckboxTile(
                    value: _emergencyAccepted,
                    onChanged: (v) =>
                        setState(() => _emergencyAccepted = v ?? false),
                    child: const Text(
                      'Bu uygulamanın teknik sınırlarını anlıyorum. '
                      'Gerçek acil durumda önce 112\'yi arayacağımı kabul ediyorum.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Checkbox 4: Yaş onayı ──
                  _buildCheckboxTile(
                    value: _ageAccepted,
                    onChanged: (v) => setState(() => _ageAccepted = v ?? false),
                    child: const Text(
                      '18 yaşından büyük olduğumu beyan ederim.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Checkbox 5: Sorumluluk kabulü ──
                  _buildCheckboxTile(
                    value: _liabilityAccepted,
                    onChanged: (v) =>
                        setState(() => _liabilityAccepted = v ?? false),
                    child: const Text(
                      'Uygulama özelliklerinin kötüye kullanımından doğan '
                      'tüm hukuki, cezai ve mali sorumluluğun bana ait '
                      'olduğunu kabul ediyorum.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Devam Et butonu ──
                  AnimatedOpacity(
                    opacity: _allAccepted ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _allAccepted ? _onAccept : null,
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
