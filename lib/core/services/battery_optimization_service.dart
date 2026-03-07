// ============================================================================
// BATTERY OPTIMIZATION BYPASS SERVICE - Android Zero-Fault
// ============================================================================
// Ensures the app can run in background even during Doze Mode.
// Requests user to disable battery optimization for critical emergency app.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Battery optimization bypass service for Android
/// 
/// Critical for emergency apps - ensures background operation during Doze Mode
class BatteryOptimizationService {
  static final BatteryOptimizationService _instance = 
      BatteryOptimizationService._();
  static BatteryOptimizationService get instance => _instance;
  BatteryOptimizationService._();
  
  static const String _prefKeyAsked = 'battery_opt_asked';
  static const String _prefKeyDisabled = 'battery_opt_disabled';
  
  /// Check if battery optimization is disabled
  Future<bool> isOptimizationDisabled() async {
    if (!Platform.isAndroid) return true; // iOS doesn't need this
    
    try {
      final isIgnoring = await OptimizeBattery.isIgnoringBatteryOptimizations();
      debugPrint('🔋 Battery optimization disabled: $isIgnoring');
      
      // Cache result
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDisabled, isIgnoring);
      
      return isIgnoring;
    } catch (e) {
      debugPrint('Battery optimization check failed: $e');
      return false;
    }
  }
  
  /// Request to disable battery optimization
  /// Shows system dialog to user
  Future<bool> requestDisableOptimization() async {
    if (!Platform.isAndroid) return true;
    
    try {
      debugPrint('🔋 Requesting battery optimization disable...');
      
      // Mark that we asked
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyAsked, true);
      
      // Show system dialog
      await OptimizeBattery.stopOptimizingBatteryUsage();
      
      // Check if user granted
      await Future.delayed(Duration(seconds: 1));
      final isDisabled = await isOptimizationDisabled();
      
      if (isDisabled) {
        debugPrint('✅ Battery optimization disabled successfully');
      } else {
        debugPrint('❌ User denied battery optimization disable');
      }
      
      return isDisabled;
    } catch (e) {
      debugPrint('Battery optimization request failed: $e');
      return false;
    }
  }
  
  /// Check if we should show the request dialog
  /// Only ask once per install, or if user hasn't disabled it
  Future<bool> shouldShowRequest() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAsked = prefs.getBool(_prefKeyAsked) ?? false;
      
      // If already asked and user said no, don't ask again
      if (hasAsked) {
        final isDisabled = await isOptimizationDisabled();
        return !isDisabled; // Show again only if still not disabled
      }
      
      // First time - check current status
      final isDisabled = await isOptimizationDisabled();
      return !isDisabled; // Show if not disabled
    } catch (e) {
      debugPrint('shouldShowRequest check failed: $e');
      return false;
    }
  }
  
  /// Open system battery optimization settings
  Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      // Open system settings for this app
      const platform = MethodChannel('com.poyrazoncel.korubeni/settings');
      await platform.invokeMethod('openBatterySettings');
    } catch (e) {
      debugPrint('Failed to open battery settings: $e');
      // Fallback: try generic battery optimization request
      try {
        await OptimizeBattery.stopOptimizingBatteryUsage();
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
      }
    }
  }
  
  /// Get battery optimization status for Crashlytics
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'is_android': Platform.isAndroid,
      'optimization_disabled': await isOptimizationDisabled(),
      'has_asked_user': await _hasAskedUser(),
    };
  }
  
  Future<bool> _hasAskedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyAsked) ?? false;
    } catch (e) {
      return false;
    }
  }
}
