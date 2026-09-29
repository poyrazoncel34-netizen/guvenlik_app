import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../../screens/splash_screen.dart';
import '../../screens/app_root.dart';
import '../app_colors.dart';
import '../widgets/subscription_deletion_notice.dart';
import '../services/app_reset_service.dart';
import '../services/emergency_session_contract.dart';
import '../widgets/sensitive_action_pin_gate.dart';
import '../widgets/escape_dismissible.dart';

class AppResetHelper {
  AppResetHelper._();

  static void showResetDialog(BuildContext context, {String? title}) {
    showDialog(
      context: context,
      builder: (dialogContext) => EscapeDismissible(
        child: AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.all(28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: IconSizes.feature,
                  color: AppColors.emergency,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title ?? "settings_logout".tr(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "settings_logout_confirm".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              // MP-23-015. This dialog is the OTHER way local data is erased, and
              // it lists the same all-local set. A subscriber must hear it on
              // both paths or the honest one is just the one they did not take.
              const SubscriptionDeletionNotice(compact: true),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "settings_cancel".tr(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final pinVerified =
                            await _verifyPinIfConfigured(context);
                        if (!pinVerified) return;
                        final wipe = await AppResetService.clearLocalData();
                        if (!context.mounted) return;
                        if (wipe != WipeResult.completed) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('data_delete_pending'.tr())),
                          );
                          return;
                        }
                        if (AppRoot.restartStartup(context)) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const SplashScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emergency,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "settings_logout".tr(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> _verifyPinIfConfigured(BuildContext context) =>
      SensitiveActionPinGate.ensure(context);
}
