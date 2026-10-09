import 'package:flutter/material.dart';

import '../../screens/battery_optimization_wizard.dart';
import '../services/emergency_platform_service.dart';
import '../utils/permission_helper.dart';

/// What the home readiness chip "Arka Plan Hazırlığı" opens: the piece that is
/// actually missing (Y-11, owner decision 2026-10-09).
///
/// The chip is red whenever exact-alarm access, notifications or the alert
/// channel is missing (`backgroundAlertReady`), but it always opened the
/// battery wizard, which fixes none of them. On an API 36 clean install the
/// red chip was the only visible hint and led nowhere near the exact-alarm
/// setting. Returning from Settings re-probes readiness on resume.
abstract final class BackgroundProtectionFix {
  static Future<void> open(
    BuildContext context, {
    required PlatformReadinessSnapshot? readiness,
    EmergencyPlatformService? platform,
    Future<bool> Function()? openNotificationSettings,
  }) async {
    final known = readiness != null && readiness.isKnown;
    if (known && !readiness.exactAlarmPermission) {
      await (platform ?? EmergencyPlatformService.instance)
          .requestExactAlarmPermission();
      return;
    }
    if (known &&
        (!readiness.notificationPermission || !readiness.alertChannelHigh)) {
      await (openNotificationSettings ??
          PermissionHelper.openNotificationSettings)();
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
