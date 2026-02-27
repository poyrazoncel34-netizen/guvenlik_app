// ============================================================================
// STARTUP DIAGNOSTICS SERVICE - Self-Healing on Boot
// ============================================================================
// Runs comprehensive diagnostics on app startup.
// Detects and repairs corrupted data, checks system health, syncs offline queue.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'breadcrumb_service.dart';
import 'health_check_service.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'battery_optimization_service.dart';
import 'doze_mode_service.dart';

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

/// Startup diagnostics service
class StartupDiagnosticsService {
  static final StartupDiagnosticsService _instance = 
      StartupDiagnosticsService._();
  static StartupDiagnosticsService get instance => _instance;
  StartupDiagnosticsService._();
  
  bool _hasRun = false;
  
  /// Run full startup diagnostics
  Future<void> run() async {
    if (_hasRun) {
      debugPrint('⚠️ Startup diagnostics already run');
      return;
    }
    
    debugPrint('🚀 Starting startup diagnostics...');
    BreadcrumbService.instance.add('App startup diagnostics begin');
    
    try {
      // 1. Collect device info
      final deviceInfo = await _collectDeviceInfo();
      await _reportDeviceInfo(deviceInfo);
      
      // 2. Check system health
      final health = await HealthCheckService.instance.performHealthCheck();
      BreadcrumbService.instance.add(
        'Health check: ${health.isHealthy ? "healthy" : "issues: ${health.issuesString}"}',
      );
      
      // 3. Check Android-specific optimizations
      if (Platform.isAndroid) {
        await _checkAndroidOptimizations();
      }
      
      // 4. Sync offline queue if online
      if (ConnectivityService.instance.isOnline) {
        BreadcrumbService.instance.add('Syncing offline queue');
        await OfflineQueueService.instance.syncPendingEvents();
      }
      
      // 5. Mark as complete
      _hasRun = true;
      BreadcrumbService.instance.add('Startup diagnostics complete');
      debugPrint('✅ Startup diagnostics complete');
      
    } catch (e, stack) {
      debugPrint('❌ Startup diagnostics failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      BreadcrumbService.instance.addError('Startup diagnostics failed: $e');
    }
  }
  
  /// Collect device information
  Future<DeviceInfo> _collectDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      return DeviceInfo(
        platform: Platform.isAndroid ? 'Android' : 
                 Platform.isIOS ? 'iOS' : 'Unknown',
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
  
  /// Report device info to Crashlytics
  Future<void> _reportDeviceInfo(DeviceInfo info) async {
    try {
      final infoMap = info.toMap();
      for (final entry in infoMap.entries) {
        await FirebaseCrashlytics.instance.setCustomKey(
          'device_${entry.key}',
          entry.value,
        );
      }
      
      debugPrint('📱 Device: ${info.platform} v${info.appVersion}');
    } catch (e) {
      debugPrint('Failed to report device info: $e');
    }
  }
  
  /// Check Android-specific optimizations
  Future<void> _checkAndroidOptimizations() async {
    try {
      // Battery optimization status
      final batteryOptDisabled = 
          await BatteryOptimizationService.instance.isOptimizationDisabled();
      
      await FirebaseCrashlytics.instance.setCustomKey(
        'battery_opt_disabled',
        batteryOptDisabled,
      );
      
      if (!batteryOptDisabled) {
        debugPrint('⚠️ Battery optimization is enabled');
        BreadcrumbService.instance.addWarning(
          'Battery optimization enabled - may affect background operation',
        );
      }
      
      // Doze Mode whitelist status
      final dozeWhitelisted = await DozeModeService.instance.isWhitelisted();
      
      await FirebaseCrashlytics.instance.setCustomKey(
        'doze_whitelisted',
        dozeWhitelisted,
      );
      
      if (!dozeWhitelisted) {
        debugPrint('⚠️ Not whitelisted from Doze Mode');
        BreadcrumbService.instance.addWarning(
          'Not whitelisted from Doze Mode - may not work in deep sleep',
        );
      }
      
    } catch (e) {
      debugPrint('Failed to check Android optimizations: $e');
    }
  }
  
  /// Get startup status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'has_run': _hasRun,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
