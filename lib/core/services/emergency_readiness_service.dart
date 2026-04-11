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

  bool get isReady => _lastState?.batteryOptimizationWhitelisted ?? false;

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
      );
    } on TimeoutException {
      debugPrint('[EmergencyReadiness] checkReadiness timed out');
      _lastState = const ReadinessState(
        batteryOptimizationWhitelisted: false,
        exactAlarmPermission: false,
        callPermission: false,
      );
    } catch (e) {
      debugPrint('[EmergencyReadiness] checkReadiness failed: $e');
      _lastState = const ReadinessState(
        batteryOptimizationWhitelisted: false,
        exactAlarmPermission: false,
        callPermission: false,
      );
    }

    return _lastState!;
  }
}

class ReadinessState {
  final bool batteryOptimizationWhitelisted;
  final bool exactAlarmPermission;
  final bool callPermission;

  const ReadinessState({
    required this.batteryOptimizationWhitelisted,
    required this.exactAlarmPermission,
    required this.callPermission,
  });
}
