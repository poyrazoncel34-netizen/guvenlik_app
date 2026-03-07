// ============================================================================
// RESOURCE MONITOR SERVICE - RAM/CPU Tracking
// ============================================================================
// Monitors app resource usage to ensure optimal performance on mid-range devices.
// Offline-first: No Crashlytics.
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

/// Resource usage snapshot
class ResourceSnapshot {
  final DateTime timestamp;
  final int? memoryUsageMB;
  final int batteryLevel;
  final String batteryState;
  
  ResourceSnapshot({
    required this.timestamp,
    this.memoryUsageMB,
    required this.batteryLevel,
    required this.batteryState,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'memory_mb': memoryUsageMB,
      'battery_level': batteryLevel,
      'battery_state': batteryState,
    };
  }
}

/// Resource monitoring service
class ResourceMonitorService {
  static final ResourceMonitorService _instance = ResourceMonitorService._();
  static ResourceMonitorService get instance => _instance;
  ResourceMonitorService._();
  
  final Battery _battery = Battery();
  Timer? _monitorTimer;
  bool _isMonitoring = false;
  
  // Thresholds
  static const int highMemoryThresholdMb = 200;
  static const int criticalMemoryThresholdMb = 300;
  static const int lowBatteryThreshold = 15;
  
  // Monitoring interval
  static const Duration monitorInterval = Duration(minutes: 5);
  
  /// Start monitoring resources
  void startMonitoring() {
    if (_isMonitoring) {
      debugPrint('⚠️ Resource monitoring already active');
      return;
    }
    
    debugPrint('📊 Starting resource monitoring...');
    _isMonitoring = true;
    
    // Initial snapshot
    _takeSnapshot();
    
    // Periodic monitoring
    _monitorTimer = Timer.periodic(monitorInterval, (_) {
      _takeSnapshot();
    });
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    debugPrint('📊 Resource monitoring stopped');
  }
  
  /// Take a resource snapshot
  Future<ResourceSnapshot> _takeSnapshot() async {
    try {
      // Battery level
      final batteryLevel = await _battery.batteryLevel;
      final batteryState = (await _battery.batteryState).toString();
      
      // Memory usage (platform-specific)
      final memoryMB = await _getMemoryUsage();
      
      final snapshot = ResourceSnapshot(
        timestamp: DateTime.now(),
        memoryUsageMB: memoryMB,
        batteryLevel: batteryLevel,
        batteryState: batteryState,
      );
      
      // Check thresholds
      await _checkThresholds(snapshot);
      
      // Report to Crashlytics
      await _reportSnapshot(snapshot);
      
      return snapshot;
    } catch (e) {
      debugPrint('Failed to take resource snapshot: $e');
      
      // Return minimal snapshot
      return ResourceSnapshot(
        timestamp: DateTime.now(),
        memoryUsageMB: null,
        batteryLevel: 100,
        batteryState: 'unknown',
      );
    }
  }
  
  /// Get memory usage in MB
  Future<int?> _getMemoryUsage() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // For now, return null - can be implemented with platform channels
        // TODO: Implement native memory tracking
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get memory usage: $e');
      return null;
    }
  }
  
  /// Check resource thresholds and alert if exceeded
  Future<void> _checkThresholds(ResourceSnapshot snapshot) async {
    try {
      // Memory threshold check
      if (snapshot.memoryUsageMB != null) {
        if (snapshot.memoryUsageMB! >= criticalMemoryThresholdMb) {
          debugPrint('🚨 CRITICAL: Memory usage ${snapshot.memoryUsageMB}MB');
        } else if (snapshot.memoryUsageMB! >= highMemoryThresholdMb) {
          debugPrint('⚠️ HIGH: Memory usage ${snapshot.memoryUsageMB}MB');
        }
      }
      
      // Battery threshold check
      if (snapshot.batteryLevel <= lowBatteryThreshold) {
        debugPrint('🔋 LOW BATTERY: ${snapshot.batteryLevel}%');
      }
      
    } catch (e) {
      debugPrint('Failed to check thresholds: $e');
    }
  }
  
  Future<void> _reportSnapshot(ResourceSnapshot snapshot) async {
    // Offline-first: No Crashlytics reporting
  }
  
  /// Get current resource status
  Future<ResourceSnapshot> getCurrentStatus() async {
    return await _takeSnapshot();
  }
  
  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
}
