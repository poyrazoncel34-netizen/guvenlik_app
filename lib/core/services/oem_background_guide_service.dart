// ============================================================================
// OEM BACKGROUND GUIDE SERVICE
// ============================================================================
// The number one cause of silent failure in this category is a
// manufacturer-specific battery policy killing the app, on top of standard
// Android Doze. The app already had the mechanism (BatteryOptimizationService,
// the native exemption request) and a generic wizard screen, but nothing that
// took the user to the OEM screen that actually matters.
//
// What was there before and why it did nothing:
//   BatteryOptimizationService.isAggressiveManufacturer() read a cached
//   manufacturer string, and cacheManufacturer() had zero callers -- so it
//   always returned false. Dead code pretending to be a feature.
//   openManufacturerSettings() knew four vendors (xiaomi/samsung/huawei/
//   oneplus), with no vivo/oppo/realme/honor/POCO and no per-step granularity.
//
// This service owns the vendor mapping, the per-vendor step list, step
// execution and the durable completion record. It is deliberately not the
// screen: the mapping and the persistence are the parts that need tests, and a
// device without the target intent must degrade to instructions, never crash.
//
// No new permission and no new dependency: Build.MANUFACTURER needs neither,
// and the per-step intents reuse the settings channel MainActivity already
// exposes (openActivityByComponent).
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_optimization_service.dart';

/// Vendor families that share one settings layout. Grouped by the screen the
/// user must reach, not by brand: POCO/Redmi are MIUI, Honor is EMUI, and
/// Realme/OnePlus ship ColorOS-derived builds.
enum OemVendor { xiaomi, huawei, samsung, oppoFamily, vivo, generic }

/// A system screen a step can open without a component name.
enum OemSystemAction { batteryExemption, batterySettings, notificationSettings }

/// What happened when a step tried to open its target.
enum OemStepLaunch {
  /// The target screen was opened; the user acts there and comes back.
  opened,

  /// This device has no such screen. The step text is the fallback, and the
  /// step stays skippable -- this must never be a dead end.
  noIntent,
}

/// One instruction in a vendor's guide.
@immutable
class OemGuideStep {
  const OemGuideStep({
    required this.id,
    required this.titleKey,
    required this.bodyKey,
    this.component,
    this.systemAction,
  });

  /// Stable identifier for the completion record. Never renumber: a changed id
  /// silently resets a user's progress.
  final String id;
  final String titleKey;
  final String bodyKey;

  /// `package/class` of an OEM activity, when the vendor has one.
  final String? component;

  /// A framework-provided screen, when no component is needed.
  final OemSystemAction? systemAction;

  bool get hasTarget => component != null || systemAction != null;
}

abstract final class OemBackgroundGuideService {
  static const MethodChannel _settingsChannel = MethodChannel(
    'com.poyrazoncel.korubeni/settings',
  );

  static const String _completedKeyPrefix = 'oem_guide_completed_v1_';
  static const String _stepsKeyPrefix = 'oem_guide_steps_v1_';

  // ---------------------------------------------------------------------------
  // Vendor resolution
  // ---------------------------------------------------------------------------

  /// Maps a raw Build.MANUFACTURER value to its settings family.
  /// Pure and case-insensitive so it can be tested without a device.
  static OemVendor vendorFrom(String manufacturer) {
    final m = manufacturer.toLowerCase().trim();
    if (m.isEmpty) return OemVendor.generic;
    if (m.contains('xiaomi') ||
        m.contains('redmi') ||
        m.contains('poco') ||
        m.contains('blackshark')) {
      return OemVendor.xiaomi;
    }
    if (m.contains('huawei') || m.contains('honor')) return OemVendor.huawei;
    if (m.contains('samsung')) return OemVendor.samsung;
    if (m.contains('oppo') ||
        m.contains('realme') ||
        m.contains('oneplus')) {
      return OemVendor.oppoFamily;
    }
    if (m.contains('vivo') || m.contains('iqoo')) return OemVendor.vivo;
    return OemVendor.generic;
  }

  /// Reads Build.MANUFACTURER through the existing settings channel.
  /// Falls back to [OemVendor.generic] on any platform failure, which yields a
  /// guide that is text plus the framework battery screens -- still useful.
  static Future<OemVendor> detectVendor() async {
    if (!Platform.isAndroid) return OemVendor.generic;
    try {
      final raw = await _settingsChannel.invokeMethod<String>(
        'getDeviceManufacturer',
      );
      final vendor = vendorFrom(raw ?? '');
      // Keep the legacy cache honest: isAggressiveManufacturer() reads it and
      // was permanently false because nothing ever populated it.
      if (raw != null && raw.isNotEmpty) {
        await BatteryOptimizationService.cacheManufacturer(raw);
      }
      return vendor;
    } on PlatformException catch (e) {
      debugPrint('OemBackgroundGuide: manufacturer read failed: ${e.code}');
      return OemVendor.generic;
    } on MissingPluginException {
      debugPrint('OemBackgroundGuide: settings channel unavailable');
      return OemVendor.generic;
    }
  }

  // ---------------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------------

  /// The guide for [vendor]. Always non-empty: every vendor gets the standard
  /// Android exemption step, so `generic` is a real guide rather than a
  /// dead screen.
  static List<OemGuideStep> stepsFor(OemVendor vendor) {
    return List<OemGuideStep>.unmodifiable(<OemGuideStep>[
      const OemGuideStep(
        id: 'battery_exemption',
        titleKey: 'oem_step_exemption_title',
        bodyKey: 'oem_step_exemption_body',
        systemAction: OemSystemAction.batteryExemption,
      ),
      ..._vendorSteps(vendor),
      const OemGuideStep(
        id: 'notifications',
        titleKey: 'oem_step_notifications_title',
        bodyKey: 'oem_step_notifications_body',
        systemAction: OemSystemAction.notificationSettings,
      ),
    ]);
  }

  static List<OemGuideStep> _vendorSteps(OemVendor vendor) {
    switch (vendor) {
      case OemVendor.xiaomi:
        return const <OemGuideStep>[
          OemGuideStep(
            id: 'xiaomi_autostart',
            titleKey: 'oem_step_xiaomi_autostart_title',
            bodyKey: 'oem_step_xiaomi_autostart_body',
            component:
                'com.miui.securitycenter/'
                'com.miui.permcenter.autostart.AutoStartManagementActivity',
          ),
          OemGuideStep(
            id: 'xiaomi_battery_saver',
            titleKey: 'oem_step_xiaomi_saver_title',
            bodyKey: 'oem_step_xiaomi_saver_body',
            component:
                'com.miui.powerkeeper/'
                'com.miui.powerkeeper.ui.HiddenAppsConfigActivity',
          ),
        ];
      case OemVendor.huawei:
        return const <OemGuideStep>[
          OemGuideStep(
            id: 'huawei_protected',
            titleKey: 'oem_step_huawei_protected_title',
            bodyKey: 'oem_step_huawei_protected_body',
            component:
                'com.huawei.systemmanager/'
                'com.huawei.systemmanager.optimize.process.ProtectActivity',
          ),
          OemGuideStep(
            id: 'huawei_startup',
            titleKey: 'oem_step_huawei_startup_title',
            bodyKey: 'oem_step_huawei_startup_body',
            component:
                'com.huawei.systemmanager/'
                'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
          ),
        ];
      case OemVendor.samsung:
        return const <OemGuideStep>[
          OemGuideStep(
            id: 'samsung_sleeping_apps',
            titleKey: 'oem_step_samsung_sleeping_title',
            bodyKey: 'oem_step_samsung_sleeping_body',
            component:
                'com.samsung.android.lool/'
                'com.samsung.android.sm.ui.battery.BatteryActivity',
          ),
        ];
      case OemVendor.oppoFamily:
        return const <OemGuideStep>[
          OemGuideStep(
            id: 'oppo_startup',
            titleKey: 'oem_step_oppo_startup_title',
            bodyKey: 'oem_step_oppo_startup_body',
            component:
                'com.coloros.safecenter/'
                'com.coloros.safecenter.permission.startup.StartupAppListActivity',
          ),
          OemGuideStep(
            id: 'oppo_battery',
            titleKey: 'oem_step_oppo_battery_title',
            bodyKey: 'oem_step_oppo_battery_body',
            component:
                'com.coloros.oppoguardelf/'
                'com.coloros.powermanager.fuelgaue.PowerUsageModelActivity',
          ),
        ];
      case OemVendor.vivo:
        return const <OemGuideStep>[
          OemGuideStep(
            id: 'vivo_background',
            titleKey: 'oem_step_vivo_background_title',
            bodyKey: 'oem_step_vivo_background_body',
            component:
                'com.vivo.permissionmanager/'
                'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
          ),
        ];
      case OemVendor.generic:
        return const <OemGuideStep>[
          OemGuideStep(
            id: 'generic_battery_list',
            titleKey: 'oem_step_generic_battery_title',
            bodyKey: 'oem_step_generic_battery_body',
            systemAction: OemSystemAction.batterySettings,
          ),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // Step execution
  // ---------------------------------------------------------------------------

  /// Tries to open [step]'s target screen.
  ///
  /// Returns [OemStepLaunch.noIntent] when the device has no such activity --
  /// the common case for a component borrowed from another OEM's ROM version.
  /// The caller shows the step text instead; nothing throws.
  static Future<OemStepLaunch> openStep(OemGuideStep step) async {
    final component = step.component;
    if (component != null) {
      if (await _openComponent(component)) return OemStepLaunch.opened;
      // A renamed or absent OEM activity is expected, not exceptional. Fall
      // through to the framework battery screen so the step still leads
      // somewhere useful.
      return await _openSystemAction(OemSystemAction.batterySettings)
          ? OemStepLaunch.opened
          : OemStepLaunch.noIntent;
    }
    final action = step.systemAction;
    if (action == null) return OemStepLaunch.noIntent;
    return await _openSystemAction(action)
        ? OemStepLaunch.opened
        : OemStepLaunch.noIntent;
  }

  static Future<bool> _openComponent(String component) async {
    if (!Platform.isAndroid) return false;
    try {
      final opened = await _settingsChannel.invokeMethod<bool>(
        'openActivityByComponent',
        <String, Object?>{'component': component},
      );
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('OemBackgroundGuide: component not available: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> _openSystemAction(OemSystemAction action) async {
    try {
      switch (action) {
        case OemSystemAction.batteryExemption:
          return await BatteryOptimizationService.instance
              .requestDisableOptimization();
        case OemSystemAction.batterySettings:
          return await BatteryOptimizationService.instance
              .openBatterySettings();
        case OemSystemAction.notificationSettings:
          final opened = await _settingsChannel.invokeMethod<bool>(
            'openNotificationSettings',
          );
          return opened ?? false;
      }
    } on PlatformException catch (e) {
      debugPrint('OemBackgroundGuide: system screen failed: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Durable progress
  // ---------------------------------------------------------------------------

  /// Step ids the user marked done for [vendor]. Survives a restart; that is
  /// the acceptance criterion for this flow.
  static Future<Set<String>> completedSteps(OemVendor vendor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList('$_stepsKeyPrefix${vendor.name}') ??
              const <String>[])
          .toSet();
    } on Exception catch (e) {
      debugPrint('OemBackgroundGuide: progress read failed: $e');
      return <String>{};
    }
  }

  /// Records a step as done. Skipping is not completing, so the caller must
  /// not route a skip through here.
  static Future<void> markStepCompleted(
    OemVendor vendor, {
    required String stepId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_stepsKeyPrefix${vendor.name}';
      final current =
          (prefs.getStringList(key) ?? const <String>[]).toSet()..add(stepId);
      await prefs.setStringList(key, current.toList(growable: false)..sort());
    } on Exception catch (e) {
      debugPrint('OemBackgroundGuide: progress write failed: $e');
    }
  }

  /// Marks the guide finished for [vendor] so the entry point can show a done
  /// state and stop nagging, while staying re-openable from settings.
  static Future<void> markGuideCompleted(OemVendor vendor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_completedKeyPrefix${vendor.name}', true);
    } on Exception catch (e) {
      debugPrint('OemBackgroundGuide: completion write failed: $e');
    }
  }

  static Future<bool> isGuideCompleted(OemVendor vendor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_completedKeyPrefix${vendor.name}') ?? false;
    } on Exception catch (e) {
      debugPrint('OemBackgroundGuide: completion read failed: $e');
      return false;
    }
  }

  // No clearProgress(): KVKK data deletion goes through AppResetService, which
  // calls SharedPreferences.clear() and therefore already removes both records.
  // A per-vendor clear would be an unused second path to the same state -- the
  // exact shape of dead code this service was written to replace.
}
