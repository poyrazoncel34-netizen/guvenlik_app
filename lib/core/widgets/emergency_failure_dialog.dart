import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../design_tokens.dart';
import '../services/android_intent_service.dart';
import '../services/emergency_result_policy.dart';
import 'dispatch_outcome_list.dart';

/// The FULLSCREEN BLOCKING failure surface. The user MUST interact: no silent
/// dismissal, no SnackBar. This is the fail-safe of last resort.
///
/// Lifted out of `countdown_screen.dart` unchanged in appearance, for two
/// reasons. That file is accepted size debt the ratchet holds at 1228 lines,
/// so the ledger section had to land somewhere else; and while the dialog was
/// private to one State class, the only way to check what it renders was to
/// read the source. It is now a widget a test can pump directly.
///
/// What changed in substance (MP-01-027 / FIR-01): the copy and the per-target
/// list both come from [EmergencyFailureCopy], which no caller can construct.
/// A failed phone handoff can no longer print "no action completed" over a
/// ledger that recorded four targets reached.
abstract final class EmergencyFailureDialog {
  static Future<void> show(
    BuildContext context, {
    required EmergencyFailureCopy copy,
    required String phoneNumber,
    String? emergencyMessage,
    bool popHostOnDismiss = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.emergency.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_rounded,
                    color: AppColors.emergency,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 16),
                // Heading of the blocking failure surface (MP-12-017).
                Semantics(
                  header: true,
                  child: Text(
                    copy.titleKey.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.bodyKey.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      phoneNumber,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                // The per-target ledger. Rendering it HERE is the fix: the
                // failure branch used to return before any surface could show
                // it, so targets that were reached vanished from the account
                // the user was given.
                ...DispatchOutcomeList.build(copy.ledger),
                if (emergencyMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      emergencyMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (phoneNumber.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await AndroidIntentService.openDialer(phoneNumber);
                  },
                  icon: const Icon(Icons.call, size: IconSizes.action),
                  label: Text(
                    'emergency_manual_call_now'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (emergencyMessage != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: emergencyMessage));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('emergency_message_copied'.tr()),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: IconSizes.listItem),
                  label: Text('emergency_copy_message'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (popHostOnDismiss) Navigator.pop(context);
                },
                child: Text(
                  'emergency_dismiss'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
