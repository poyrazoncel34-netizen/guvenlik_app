import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../app_colors.dart';

/// Centralized permission handling with user-friendly dialogs.
class PermissionHelper {
  PermissionHelper._();

  /// Request location permission with proper UX flow.
  /// Returns true if permission was granted.
  static Future<bool> requestLocationPermission(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.location_off_rounded,
        title: 'Konum Servisi Kapalı',
        message:
            'Acil durumlarda konumunuzu paylaşmak için konum servisini açmanız gerekiyor.',
        actionText: 'Ayarlara Git',
      );
      if (shouldOpen == true) {
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final shouldOpen = await _showDialog(
        context,
        icon: Icons.location_disabled_rounded,
        title: 'Konum İzni Reddedildi',
        message:
            'Konum izni kalıcı olarak reddedilmiş. Uygulamanın düzgün çalışması için lütfen ayarlardan konum iznini açın.',
        actionText: 'Ayarlara Git',
      );
      if (shouldOpen == true) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
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
      title: '$permissionName İzni Gerekli',
      message: reason,
      actionText: 'Ayarlara Git',
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
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: AppColors.textSecondary),
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
