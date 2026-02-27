// ============================================================================
// HEALTH CHECK SERVICE - System Status Monitoring
// ============================================================================
// Performs comprehensive health checks on app startup and periodically.
// Detects and reports system issues to Crashlytics.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'connectivity_service.dart';
import 'firebase_service.dart';

/// System health status
class HealthStatus {
  final bool networkHealthy;
  final bool firebaseHealthy;
  final bool gpsHealthy;
  final bool permissionsHealthy;
  final bool batteryHealthy;
  final bool sensorsHealthy;
  
  HealthStatus({
    required this.networkHealthy,
    required this.firebaseHealthy,
    required this.gpsHealthy,
    required this.permissionsHealthy,
    required this.batteryHealthy,
    required this.sensorsHealthy,
  });
  
  bool get isHealthy =>
      networkHealthy &&
      firebaseHealthy &&
      gpsHealthy &&
      permissionsHealthy &&
      batteryHealthy;
  
  List<String> get issues {
    final problems = <String>[];
    if (!networkHealthy) problems.add('network');
    if (!firebaseHealthy) problems.add('firebase');
    if (!gpsHealthy) problems.add('gps');
    if (!permissionsHealthy) problems.add('permissions');
    if (!batteryHealthy) problems.add('battery');
    if (!sensorsHealthy) problems.add('sensors');
    return problems;
  }
  
  String get issuesString => issues.join(', ');
  
  Map<String, dynamic> toMap() {
    return {
      'network_healthy': networkHealthy,
      'firebase_healthy': firebaseHealthy,
      'gps_healthy': gpsHealthy,
      'permissions_healthy': permissionsHealthy,
      'battery_healthy': batteryHealthy,
      'sensors_healthy': sensorsHealthy,
      'overall_healthy': isHealthy,
      'issues': issuesString,
    };
  }
}

/// Health check service
class HealthCheckService {
  static final HealthCheckService _instance = HealthCheckService._();
  static HealthCheckService get instance => _instance;
  HealthCheckService._();
  
  static const int LOW_BATTERY_THRESHOLD = 15;
  
  /// Perform comprehensive health check
  Future<HealthStatus> performHealthCheck() async {
    debugPrint('🏥 Starting health check...');
    
    try {
      final results = await Future.wait([
        _checkNetwork(),
        _checkFirebase(),
        _checkGPS(),
        _checkPermissions(),
        _checkBattery(),
        _checkSensors(),
      ]);
      
      final status = HealthStatus(
        networkHealthy: results[0] as bool,
        firebaseHealthy: results[1] as bool,
        gpsHealthy: results[2] as bool,
        permissionsHealthy: results[3] as bool,
        batteryHealthy: results[4] as bool,
        sensorsHealthy: results[5] as bool,
      );
      
      // Report to Crashlytics
      await _reportHealthStatus(status);
      
      // Log issues
      if (!status.isHealthy) {
        debugPrint('⚠️ Health issues: ${status.issuesString}');
        await FirebaseCrashlytics.instance.recordError(
          Exception('Health check failed'),
          StackTrace.current,
          reason: 'System health issues: ${status.issuesString}',
          fatal: false,
        );
      } else {
        debugPrint('✅ All systems healthy');
      }
      
      return status;
    } catch (e, stack) {
      debugPrint('❌ Health check failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
      
      // Return unhealthy status
      return HealthStatus(
        networkHealthy: false,
        firebaseHealthy: false,
        gpsHealthy: false,
        permissionsHealthy: false,
        batteryHealthy: false,
        sensorsHealthy: false,
      );
    }
  }
  
  /// Check network connectivity
  Future<bool> _checkNetwork() async {
    try {
      final isOnline = ConnectivityService.instance.isOnline;
      
      // Also try a real connection test
      if (isOnline) {
        try {
          final result = await InternetAddress.lookup('google.com')
              .timeout(Duration(seconds: 5));
          return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (e) {
          debugPrint('Network test failed: $e');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Network check failed: $e');
      return false;
    }
  }
  
  /// Check Firebase connectivity
  Future<bool> _checkFirebase() async {
    try {
      // Check if Firebase is initialized
      return FirebaseService.instance != null;
    } catch (e) {
      debugPrint('Firebase check failed: $e');
      return false;
    }
  }
  
  /// Check GPS availability
  Future<bool> _checkGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      return serviceEnabled;
    } catch (e) {
      debugPrint('GPS check failed: $e');
      return false;
    }
  }
  
  /// Check critical permissions
  Future<bool> _checkPermissions() async {
    try {
      final location = await Permission.location.isGranted;
      final locationAlways = await Permission.locationAlways.isGranted;
      
      // At least one location permission should be granted
      return location || locationAlways;
    } catch (e) {
      debugPrint('Permissions check failed: $e');
      return false;
    }
  }
  
  /// Check battery level
  Future<bool> _checkBattery() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      
      // Healthy if above threshold
      return level > LOW_BATTERY_THRESHOLD;
    } catch (e) {
      debugPrint('Battery check failed: $e');
      return true; // Assume healthy if can't check
    }
  }
  
  /// Check sensors availability
  Future<bool> _checkSensors() async {
    try {
      // For now, assume sensors are available
      // Can be extended to check accelerometer, etc.
      return true;
    } catch (e) {
      debugPrint('Sensors check failed: $e');
      return false;
    }
  }
  
  /// Report health status to Crashlytics
  Future<void> _reportHealthStatus(HealthStatus status) async {
    try {
      final statusMap = status.toMap();
      for (final entry in statusMap.entries) {
        await FirebaseCrashlytics.instance.setCustomKey(
          'health_${entry.key}',
          entry.value,
        );
      }
    } catch (e) {
      debugPrint('Failed to report health status: $e');
    }
  }
}
