// ============================================================================
// ONBOARDING - ACIL KISI ADIMI
// ============================================================================
// Onboarding'in gecilemez son adimi. Kisi eklenmeden onboarding tamamlanamaz;
// karar mantigi [OnboardingContactGateService] icinde, bu widget yalnizca onu
// surer ve durumunu ust ekrana bildirir.
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/services/native_contact_picker_service.dart';
import '../../core/services/onboarding_contact_gate_service.dart';
import '../../core/utils/emergency_number_validator.dart';
import '../../widgets/emergency_contact_consent_dialog.dart';

const int _nameInputLimit = 60;
const int _phoneInputLimit = 32;

class OnboardingContactStep extends StatefulWidget {
  const OnboardingContactStep({super.key, required this.onGateChanged});

  /// Fires with true once a callable primary contact exists, false when it does
  /// not. The onboarding screen uses this to enable its completion button.
  final ValueChanged<bool> onGateChanged;

  @override
  State<OnboardingContactStep> createState() =>
      _OnboardingContactStepState();
}

class _OnboardingContactStepState extends State<OnboardingContactStep> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _hasContact = false;
  bool _needsConsent = false;
  String? _phoneErrorKey;
  String? _failureKey;
  String _savedName = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final hasContact = await OnboardingContactGateService.hasCallableContact();
    final needsConsent = OnboardingContactGateService.needsContactDataConsent();
    var savedName = '';
    if (hasContact) {
      savedName = await OnboardingContactGateService.primaryContactName() ?? '';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasContact = hasContact;
      _needsConsent = needsConsent;
      _savedName = savedName;
    });
    widget.onGateChanged(hasContact);
  }

  Future<void> _grantConsent() async {
    final locale = context.locale.languageCode;
    final granted = await OnboardingContactGateService.grantContactDataConsent(
      locale: locale,
    );
    if (!mounted) return;
    setState(() {
      _needsConsent = !granted;
      _failureKey = granted ? null : 'onboarding_contact_consent_failed';
    });
  }

  Future<void> _pickFromDevice() async {
    unawaited(HapticFeedback.selectionClick());
    final result = await NativeContactPickerService.pickPhoneContact();
    if (!mounted) return;
    if (result.isUnavailable) {
      setState(() => _failureKey = 'onboarding_contact_picker_failed');
      return;
    }
    final picked = result.contact;
    if (picked == null) return; // cancelled

    setState(() {
      _failureKey = null;
      _nameController.text = picked.name;
      _phoneController.text = picked.number;
      _phoneErrorKey = OnboardingContactGateService.phoneErrorKey(
        picked.number,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final phone = _phoneController.text;
    final errorKey = OnboardingContactGateService.phoneErrorKey(phone);
    if (errorKey != null) {
      setState(() => _phoneErrorKey = errorKey);
      return;
    }

    final name = _nameController.text.trim();
    final consentGiven = await EmergencyContactConsentDialog.show(
      context: context,
      contactName: name.isEmpty ? 'contacts_unknown'.tr() : name,
    );
    if (!mounted || !consentGiven) return;

    setState(() {
      _saving = true;
      _failureKey = null;
    });
    final outcome = await OnboardingContactGateService.savePrimaryContact(
      name: name,
      phone: phone,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case OnboardingContactSaveOutcome.saved:
        unawaited(HapticFeedback.mediumImpact());
        await _refresh();
      case OnboardingContactSaveOutcome.invalidPhone:
        setState(() => _phoneErrorKey = 'onboarding_contact_invalid_phone');
      case OnboardingContactSaveOutcome.storageFailed:
        setState(() => _failureKey = 'onboarding_contact_save_failed');
    }
  }

  void _startOver() {
    setState(() {
      _hasContact = false;
      _phoneErrorKey = null;
      _failureKey = null;
    });
    widget.onGateChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final failureKey = _failureKey;
    return Semantics(
      label: 'semantics_onboarding_contact_step'.tr(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 24),
            if (_hasContact) _savedCard() else ..._form(),
            // Local copy so the null check promotes: a field cannot, and `!` on
            // a field is exactly the pattern this repo avoids.
            if (failureKey != null) ...[
              const SizedBox(height: 16),
              _noticeCard(
                icon: Icons.error_outline_rounded,
                color: AppColors.warning,
                text: failureKey.tr(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: (_hasContact ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _hasContact
                ? Icons.how_to_reg_rounded
                : Icons.contact_phone_rounded,
            size: 40,
            color: _hasContact ? AppColors.success : AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'onboarding_contact_title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'onboarding_contact_body'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  List<Widget> _form() {
    return <Widget>[
      if (_needsConsent) ...[
        _consentCard(),
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _nameController,
        enabled: !_needsConsent && !_saving,
        maxLength: _nameInputLimit,
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: _fieldDecoration(
          label: 'onboarding_contact_name_label'.tr(),
          icon: Icons.person_outline_rounded,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _phoneController,
        enabled: !_needsConsent && !_saving,
        maxLength: _phoneInputLimit,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: AppColors.textPrimary),
        onChanged: (value) {
          final next = value.trim().isEmpty
              ? null
              : OnboardingContactGateService.phoneErrorKey(value);
          if (next != _phoneErrorKey) {
            setState(() => _phoneErrorKey = next);
          }
        },
        decoration: _fieldDecoration(
          label: 'onboarding_contact_phone_label'.tr(),
          icon: Icons.phone_outlined,
          errorText: _phoneErrorKey?.tr(),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'onboarding_contact_phone_hint'.tr(
          namedArgs: {
            'min': '${EmergencyNumberValidator.minUserContactDigits}',
            'max': '${EmergencyNumberValidator.maxUserContactDigits}',
          },
        ),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _needsConsent || _saving ? null : _pickFromDevice,
        icon: const Icon(Icons.contacts_rounded, size: 20),
        label: Text('onboarding_contact_pick_btn'.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        onPressed: _needsConsent || _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded, size: 20),
        label: Text('onboarding_contact_save_btn'.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ];
  }

  Widget _savedCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _noticeCard(
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          text: _savedName.isEmpty
              ? 'onboarding_contact_saved_desc_generic'.tr()
              : 'onboarding_contact_saved_desc'.tr(
                  namedArgs: {'name': _savedName},
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _startOver,
          child: Text(
            'onboarding_contact_change_btn'.tr(),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _consentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'onboarding_contact_consent_title'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'onboarding_contact_consent_body'.tr(),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _grantConsent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.background,
              ),
              child: Text('onboarding_contact_consent_grant_btn'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      counterText: '',
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.cardBg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emergency),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.emergency),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
    );
  }
}
