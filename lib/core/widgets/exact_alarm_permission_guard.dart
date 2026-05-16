import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/emergency_platform_service.dart';

Future<bool> confirmExactAlarmPermissionOrDegraded(BuildContext context) async {
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

  final acknowledged = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'exact_alarm_degraded_title'.tr(),
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: Text(
        'exact_alarm_degraded_body'.tr(),
        style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('exact_alarm_degraded_cancel'.tr()),
        ),
        OutlinedButton.icon(
          onPressed: () {
            unawaited(platform.requestExactAlarmPermission());
          },
          icon: const Icon(Icons.settings_rounded, size: 18),
          label: Text('exact_alarm_degraded_settings'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
          ),
          child: Text('exact_alarm_degraded_continue'.tr()),
        ),
      ],
    ),
  );

  return acknowledged == true;
}
