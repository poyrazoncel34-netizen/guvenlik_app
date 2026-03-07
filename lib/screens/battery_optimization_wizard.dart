// ============================================================================
// PİL OPTİMİZASYONU KURULUM SİHİRBAZI
// ============================================================================
// Xiaomi, Samsung, Huawei, Oppo gibi üreticilerin agresif pil yönetimini
// devre dışı bırakması için kullanıcıyı yönlendirir.
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'package:easy_localization/easy_localization.dart';

import '../core/app_colors.dart';
import '../core/utils/permission_helper.dart';

/// Key for battery optimization wizard seen flag
const String _kBatteryWizardSeenKey = 'battery_optimization_wizard_seen';

class BatteryOptimizationWizard extends StatefulWidget {
  /// Eğer true ise, ilk açılış kontrolü yapılır.
  /// false ise direkt gösterilir (ayarlardan açılma).
  final bool checkFirstLaunch;

  const BatteryOptimizationWizard({super.key, this.checkFirstLaunch = false});

  /// İlk açılışta wizard'ı göstermeli mi kontrol eder
  static Future<bool> shouldShow() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kBatteryWizardSeenKey) ?? false);
  }

  /// Wizard'ı gösterildi olarak işaretle
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBatteryWizardSeenKey, true);
  }

  @override
  State<BatteryOptimizationWizard> createState() =>
      _BatteryOptimizationWizardState();
}

class _BatteryOptimizationWizardState extends State<BatteryOptimizationWizard> {
  bool _isOptimizationDisabled = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!Platform.isAndroid) return;
    try {
      final isIgnoring =
          await OptimizeBattery.isIgnoringBatteryOptimizations();
      if (mounted) {
        setState(() => _isOptimizationDisabled = isIgnoring);
      }
    } catch (_) {}
  }

  /// Pil kısıtlamasını kaldır - PermissionHelper ile Prominent Disclosure önce gösterilir.
  Future<void> _requestDisableOptimization(BuildContext context) async {
    if (!mounted) return;
    try {
      final success = await PermissionHelper.requestBatteryOptimizationExemption(
        context,
      );
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _checkStatus();
      }
    } catch (e) {
      debugPrint('Battery optimization request failed: $e');
    }
  }

  Future<void> _openBatterySettings() async {
    try {
      // Android'in pil ayarları sayfasını aç
      const channel = MethodChannel('com.poyrazoncel.korubeni/settings');
      await channel.invokeMethod('openBatterySettings');
    } catch (_) {
      // Fallback: genel ayarları aç
      try {
        await OptimizeBattery.openBatteryOptimizationSettings();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('battery_wizard_title'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Hero icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isOptimizationDisabled
                                ? [AppColors.success, AppColors.accent]
                                : [AppColors.warning, AppColors.emergency],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isOptimizationDisabled
                                      ? AppColors.success
                                      : AppColors.warning)
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isOptimizationDisabled
                              ? Icons.check_circle_rounded
                              : Icons.battery_alert_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      Text(
                        _isOptimizationDisabled
                            ? 'battery_wizard_done_title'.tr()
                            : 'battery_wizard_header'.tr(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        _isOptimizationDisabled
                            ? 'battery_wizard_done_desc'.tr()
                            : 'battery_wizard_desc'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      if (!_isOptimizationDisabled) ...[
                        // Warning card
                        _buildWarningCard(
                          icon: Icons.warning_amber_rounded,
                          title: 'battery_wizard_why_title'.tr(),
                          description: 'battery_wizard_why_desc'.tr(),
                        ),
                        const SizedBox(height: 16),

                        // Brand-specific info
                        _buildInfoCard(
                          icon: Icons.phone_android_rounded,
                          title: 'battery_wizard_brands_title'.tr(),
                          description: 'battery_wizard_brands_desc'.tr(),
                        ),
                        const SizedBox(height: 16),

                        // Steps card
                        _buildStepsCard(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              if (!_isOptimizationDisabled) ...[
                // Primary: Disable battery optimization
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _requestDisableOptimization(context);
                    },
                    icon: const Icon(Icons.battery_saver_rounded, size: 22),
                    label: Text(
                      'battery_wizard_disable_btn'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary: Open battery settings (for brand-specific)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _openBatterySettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 20),
                    label: Text(
                      'battery_wizard_settings_btn'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Skip
                TextButton(
                  onPressed: () async {
                    await BatteryOptimizationWizard.markAsSeen();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text(
                    'battery_wizard_skip'.tr(),
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else ...[
                // Already disabled — done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await BatteryOptimizationWizard.markAsSeen();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: Text(
                      'battery_wizard_done_btn'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'battery_wizard_steps_title'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildStep(1, 'battery_wizard_step1'.tr()),
          _buildStep(2, 'battery_wizard_step2'.tr()),
          _buildStep(3, 'battery_wizard_step3'.tr()),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
