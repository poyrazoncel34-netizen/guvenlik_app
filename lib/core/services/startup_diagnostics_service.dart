// ============================================================================
// STARTUP DIAGNOSTICS SERVICE - Offline-First Boot Check
// ============================================================================
// Local diagnostics only. No Firebase, no network. Not called at startup
// to ensure instant app launch.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'health_check_service.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'battery_optimization_service.dart';

/// Device information for diagnostics
class DeviceInfo {
  final String platform;
  final String appVersion;
  final String buildNumber;
  final bool isPhysicalDevice;

  DeviceInfo({
    required this.platform,
    required this.appVersion,
    required this.buildNumber,
    required this.isPhysicalDevice,
  });

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'app_version': appVersion,
      'build_number': buildNumber,
      'is_physical_device': isPhysicalDevice,
    };
  }
}

/// Startup diagnostics - offline only, no cloud
class StartupDiagnosticsService {
  static final StartupDiagnosticsService _instance =
      StartupDiagnosticsService._();
  static StartupDiagnosticsService get instance => _instance;
  StartupDiagnosticsService._();

  bool _hasRun = false;

  /// Run diagnostics (call optionally, not at boot)
  Future<void> run() async {
    if (_hasRun) {
      debugPrint('⚠️ Startup diagnostics already run');
      return;
    }

    debugPrint('🚀 Starting startup diagnostics...');

    try {
      final deviceInfo = await _collectDeviceInfo();
      debugPrint('📱 Device: ${deviceInfo.platform} v${deviceInfo.appVersion}');

      final health = await HealthCheckService.instance.performHealthCheck();
      debugPrint(
        'Health: ${health.isHealthy ? "OK" : "issues: ${health.issuesString}"}',
      );

      if (Platform.isAndroid) {
        await _checkAndroidOptimizations();
      }

      if (ConnectivityService.instance.isOnline) {
        await OfflineQueueService.instance.processPendingEventsLocal();
      }

      _hasRun = true;
      debugPrint('✅ Startup diagnostics complete');
    } catch (e, stack) {
      debugPrint('❌ Startup diagnostics failed: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<DeviceInfo> _collectDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return DeviceInfo(
        platform: Platform.isAndroid
            ? 'Android'
            : Platform.isIOS
            ? 'iOS'
            : 'Unknown',
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        isPhysicalDevice: !kIsWeb,
      );
    } catch (e) {
      debugPrint('Failed to collect device info: $e');
      return DeviceInfo(
        platform: 'Unknown',
        appVersion: '0.0.0',
        buildNumber: '0',
        isPhysicalDevice: true,
      );
    }
  }

  Future<void> _checkAndroidOptimizations() async {
    try {
      final batteryOptDisabled = await BatteryOptimizationService.instance
          .isOptimizationDisabled();
      if (!batteryOptDisabled) {
        debugPrint('⚠️ Battery optimization is enabled');
      }
    } catch (e) {
      debugPrint('Failed to check Android optimizations: $e');
    }
  }

  Map<String, dynamic> getStatus() {
    return {'has_run': _hasRun, 'timestamp': DateTime.now().toIso8601String()};
  }
}
