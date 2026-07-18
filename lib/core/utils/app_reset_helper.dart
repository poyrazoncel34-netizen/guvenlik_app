import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/splash_screen.dart';
import '../app_colors.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import '../services/app_reset_service.dart';
import '../services/emergency_session_contract.dart';

class AppResetHelper {
  AppResetHelper._();

  static void showResetDialog(BuildContext context, {String? title}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                size: 36,
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
                      final pinVerified = await _verifyPinIfConfigured(context);
                      if (!pinVerified) return;
                      final wipe = await AppResetService.clearLocalData();
                      if (!context.mounted) return;
                      if (wipe != WipeResult.completed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('data_delete_pending'.tr())),
                        );
                        return;
                      }
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
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
    );
  }

  static Future<bool> _verifyPinIfConfigured(BuildContext context) async {
    final currentPin = await _readConfiguredPin();
    if (currentPin == null || currentPin.isEmpty) {
      return true;
    }
    if (!context.mounted) return false;

    final controller = TextEditingController();
    var errorVisible = false;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'reset_pin_verify_title'.tr(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              hintText: 'reset_pin_verify_hint'.tr(),
              errorText: errorVisible ? 'settings_pin_wrong'.tr() : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'settings_cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text == currentPin) {
                  Navigator.pop(dialogContext, true);
                  return;
                }
                setState(() => errorVisible = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('reset_pin_verify_confirm'.tr()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return verified == true;
  }

  static Future<String?> _readConfiguredPin() async {
    final secureStorage = serviceLocator<SecureStorage>();
    final securePin = await secureStorage.read(key: SecureStorageKeys.userPin);
    if (securePin != null && securePin.isNotEmpty) {
      return securePin;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyPin = prefs.getString(SecureStorageKeys.userPin);
    if (legacyPin != null && legacyPin.isNotEmpty) {
      await secureStorage.write(
        key: SecureStorageKeys.userPin,
        value: legacyPin,
      );
      await prefs.remove(SecureStorageKeys.userPin);
      return legacyPin;
    }
    return null;
  }
}
