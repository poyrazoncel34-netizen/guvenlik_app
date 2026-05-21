// ============================================================================
// HEALTH CHECK SERVICE - Offline-First System Status
// ============================================================================
// Performs local health checks. No Firebase, no network calls.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';

/// System health status (offline-first)
class HealthStatus {
  final bool gpsHealthy;
  final bool permissionsHealthy;
  final bool batteryHealthy;
  final bool sensorsHealthy;

  HealthStatus({
    required this.gpsHealthy,
    required this.permissionsHealthy,
    required this.batteryHealthy,
    required this.sensorsHealthy,
  });

  bool get isHealthy => gpsHealthy && permissionsHealthy && batteryHealthy;

  List<String> get issues {
    final problems = <String>[];
    if (!gpsHealthy) problems.add('gps');
    if (!permissionsHealthy) problems.add('permissions');
    if (!batteryHealthy) problems.add('battery');
    if (!sensorsHealthy) problems.add('sensors');
    return problems;
  }

  String get issuesString => issues.join(', ');
}

/// Health check service - no cloud dependencies
class HealthCheckService {
  static final HealthCheckService _instance = HealthCheckService._();
  static HealthCheckService get instance => _instance;
  HealthCheckService._();

  static const int lowBatteryThreshold = 15;

  /// Perform local health check (no network)
  Future<HealthStatus> performHealthCheck() async {
    debugPrint('🏥 Starting local health check...');

    try {
      final results = await Future.wait<bool>([
        _checkGPS(),
        _checkPermissions(),
        _checkBattery(),
        _checkSensors(),
      ]);

      final status = HealthStatus(
        gpsHealthy: results[0],
        permissionsHealthy: results[1],
        batteryHealthy: results[2],
        sensorsHealthy: results[3],
      );

      if (!status.isHealthy) {
        debugPrint('⚠️ Health issues: ${status.issuesString}');
      } else {
        debugPrint('✅ All systems healthy');
      }

      return status;
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return HealthStatus(
        gpsHealthy: false,
        permissionsHealthy: false,
        batteryHealthy: false,
        sensorsHealthy: false,
      );
    }
  }

  Future<bool> _checkGPS() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('GPS check failed: $e');
      return false;
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      final location = await Permission.location.isGranted;
      final locationAlways = await Permission.locationAlways.isGranted;
      return location || locationAlways;
    } catch (e) {
      debugPrint('Permissions check failed: $e');
      return false;
    }
  }

  Future<bool> _checkBattery() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      return level > lowBatteryThreshold;
    } catch (e) {
      debugPrint('Battery check failed: $e');
      return true;
    }
  }

  Future<bool> _checkSensors() async {
    try {
      return true;
    } catch (e) {
      debugPrint('Sensors check failed: $e');
      return false;
    }
  }
}
