// ============================================================================
// PIN AYARLARI - ORTAK BOTTOM SHEET (Ayarlar + Profil)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_colors.dart';
import '../services/activity_service.dart';
import '../services/emergency_session_contract.dart';
import '../services/pin_verification_service.dart';
import 'validators.dart';
import '../../domain/models/activity_event.dart';
import '../widgets/escape_dismissible.dart';

abstract class PinSettingsHelper {
  /// Shows the PIN change bottom sheet. Used from Settings and Profile.
  static void showPinChangeSheet(BuildContext context) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EscapeDismissible(
        child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
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
                      // The configured PIN is never read into this closure.
                      // PinVerificationService owns the constant-time
                      // comparison and the one-way legacy migration, so there
                      // is a single verification path in the app.
                      final currentCheck = await PinVerificationService.instance
                          .verify(oldController.text);
                      if (!ctx.mounted) return;
                      if (currentCheck.state == PinState.absent) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text("settings_pin_not_found".tr()),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      if (currentCheck.state == PinState.readFailed) {
                        // A storage failure must not read as a wrong PIN.
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text("pin_state_read_failed".tr()),
                            backgroundColor: AppColors.emergency,
                          ),
                        );
                        return;
                      }
                      if (!currentCheck.matches) {
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
                      final reuseCheck = await PinVerificationService.instance
                          .verify(newController.text);
                      if (!ctx.mounted) return;
                      if (reuseCheck.matches) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text("settings_pin_same_as_old".tr()),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      final saved = await PinVerificationService.instance
                          .writePin(newController.text);
                      if (!ctx.mounted) return;
                      if (!saved) {
                        // The old PIN still works; saying "updated" here would
                        // send the user away with the wrong PIN in mind.
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text("pin_setup_save_failed".tr()),
                            backgroundColor: AppColors.emergency,
                          ),
                        );
                        return;
                      }
                      await ActivityService.logEvent(
                        type: ActivityType.pinChanged,
                        title: "activity_pin_changed_title".tr(),
                        description: "activity_pin_changed_desc".tr(),
                      );
                      if (ctx.mounted) {
                        final messenger = ScaffoldMessenger.of(ctx);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
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
        ),
      ),
      ),
    ).whenComplete(() {
      oldController.dispose();
      newController.dispose();
    });
  }
}
