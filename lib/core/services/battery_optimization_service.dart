// ============================================================================
// BATTERY OPTIMIZATION GUIDANCE SERVICE
// ============================================================================
// Offers an optional reliability improvement for active safety sessions.
// If the user declines or Android/OEM policy still restricts background work,
// the app must continue in degraded mode without guarantee language.
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Battery optimization guidance service for Android.
///
/// This improves reliability on some devices, but it does not guarantee
/// background operation during Doze or OEM battery restrictions.
class BatteryOptimizationService {
  static final BatteryOptimizationService _instance =
      BatteryOptimizationService._();
  static BatteryOptimizationService get instance => _instance;
  BatteryOptimizationService._();

  static const String _prefKeyAsked = 'battery_opt_asked';
  static const String _prefKeyDisabled = 'battery_opt_disabled';

  /// Check if battery optimization is disabled.
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

  /// Request optional battery optimization exemption.
  /// Shows a system dialog/settings screen and returns false if the user
  /// declines or the platform refuses the request.
  Future<bool> requestDisableOptimization() async {
    if (!Platform.isAndroid) return true;

    try {
      debugPrint('🔋 Requesting optional battery optimization exemption...');

      // Mark that we asked
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyAsked, true);

      // Show system dialog
      await OptimizeBattery.stopOptimizingBatteryUsage();

      // Check if user granted
      await Future.delayed(const Duration(seconds: 1));
      final isDisabled = await isOptimizationDisabled();

      if (isDisabled) {
        debugPrint('✅ Battery optimization exemption granted');
      } else {
        debugPrint('❌ Battery optimization exemption not granted');
      }

      return isDisabled;
    } catch (e) {
      debugPrint('Battery optimization request failed: $e');
      return false;
    }
  }

  /// Check if we should show the optional request dialog.
  /// A refusal must leave the app in degraded mode rather than blocking use.
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

  /// Get battery optimization status (local only)
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'is_android': Platform.isAndroid,
      'optimization_disabled': await isOptimizationDisabled(),
      'has_asked_user': await _hasAskedUser(),
    };
  }

  /// Returns true if this device manufacturer is known to apply aggressive
  /// battery kill policies on top of standard Android Doze mode.
  /// When true, call [openManufacturerBatterySettings] after the standard
  /// Doze whitelist request.
  static bool isAggressiveManufacturer() {
    try {
      // Build.MANUFACTURER is not available in pure Dart — we pass it in via
      // a MethodChannel or store it at first launch. Here we use the cached
      // preference set by [cacheManufacturer].
      // Comparison is lower-cased for safety.
      final m = _cachedManufacturer.toLowerCase();
      return m.contains('xiaomi') ||
          m.contains('huawei') ||
          m.contains('honor') ||
          m.contains('oppo') ||
          m.contains('vivo') ||
          m.contains('oneplus') ||
          m.contains('realme') ||
          m.contains('samsung');
    } catch (_) {
      return false;
    }
  }

  static String _cachedManufacturer = '';
  static const String _prefKeyManufacturer = 'device_manufacturer';

  /// Call once at startup with the device manufacturer string from
  /// device_info_plus or a MethodChannel.
  static Future<void> cacheManufacturer(String manufacturer) async {
    _cachedManufacturer = manufacturer;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyManufacturer, manufacturer);
    } catch (e) {
      debugPrint('cacheManufacturer failed: $e');
    }
  }

  /// Load cached manufacturer from prefs (survives hot-restart).
  static Future<void> loadCachedManufacturer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedManufacturer = prefs.getString(_prefKeyManufacturer) ?? '';
    } catch (e) {
      debugPrint('loadCachedManufacturer failed: $e');
    }
  }

  /// Opens the manufacturer-specific auto-start / protected-apps settings
  /// screen for known aggressive manufacturers.
  /// Falls back to standard battery settings on unknown OEMs.
  Future<void> openManufacturerBatterySettings() async {
    if (!Platform.isAndroid) return;
    final m = _cachedManufacturer.toLowerCase();
    try {
      const platform = MethodChannel('com.poyrazoncel.korubeni/settings');
      String? intent;
      if (m.contains('xiaomi')) {
        intent = 'com.miui.securitycenter/.MainActivity';
      } else if (m.contains('huawei') || m.contains('honor')) {
        intent =
            'com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity';
      } else if (m.contains('oppo')) {
        intent = 'com.coloros.safecenter/.startupapp.StartupAppListActivity';
      } else if (m.contains('vivo')) {
        intent =
            'com.vivo.permissionmanager/.activity.BgStartUpManagerActivity';
      } else if (m.contains('oneplus')) {
        intent = 'com.oneplus.security/.autostart.AutoStartActivity';
      } else if (m.contains('realme')) {
        intent = 'com.coloros.safecenter/.startupapp.StartupAppListActivity';
      } else if (m.contains('samsung')) {
        intent = 'com.samsung.android.lool/.DeviceHealthMonitorMainActivity';
      }
      if (intent != null) {
        await platform.invokeMethod('openActivityByComponent', {
          'component': intent,
        });
        return;
      }
    } catch (_) {
      // Fall through to generic settings
    }
    // Generic fallback: standard battery settings
    await openBatterySettings();
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
