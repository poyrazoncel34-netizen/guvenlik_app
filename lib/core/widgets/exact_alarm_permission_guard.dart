import '../design_tokens.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/emergency_platform_service.dart';
import 'escape_dismissible.dart';

/// Timed safety sessions and delayed fake calls are not acknowledged unless
/// Android exact-alarm access is currently available. Opening Settings is not
/// an acknowledgement: the caller must retry after returning to the app.
Future<bool> requireExactAlarmPermission(BuildContext context) async {
  final platform = EmergencyPlatformService.instance;
  if (!platform.isSupported) {
    return true;
  }

  final canScheduleExactAlarms = await platform.canScheduleExactAlarms();
  if (canScheduleExactAlarms) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  await showExactAlarmPrompt(context, platform: platform);

  return false;
}

/// The dialog above, with the sentence that fits the caller: the panic setup
/// (2026-11-02) explains the panic, not a timed action. True when the user
/// chose to open the alarm settings; Settings has then been asked to open.
Future<bool> showExactAlarmPrompt(
  BuildContext context, {
  String bodyKey = 'exact_alarm_degraded_body',
  EmergencyPlatformService? platform,
}) async {
  final settings = platform ?? EmergencyPlatformService.instance;
  final opened = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => EscapeDismissible(
        child: AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'exact_alarm_degraded_title'.tr(),
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: Text(
        bodyKey.tr(),
        style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('exact_alarm_degraded_cancel'.tr()),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop(true);
            unawaited(settings.requestExactAlarmPermission());
          },
          icon: const Icon(Icons.settings_rounded, size: IconSizes.listItem),
          label: Text('exact_alarm_degraded_settings'.tr()),
        ),
      ],
    ),
      ),
  );
  return opened ?? false;
}
