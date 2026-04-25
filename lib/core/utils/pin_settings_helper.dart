// ============================================================================
// PIN AYARLARI - ORTAK BOTTOM SHEET (Ayarlar + Profil)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import '../app_colors.dart';
import '../services/activity_service.dart';
import 'validators.dart';
import '../../domain/models/activity_event.dart';

abstract class PinSettingsHelper {
  /// Shows the PIN change bottom sheet. Used from Settings and Profile.
  static void showPinChangeSheet(BuildContext context) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "settings_pin_dialog_title".tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "settings_pin_dialog_desc".tr(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: oldController,
              obscureText: true,
              keyboardType: TextInputType.number,
              enableSuggestions: false,
              autocorrect: false,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              contextMenuBuilder: (context, editableTextState) =>
                  const SizedBox.shrink(),
              decoration: InputDecoration(
                hintText: "settings_pin_old".tr(),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              keyboardType: TextInputType.number,
              enableSuggestions: false,
              autocorrect: false,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              contextMenuBuilder: (context, editableTextState) =>
                  const SizedBox.shrink(),
              decoration: InputDecoration(
                hintText: "settings_pin_new".tr(),
                prefixIcon: const Icon(Icons.lock_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final secureStorage = serviceLocator<SecureStorage>();
                  final prefs = await SharedPreferences.getInstance();
                  String? currentPin = await secureStorage.read(
                    key: SecureStorageKeys.userPin,
                  );
                  if (currentPin == null || currentPin.isEmpty) {
                    final legacy = prefs.getString(SecureStorageKeys.userPin);
                    if (legacy != null && legacy.isNotEmpty) {
                      await secureStorage.write(
                        key: SecureStorageKeys.userPin,
                        value: legacy,
                      );
                      await prefs.remove(SecureStorageKeys.userPin);
                      currentPin = legacy;
                    }
                  }
                  if (!ctx.mounted) return;
                  if (currentPin == null || currentPin.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("settings_pin_not_found".tr()),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  if (oldController.text != currentPin) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("settings_pin_wrong".tr()),
                        backgroundColor: AppColors.emergency,
                      ),
                    );
                    return;
                  }
                  if (newController.text.length != 4) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("settings_pin_length_error".tr()),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  if (!Validators.isValidPin(newController.text)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("pin_weak_error".tr()),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  if (newController.text == currentPin) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("settings_pin_same_as_old".tr()),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  await secureStorage.write(
                    key: SecureStorageKeys.userPin,
                    value: newController.text,
                  );
                  await prefs.remove(SecureStorageKeys.userPin);
                  await ActivityService.logEvent(
                    type: ActivityType.pinChanged,
                    title: "activity_pin_changed_title".tr(),
                    description: "activity_pin_changed_desc".tr(),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("settings_pin_updated".tr()),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "save".tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
