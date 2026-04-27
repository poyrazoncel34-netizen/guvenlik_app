// ============================================================================
// FEATURE WARNING DIALOG — KVKK Article 5: Notice before processing
// ----------------------------------------------------------------------------
// Shown once per feature (gated by a SharedPreferences flag) so the user is
// informed before the feature processes any data. Title/content are pulled
// from easy_localization keys so EN/TR users see their own language.
// ============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../services/legal_log_service.dart';

class FeatureWarningHelper {
  FeatureWarningHelper._();

  /// Shows the first-use warning dialog for a feature.
  ///
  /// [prefKey] — SharedPreferences flag key (AppConstants.prefWarning*)
  /// [featureName] — technical name for the audit log (e.g. 'panic_button')
  /// [title] — already-localized dialog title (typically a getter below)
  /// [content] — already-localized dialog content (typically a getter below)
  ///
  /// Returns `true` if the user accepted (or had already accepted previously),
  /// `false` if the dialog was suppressed because the host context is gone.
  static Future<bool> showIfNeeded(
    BuildContext context, {
    required String prefKey,
    required String featureName,
    required String title,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(prefKey) ?? false;
    if (alreadyShown) return true;

    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FeatureWarningDialog(
        title: title,
        content: content,
        onAccepted: () async {
          await prefs.setBool(prefKey, true);
          await LegalLogService.instance.logEvent(
            'warning_shown_and_accepted',
            feature: featureName,
          );
        },
      ),
    );

    return true;
  }

  // ── Localized titles / contents ──────────────────────────────────────────
  // NOTE: kept as static getters (not const fields) so the active locale is
  // resolved at call time. Boot-restart disclosure test reads the TR JSON
  // value of feature_warning_checkin_content for the "yeniden başlat" check.

  static String get panicTitle => 'feature_warning_panic_title'.tr();
  static String get panicContent => 'feature_warning_panic_content'.tr();

  static String get checkinTitle => 'feature_warning_checkin_title'.tr();
  static String get checkinContent => 'feature_warning_checkin_content'.tr();

  static String get sirenTitle => 'feature_warning_siren_title'.tr();
  static String get sirenContent => 'feature_warning_siren_content'.tr();

  static String get locationTitle => 'feature_warning_location_title'.tr();
  static String get locationContent => 'feature_warning_location_content'.tr();
}

class _FeatureWarningDialog extends StatelessWidget {
  final String title;
  final String content;
  final Future<void> Function() onAccepted;

  const _FeatureWarningDialog({
    required this.title,
    required this.content,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await onAccepted();
              if (context.mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'feature_warning_continue'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
