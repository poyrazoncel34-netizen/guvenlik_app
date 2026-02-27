// ============================================================================
// AYARLAR SAYFASI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/utils/pin_settings_helper.dart';
import 'profile_page.dart';
import 'settings_detail_page.dart';
import '../presentation/providers/settings_provider.dart';
import 'battery_optimization_wizard.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadProfile();
    });
  }

  Future<void> _loadVersionInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  Future<void> _shareApp() async {
    final shareText = defaultTargetPlatform == TargetPlatform.iOS
        ? 'settings_share_text_ios'.tr()
        : 'settings_share_text'.tr();
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': shareText},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: shareText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('link_copied'.tr()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _rateApp() async {
    final url = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/id6738228832'
        : 'https://play.google.com/store/apps/details?id=com.poyrazoncel.korubeni';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open store: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    return Semantics(
      label: "semantics_settings_page".tr(),
      hint: "semantics_settings_page_hint".tr(),
      child: Scaffold(
      appBar: AppBar(
        title: Text("settings".tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile section
          _buildProfileSection(provider),
          const SizedBox(height: 28),

          // Security settings
          _buildSectionTitle("settings_security".tr()),
          const SizedBox(height: 14),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.notifications_rounded,
              iconColor: AppColors.warning,
              title: "settings_notifications_title".tr(),
              subtitle: "settings_notifications_subtitle".tr(),
              value: provider.notificationsEnabled,
              onChanged: provider.setNotifications,
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.info,
              title: "settings_location_title".tr(),
              subtitle: "settings_location_subtitle".tr(),
              value: provider.locationEnabled,
              onChanged: provider.setLocation,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.lock_rounded,
              iconColor: AppColors.primary,
              title: "settings_pin_title".tr(),
              subtitle: "settings_pin_subtitle".tr(),
              onTap: () => _showPinSettings(context),
            ),
          ]),
          const SizedBox(height: 28),

          // Battery Optimization (Android only)
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            _buildSectionTitle("battery_wizard_title".tr()),
            const SizedBox(height: 14),
            _buildSettingsCard([
              _buildNavigationTile(
                icon: Icons.battery_saver_rounded,
                iconColor: AppColors.warning,
                title: "settings_battery_title".tr(),
                subtitle: "settings_battery_subtitle".tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BatteryOptimizationWizard()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 28),
          ],

          // Sound & Vibration
          _buildSectionTitle("settings_sound_vibration".tr()),
          const SizedBox(height: 14),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.volume_up_rounded,
              iconColor: AppColors.success,
              title: "settings_sound_title".tr(),
              subtitle: "settings_sound_subtitle".tr(),
              value: provider.soundEnabled,
              onChanged: provider.setSound,
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.vibration_rounded,
              iconColor: AppColors.emergency,
              title: "settings_vibration_title".tr(),
              subtitle: "settings_vibration_subtitle".tr(),
              value: provider.vibrationEnabled,
              onChanged: provider.setVibration,
            ),
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.volume_down_rounded,
                iconColor: AppColors.primary,
                title: "settings_volume_trigger_title".tr(),
                subtitle: "settings_volume_trigger_subtitle".tr(),
                value: provider.volumeTriggerEnabled,
                onChanged: provider.setVolumeTrigger,
              ),
            ],
          ]),
          const SizedBox(height: 28),

          // About section
          _buildSectionTitle("settings_about".tr()),
          const SizedBox(height: 14),
          _buildSettingsCard([
            _buildNavigationTile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: "settings_about_app".tr(),
              subtitle: _appVersion.isNotEmpty
                  ? "settings_version".tr(namedArgs: {"version": _appVersion, "build": _buildNumber})
                  : "...",
              onTap: () => _openDetail(context, "settings_about_app".tr(), 'settings_about_app', Icons.info_outline_rounded),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.description_outlined,
              iconColor: AppColors.textSecondary,
              title: "settings_privacy_policy".tr(),
              subtitle: "settings_privacy_subtitle".tr(),
              onTap: () => _openDetail(context, "settings_privacy_policy".tr(), 'settings_privacy_policy', Icons.description_outlined),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: "settings_help".tr(),
              subtitle: "settings_help_subtitle".tr(),
              onTap: () => _openDetail(context, "settings_help".tr(), 'settings_help', Icons.help_outline_rounded),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.share_rounded,
              iconColor: AppColors.accent,
              title: "settings_share_app".tr(),
              subtitle: "settings_share_subtitle".tr(),
              onTap: _shareApp,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.star_rounded,
              iconColor: AppColors.warning,
              title: "settings_rate_app".tr(),
              subtitle: "settings_rate_subtitle".tr(),
              onTap: _rateApp,
            ),
          ]),
          const SizedBox(height: 28),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showLogoutDialog(context);
              },
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: Text("settings_logout".tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Version info
          Center(
            child: Column(
              children: [
                Text(
                  "app_name".tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _appVersion.isNotEmpty
                      ? "settings_version".tr(namedArgs: {"version": _appVersion, "build": _buildNumber})
                      : "...",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
    );
  }

  Widget _buildProfileSection(SettingsProvider provider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          final settingsProvider = context.read<SettingsProvider>();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) {
            if (!mounted) return;
            settingsProvider.loadProfile();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.profileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.profileEmail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String title, String sectionKey, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsDetailPage(title: title, sectionKey: sectionKey, icon: icon)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border.withValues(alpha: 0.5),
      indent: 60,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                onChanged(val);
              },
              activeThumbColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
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
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinSettings(BuildContext context) {
    PinSettingsHelper.showPinChangeSheet(context);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.emergency.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, size: 36, color: AppColors.emergency),
            ),
            const SizedBox(height: 24),
            Text(
              "settings_logout".tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              "settings_logout_confirm".tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("settings_cancel".tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await FirebaseAuth.instance.signOut();
                      } catch (_) {}
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white),
                              const SizedBox(width: 12),
                              Text("settings_logout_success".tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("settings_logout".tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
