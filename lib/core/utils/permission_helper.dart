import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/consent_record.dart';
import '../services/consent_gate_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_colors.dart';
import '../services/app_settings_service.dart';
import '../services/battery_optimization_service.dart';

enum NotificationPermissionRequestStatus { granted, denied, permanentlyDenied }

/// Centralized permission handling with user-friendly dialogs.
/// Play Store Prominent Disclosure: Tehlikeli izinler (arka plan konum, pil optimizasyonu)
/// için izin istemeden ÖNCE kullanıcıya açık bilgilendirme gösterilir.
class PermissionHelper {
  PermissionHelper._();

  /// Request location permission with proper UX flow.
  /// Play Store: Prominent Disclosure - Native izin istemeden önce açık bilgilendirme.
  /// Returns true if permission was granted.
  static Future<bool> requestLocationPermission(BuildContext context) async {
    if (!ConsentGateService.requireConsent(
      context,
      ConsentRecord.typeLocation,
    )) {
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.location_off_rounded,
        title: 'perm_location_service_off'.tr(),
        message: 'perm_location_service_off_msg'.tr(),
        actionText: 'perm_go_settings'.tr(),
      );
      if (shouldOpen == true) {
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Prominent Disclosure: Arka plan konum için açık beyan - kullanıcı kabul etmezse native'e geçme
      if (!context.mounted) return false;
      final accepted = await _showProminentDisclosure(
        context,
        title: 'perm_location_prominent_title'.tr(),
        message: 'perm_location_prominent_msg'.tr(),
      );
      if (accepted != true) return false;

      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.location_disabled_rounded,
        title: 'perm_location_denied'.tr(),
        message: 'perm_location_denied_msg'.tr(),
        actionText: 'perm_go_settings'.tr(),
      );
      if (shouldOpen == true) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Pil optimizasyonu muafiyeti - Prominent Disclosure ile.
  /// Play Store: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS izni için önce açık beyan.
  /// Returns true only if Android accepted the settings intent. The caller
  /// must re-read the current exemption state after the app resumes.
  static Future<bool> requestBatteryOptimizationExemption(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid) return false;
    if (!context.mounted) return false;

    // Prominent Disclosure: Pil optimizasyonu için açık beyan
    final accepted = await _showProminentDisclosure(
      context,
      title: 'perm_battery_prominent_title'.tr(),
      message: 'perm_battery_prominent_msg'.tr(),
    );
    if (accepted != true) return false;

    try {
      return BatteryOptimizationService.instance.requestDisableOptimization();
    } catch (e) {
      return false;
    }
  }

  /// CALL_PHONE izni — Prominent Disclosure ile.
  /// Play Store: izin istemeden önce kullanıcıya neden gerektiği açıklanır.
  /// Returns true if permission is granted (or was already granted).
  static Future<bool> requestCallPhonePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.phone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) {
      if (!context.mounted) return false;
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.phone_disabled_rounded,
        title: 'perm_call_denied_title'.tr(),
        message: 'perm_call_denied_msg'.tr(),
        actionText: 'perm_go_settings'.tr(),
      );
      if (shouldOpen == true) {
        await openAppSettings();
      }
      return false;
    }

    if (!context.mounted) return false;
    final accepted = await _showProminentDisclosure(
      context,
      title: 'perm_call_prominent_title'.tr(),
      message: 'perm_call_prominent_msg'.tr(),
    );
    if (accepted != true) return false;

    final result = await Permission.phone.request();
    if (result.isPermanentlyDenied || result.isRestricted) {
      if (!context.mounted) return false;
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.phone_disabled_rounded,
        title: 'perm_call_denied_title'.tr(),
        message: 'perm_call_denied_msg'.tr(),
        actionText: 'perm_go_settings'.tr(),
      );
      if (shouldOpen == true) {
        await openAppSettings();
      }
    }
    return result.isGranted;
  }

  static Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  static Future<bool> requestNotificationPermission(
    BuildContext context,
  ) async {
    if (!await AppSettingsService.notificationsEnabled()) {
      return false;
    }

    if (await hasNotificationPermission()) {
      return true;
    }
    if (!context.mounted) return false;

    final accepted = await _showProminentDisclosure(
      context,
      title: 'perm_notifications_prominent_title'.tr(),
      message: 'perm_notifications_prominent_msg'.tr(),
    );
    if (accepted != true) return false;

    final result = await Permission.notification.request();
    if (result.isGranted || result.isLimited || result.isProvisional) {
      return true;
    }

    if (result.isPermanentlyDenied && context.mounted) {
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.notifications_off_rounded,
        title: 'perm_notifications_denied'.tr(),
        message: 'perm_notifications_denied_msg'.tr(),
        actionText: 'perm_go_settings'.tr(),
      );
      if (shouldOpen == true) {
        await openNotificationSettings();
      }
    }

    return false;
  }

  static Future<NotificationPermissionRequestStatus>
  requestNotificationPermissionForScheduledAction(BuildContext context) async {
    if (!await AppSettingsService.notificationsEnabled()) {
      return NotificationPermissionRequestStatus.denied;
    }

    if (await hasNotificationPermission()) {
      return NotificationPermissionRequestStatus.granted;
    }
    if (!context.mounted) {
      return NotificationPermissionRequestStatus.denied;
    }

    final accepted = await _showProminentDisclosure(
      context,
      title: 'perm_notifications_prominent_title'.tr(),
      message: 'perm_notifications_prominent_msg'.tr(),
    );
    if (accepted != true) {
      final status = await Permission.notification.status;
      return status.isPermanentlyDenied
          ? NotificationPermissionRequestStatus.permanentlyDenied
          : NotificationPermissionRequestStatus.denied;
    }

    final result = await Permission.notification.request();
    if (result.isGranted || result.isLimited || result.isProvisional) {
      return NotificationPermissionRequestStatus.granted;
    }
    return result.isPermanentlyDenied
        ? NotificationPermissionRequestStatus.permanentlyDenied
        : NotificationPermissionRequestStatus.denied;
  }

  /// Open the system notification settings page for KoruBeni.
  ///
  /// On Android 8.0+ this deep-links directly into the app's
  /// notification settings (ACTION_APP_NOTIFICATION_SETTINGS via
  /// the native settings channel). On older Android versions and on
  /// iOS we fall back to the generic app settings page provided by
  /// `permission_handler`.
  static Future<bool> openNotificationSettings() async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.poyrazoncel.korubeni/settings');
        final ok = await channel.invokeMethod<bool>('openNotificationSettings');
        if (ok == true) return true;
      } on PlatformException {
        // Native handler missing or settings screen unavailable —
        // fall through to the generic settings deep link below.
      }
    }
    return openAppSettings();
  }

  /// Play Store Prominent Disclosure: İzin istemeden önce gösterilen bilgilendirme.
  /// Kullanıcı "Kabul Et" demezse native izin adımına geçilmez.
  static Future<bool?> _showProminentDisclosure(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Semantics(
        label: '$title. $message',
        child: AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.info,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'perm_cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Semantics(
              label: 'perm_accept'.tr(),
              button: true,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('perm_accept'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a generic "go to settings" dialog for any permission.
  static Future<bool> showPermissionDeniedDialog(
    BuildContext context, {
    required String permissionName,
    required String reason,
  }) async {
    final result = await _showDialog(
      context,
      icon: Icons.block_rounded,
      title: 'perm_required'.tr(namedArgs: {'name': permissionName}),
      message: reason,
      actionText: 'perm_go_settings'.tr(),
    );
    if (result == true) {
      await Geolocator.openAppSettings();
      return true;
    }
    return false;
  }

  static Future<bool?> _showDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String actionText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Semantics(
        label: '$title. $message',
        child: AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.warning, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'perm_cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Semantics(
              label: actionText,
              button: true,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
