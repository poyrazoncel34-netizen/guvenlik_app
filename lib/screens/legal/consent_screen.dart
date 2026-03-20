// ============================================================================
// GRANÜLER RIZA EKRANI
// Her veri işleme faaliyeti için ayrı checkbox — KVKK açık rıza gereklilikleri
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/consent_manager.dart';
import '../../models/consent_record.dart';
import '../../core/di/service_locator.dart';
import '../../widgets/consent_checkbox_widget.dart';

class ConsentScreen extends StatefulWidget {
  final VoidCallback? onCompleted;
  /// Re-consent modunda önceki rızalar gösterilir
  final bool isReConsent;

  const ConsentScreen({
    super.key,
    this.onCompleted,
    this.isReConsent = false,
  });

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _consentLocation = false;
  bool _consentBiometric = false;
  bool _consentAudio = false;
  bool _consentEmergencyContacts = false;
  bool _consentProfile = false;
  bool _consentFakeCall = false;
  bool _loading = false;

  // Zorunlu rızalar: konum ve acil kişiler temel işlevsellik için gerekli
  // (Bununla birlikte KVKK, rızanın özgür iradeyle verilmesini şart koşar —
  //  reddetme halinde yalnızca ilgili özellik devre dışı kalır)

  @override
  void initState() {
    super.initState();
    _loadExistingConsents();
  }

  Future<void> _loadExistingConsents() async {
    final cm = serviceLocator<ConsentManager>();
    setState(() {
      _consentLocation = cm.isGranted(ConsentRecord.typeLocation);
      _consentBiometric = cm.isGranted(ConsentRecord.typeBiometric);
      _consentAudio = cm.isGranted(ConsentRecord.typeAudio);
      _consentEmergencyContacts =
          cm.isGranted(ConsentRecord.typeEmergencyContacts);
      _consentProfile = cm.isGranted(ConsentRecord.typeProfile);
      _consentFakeCall = cm.isGranted(ConsentRecord.typeFakeCall);
    });
  }

  Future<void> _saveConsents() async {
    if (_loading) return;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    try {
      final cm = serviceLocator<ConsentManager>();
      final locale = context.locale.languageCode;
      final prefs = await SharedPreferences.getInstance();

      Future<void> record(String type, bool granted) async {
        if (granted) {
          await cm.grantConsent(type, locale: locale);
        } else {
          await cm.revokeConsent(type, locale: locale);
        }
      }

      await record(ConsentRecord.typeLocation, _consentLocation);
      await record(ConsentRecord.typeBiometric, _consentBiometric);
      await record(ConsentRecord.typeAudio, _consentAudio);
      await record(ConsentRecord.typeEmergencyContacts, _consentEmergencyContacts);
      await record(ConsentRecord.typeProfile, _consentProfile);
      await record(ConsentRecord.typeFakeCall, _consentFakeCall);

      // SharedPrefs önbelleği güncelle (özellik durumu için)
      await prefs.setBool(AppConstants.prefConsentLocation, _consentLocation);
      await prefs.setBool(AppConstants.prefConsentBiometric, _consentBiometric);
      await prefs.setBool(AppConstants.prefConsentAudio, _consentAudio);
      await prefs.setBool(AppConstants.prefConsentEmergencyContacts,
          _consentEmergencyContacts);
      await prefs.setBool(AppConstants.prefConsentProfile, _consentProfile);

      if (mounted) widget.onCompleted?.call();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'legal_consent_title'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        automaticallyImplyLeading: widget.isReConsent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // Bilgi banner'ı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.info.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'legal_consent_info'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'legal_consent_subtitle'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Konum
                  ConsentCheckboxWidget(
                    label: 'legal_consent_location'.tr(),
                    sublabel: 'legal_consent_location_sub'.tr(),
                    value: _consentLocation,
                    onChanged: (v) =>
                        setState(() => _consentLocation = v ?? false),
                  ),

                  // Acil durum kişileri
                  ConsentCheckboxWidget(
                    label: 'legal_consent_emergency_contacts'.tr(),
                    sublabel:
                        'legal_consent_emergency_contacts_sub'.tr(),
                    value: _consentEmergencyContacts,
                    onChanged: (v) =>
                        setState(() => _consentEmergencyContacts = v ?? false),
                  ),

                  // Profil
                  ConsentCheckboxWidget(
                    label: 'legal_consent_profile'.tr(),
                    sublabel: 'legal_consent_profile_sub'.tr(),
                    value: _consentProfile,
                    onChanged: (v) =>
                        setState(() => _consentProfile = v ?? false),
                  ),

                  // Ses kaydı
                  ConsentCheckboxWidget(
                    label: 'legal_consent_audio'.tr(),
                    sublabel: 'legal_consent_audio_sub'.tr(),
                    value: _consentAudio,
                    onChanged: (v) =>
                        setState(() => _consentAudio = v ?? false),
                  ),

                  // Sahte çağrı
                  ConsentCheckboxWidget(
                    label: 'legal_consent_fake_call'.tr(),
                    sublabel: 'legal_consent_fake_call_sub'.tr(),
                    value: _consentFakeCall,
                    onChanged: (v) =>
                        setState(() => _consentFakeCall = v ?? false),
                  ),

                  // Biyometrik (özel nitelikli)
                  ConsentCheckboxWidget(
                    label: 'legal_consent_biometric'.tr(),
                    sublabel: 'legal_consent_biometric_sub'.tr(),
                    value: _consentBiometric,
                    onChanged: (v) =>
                        setState(() => _consentBiometric = v ?? false),
                    isSpecialCategory: true,
                  ),

                  const SizedBox(height: 16),

                  // Reddetme notu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'legal_consent_rejection_note'.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Kaydet butonu
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveConsents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isReConsent
                            ? 'legal_consent_save'.tr()
                            : 'legal_consent_complete'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
