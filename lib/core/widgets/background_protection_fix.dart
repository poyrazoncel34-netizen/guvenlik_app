import 'package:flutter/material.dart';

import '../../screens/battery_optimization_wizard.dart';
import '../services/emergency_platform_service.dart';
import '../services/notification_preferences_service.dart';
import '../utils/permission_helper.dart';

/// What the home readiness chip "Arka Plan Hazırlığı" opens: the piece that is
/// actually missing (Y-11, owner decision 2026-10-09).
///
/// The chip is red whenever exact-alarm access, notifications or the alert
/// channel is missing (`backgroundAlertReady`), but it always opened the
/// battery wizard, which fixes none of them. On an API 36 clean install the
/// red chip was the only visible hint and led nowhere near the exact-alarm
/// setting. Returning from Settings re-probes readiness on resume.
///
/// With notifications on and only the alert channel lowered, the app page is
/// one screen short of the switch; that channel's own screen opens instead
/// (2026-11-02), the same one the blocked-panic dialog offers.
abstract final class BackgroundProtectionFix {
  static Future<void> open(
    BuildContext context, {
    required PlatformReadinessSnapshot? readiness,
    EmergencyPlatformService? platform,
    Future<bool> Function()? openNotificationSettings,
    NotificationPreferencesService? notificationPreferences,
  }) async {
    final known = readiness != null && readiness.isKnown;
    if (known && !readiness.exactAlarmPermission) {
      await (platform ?? EmergencyPlatformService.instance)
          .requestExactAlarmPermission();
      return;
    }
    if (known && !readiness.notificationPermission) {
      await (openNotificationSettings ??
          PermissionHelper.openNotificationSettings)();
      return;
    }
    if (known && !readiness.alertChannelHigh) {
      await (notificationPreferences ??
              NotificationPreferencesService.instance)
          .openSettingsFor(NotificationCategory.emergencyAlert);
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const BatteryOptimizationWizard(),
      ),
    );
  }
}
