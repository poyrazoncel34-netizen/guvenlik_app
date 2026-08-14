// ============================================================================
// BİRLEŞİK ONAY EKRANI — Tek ekranlı yasal akış
// Yaş Doğrulama + EULA + KVKK + Granüler Rıza
// ============================================================================

import '../../core/design_tokens.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/motion.dart';
import '../../core/constants/app_constants.dart';
import '../../constants/legal_texts.dart';
import '../../services/consent_manager.dart';
import '../../models/consent_record.dart';
import '../../core/di/service_locator.dart';
import '../../widgets/consent_checkbox_widget.dart';
import '../onboarding_screen.dart';

class UnifiedConsentScreen extends StatefulWidget {
  const UnifiedConsentScreen({super.key, this.onAccepted});

  /// Advances the [AppRoot] shell instead of replacing the route. Replacing it
  /// destroys the Navigator's initial route, which is what made Android state
  /// restoration impossible -- see lib/screens/app_root.dart.
  ///
  /// Null keeps the historical route replacement, so this screen still works
  /// when it is pushed on its own.
  final VoidCallback? onAccepted;

  @override
  State<UnifiedConsentScreen> createState() => _UnifiedConsentScreenState();
}

class _UnifiedConsentScreenState extends State<UnifiedConsentScreen> {
  int? _selectedAgeOption; // 0 = 18+

  bool _isEulaAccepted = false;
  bool _isKvkkAcknowledged = false;

  bool _consentLocation = false;
  bool _consentEmergencyContacts = false;
  bool _consentProfile = false;
  bool _consentFakeCall = false;

  bool _eulaExpanded = false;
  bool _kvkkExpanded = false;

  bool _loading = false;

  bool get _canProceed =>
      _selectedAgeOption != null && _isEulaAccepted && _isKvkkAcknowledged;

  bool get _isTurkish => context.locale.languageCode == 'tr';

  Future<void> _complete() async {
    if (!_canProceed || _loading) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _loading = true);

    try {
      final cm = serviceLocator<ConsentManager>();
      final locale = context.locale.languageCode;
      final prefs = await SharedPreferences.getInstance();

      await cm.grantConsent('age_verification', locale: locale);
      await prefs.setBool(AppConstants.prefAgeVerified, true);

      await cm.grantConsent(ConsentRecord.typeTerms, locale: locale);
      await cm.grantConsent(ConsentRecord.typeKvkk, locale: locale);

      Future<void> recordOptional(String type, bool granted) async {
        if (granted) {
          await cm.grantConsent(type, locale: locale);
        } else {
          await cm.revokeConsent(type, locale: locale);
        }
      }

      await recordOptional(ConsentRecord.typeLocation, _consentLocation);
      await recordOptional(
        ConsentRecord.typeEmergencyContacts,
        _consentEmergencyContacts,
      );
      await recordOptional(ConsentRecord.typeProfile, _consentProfile);
      await recordOptional(ConsentRecord.typeFakeCall, _consentFakeCall);

      await prefs.setBool(AppConstants.prefConsentLocation, _consentLocation);
      await prefs.setBool(
        AppConstants.prefConsentEmergencyContacts,
        _consentEmergencyContacts,
      );
      await prefs.setBool(AppConstants.prefConsentProfile, _consentProfile);

      await cm.markLegalVersionsAccepted();

      if (!mounted) return;

      final onAccepted = widget.onAccepted;
      if (onAccepted != null) {
        onAccepted();
      } else {
        unawaited(
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, _) => const OnboardingScreen(),
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: Motion.slow,
            ),
          ),
        );
      }
    } on Exception catch (_) {
      if (mounted) setState(() => _loading = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildAgeSection(),
                    const SizedBox(height: 16),
                    _buildEulaSection(),
                    const SizedBox(height: 16),
                    _buildKvkkSection(),
                    const SizedBox(height: 24),
                    _buildOptionalConsents(),
                    const SizedBox(height: 16),
                    _buildRejectionNote(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_rounded, size: IconSizes.illustration, color: AppColors.primary),
        const SizedBox(height: 12),
        // Screen heading (MP-12-017).
        Semantics(
          header: true,
          child: Text(
            'legal_unified_title'.tr(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'legal_unified_subtitle'.tr(),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          icon: Icons.verified_user_outlined,
          label: 'legal_age_title'.tr(),
          required: true,
        ),
        const SizedBox(height: 12),
        _buildAgeOption(
          index: 0,
          icon: Icons.person_outline_rounded,
          label: 'legal_age_adult'.tr(),
          sublabel: 'legal_age_adult_sub'.tr(),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'legal_age_notice'.tr(),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgeOption({
    required int index,
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    final isSelected = _selectedAgeOption == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedAgeOption = index);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEulaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          icon: Icons.description_outlined,
          label: 'legal_tos_title'.tr(),
          required: true,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                // MEASURED OVERFLOW. On an API 36 emulator at `wm density 560`
                // with `font_scale 2.0`, this Row logged "A RenderFlex
                // overflowed by 82 pixels on the right" and the version string
                // ran off the card. Neither setting alone reproduces it, which
                // is why a density-only sweep and a text-scale-only sweep both
                // missed it -- the two multiply.
                //
                // The version line is legal provenance ("which text did I
                // accept?"), so it must stay readable rather than be clipped
                // or ellipsised: Expanded lets it wrap onto a second line.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: IconSizes.inline,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${'legal_version_prefix'.tr()} ${LegalTexts.termsVersion} — ${LegalTexts.lastUpdated}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_eulaExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: SelectableText(
                    _isTurkish
                        ? LegalTexts.termsOfServiceTr
                        : LegalTexts.termsOfServiceEn,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _eulaExpanded = !_eulaExpanded),
                icon: Icon(
                  _eulaExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: IconSizes.listItem,
                  color: AppColors.primary,
                ),
                label: Text(
                  _eulaExpanded ? 'legal_collapse'.tr() : 'legal_expand'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ConsentCheckboxWidget(
          label: 'legal_tos_accept_label'.tr(),
          value: _isEulaAccepted,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            setState(() => _isEulaAccepted = v ?? false);
          },
        ),
      ],
    );
  }

  Widget _buildKvkkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          icon: Icons.verified_user_rounded,
          label: 'legal_kvkk_title'.tr(),
          required: true,
          color: AppColors.accent,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: IconSizes.inline,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${'legal_kvkk_madde10'.tr()} — ${LegalTexts.kvkkVersion} — ${LegalTexts.lastUpdatedKvkk}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'legal_data_controller'.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _dataRow(
                      'legal_data_controller'.tr(),
                      AppConstants.appName,
                    ),
                    _dataRow(
                      'legal_dc_contact'.tr(),
                      AppConstants.supportEmail,
                    ),
                  ],
                ),
              ),
              if (_kvkkExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: SelectableText(
                    _isTurkish
                        ? LegalTexts.kvkkDisclosureTr
                        : LegalTexts.kvkkDisclosureEn,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _kvkkExpanded = !_kvkkExpanded),
                icon: Icon(
                  _kvkkExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: IconSizes.listItem,
                  color: AppColors.accent,
                ),
                label: Text(
                  _kvkkExpanded ? 'legal_collapse'.tr() : 'legal_expand'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ConsentCheckboxWidget(
          label: 'legal_kvkk_accept_label'.tr(),
          value: _isKvkkAcknowledged,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            setState(() => _isKvkkAcknowledged = v ?? false);
          },
        ),
      ],
    );
  }

  Widget _buildOptionalConsents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          icon: Icons.tune_rounded,
          label: 'legal_consent_subtitle'.tr(),
          required: false,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: IconSizes.inline,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
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
        const SizedBox(height: 10),
        ConsentCheckboxWidget(
          label: 'legal_consent_location'.tr(),
          sublabel: 'legal_consent_location_sub'.tr(),
          value: _consentLocation,
          onChanged: (v) => setState(() => _consentLocation = v ?? false),
        ),
        ConsentCheckboxWidget(
          label: 'legal_consent_emergency_contacts'.tr(),
          sublabel: 'legal_consent_emergency_contacts_sub'.tr(),
          value: _consentEmergencyContacts,
          onChanged: (v) =>
              setState(() => _consentEmergencyContacts = v ?? false),
        ),
        ConsentCheckboxWidget(
          label: 'legal_consent_profile'.tr(),
          sublabel: 'legal_consent_profile_sub'.tr(),
          value: _consentProfile,
          onChanged: (v) => setState(() => _consentProfile = v ?? false),
        ),
        ConsentCheckboxWidget(
          label: 'legal_consent_fake_call'.tr(),
          sublabel: 'legal_consent_fake_call_sub'.tr(),
          value: _consentFakeCall,
          onChanged: (v) => setState(() => _consentFakeCall = v ?? false),
        ),
      ],
    );
  }

  Widget _buildRejectionNote() {
    return Container(
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
    );
  }

  Widget _buildActionButton() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canProceed && !_loading ? _complete : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
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
                  'legal_unified_cta'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _sectionLabel({
    required IconData icon,
    required String label,
    required bool required,
    Color color = AppColors.primary,
  }) {
    return Row(
      children: [
        Icon(icon, size: IconSizes.listItem, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (required)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Zorunlu',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
