// ============================================================================
// ACİL DURUM KİŞİSİ EKLEME ONAY DIALOG'U
// KVKK — üçüncü kişi verisi işleme sorumluluğu kullanıcıya bildirim
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../services/consent_manager.dart';
import '../models/consent_record.dart';
import '../core/di/service_locator.dart';

class EmergencyContactConsentDialog extends StatefulWidget {
  final String contactName;
  final VoidCallback onConfirmed;
  final VoidCallback onCancelled;

  const EmergencyContactConsentDialog({
    super.key,
    required this.contactName,
    required this.onConfirmed,
    required this.onCancelled,
  });

  @override
  State<EmergencyContactConsentDialog> createState() =>
      _EmergencyContactConsentDialogState();

  /// Dialog'u göster ve sonucu döndür
  static Future<bool> show({
    required BuildContext context,
    required String contactName,
  }) async {
    bool confirmed = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmergencyContactConsentDialog(
        contactName: contactName,
        onConfirmed: () {
          confirmed = true;
          Navigator.pop(context);
        },
        onCancelled: () {
          confirmed = false;
          Navigator.pop(context);
        },
      ),
    );
    return confirmed;
  }
}

class _EmergencyContactConsentDialogState
    extends State<EmergencyContactConsentDialog> {
  bool _confirmed = false;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_confirmed || _loading) return;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final cm = serviceLocator<ConsentManager>();
      await cm.grantConsent(
        ConsentRecord.typeEmergencyContactPerson,
        locale: context.locale.languageCode,
      );
      widget.onConfirmed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'contact_consent_title'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Açıklama
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: 'contact_consent_desc_pre'.tr()),
                  TextSpan(
                    text: ' "${widget.contactName}" ',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: 'contact_consent_desc_post'.tr()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // KVKK uyarısı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'contact_consent_kvkk_warning'.tr(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3. kişi KVKK hakları bilgilendirmesi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'contact_consent_third_party_rights'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.info,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Onay checkbox
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _confirmed = !_confirmed);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _confirmed
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _confirmed ? AppColors.success : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _confirmed,
                        semanticLabel: 'contact_consent_checkbox_label'.tr(),
                        onChanged: (v) =>
                            setState(() => _confirmed = v ?? false),
                        activeColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'contact_consent_checkbox_label'.tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Butonlar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancelled,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmed && !_loading ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.3,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'contact_consent_confirm'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
