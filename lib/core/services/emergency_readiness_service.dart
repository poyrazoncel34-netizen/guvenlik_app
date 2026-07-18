import 'dart:async';

import 'package:flutter/foundation.dart';

import 'emergency_platform_service.dart';

/// System 3A: Checks device readiness for emergency dispatch.
/// Non-blocking — results cached for later query.
class EmergencyReadinessService {
  EmergencyReadinessService._();

  static final EmergencyReadinessService instance =
      EmergencyReadinessService._();

  ReadinessState? _lastState;

  ReadinessState? get lastState => _lastState;

  bool get isReady => _lastState?.criticalSafetyReady ?? false;

  Future<ReadinessState> checkReadiness() async {
    try {
      final deviceState = await EmergencyPlatformService.instance
          .getDeviceState()
          .timeout(const Duration(seconds: 3));

      _lastState = ReadinessState(
        batteryOptimizationWhitelisted:
            deviceState['batteryOptimizationsIgnored'] == true,
        exactAlarmPermission: deviceState['canScheduleExactAlarms'] == true,
        callPermission: deviceState['callPermissionGranted'] == true,
        notificationPermission: deviceState['notificationsEnabled'] == true,
      );
    } on TimeoutException {
      debugPrint('[EmergencyReadiness] checkReadiness timed out');
      _lastState = const ReadinessState(
        batteryOptimizationWhitelisted: false,
        exactAlarmPermission: false,
        callPermission: false,
        notificationPermission: false,
      );
    } catch (e) {
      debugPrint('[EmergencyReadiness] checkReadiness failed: $e');
      _lastState = const ReadinessState(
        batteryOptimizationWhitelisted: false,
        exactAlarmPermission: false,
        callPermission: false,
        notificationPermission: false,
      );
    }

    return _lastState!;
  }
}

class ReadinessState {
  final bool batteryOptimizationWhitelisted;
  final bool exactAlarmPermission;
  final bool callPermission;
  final bool notificationPermission;

  const ReadinessState({
    required this.batteryOptimizationWhitelisted,
    required this.exactAlarmPermission,
    required this.callPermission,
    required this.notificationPermission,
  });

  /// Required for a timed background alert to be both timely and visible.
  bool get backgroundAlertReady =>
      exactAlarmPermission && notificationPermission;

  /// Direct-call permission is required for the hands-free request path. A
  /// dialer fallback still exists, but it is intentionally not called ready.
  bool get criticalSafetyReady => backgroundAlertReady && callPermission;
}
