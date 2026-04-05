// ============================================================================
// AYARLAR SAYFASI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/widgets/theme_selector.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_reset_helper.dart';
import '../core/utils/pin_settings_helper.dart';
import 'legal_info_screen.dart';
import 'profile_page.dart';
import 'settings_detail_page.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/subscription_provider.dart';
import 'battery_optimization_wizard.dart';
import 'settings_legal/legal_settings_screen.dart';
import 'subscription/paywall_screen.dart';
import 'subscription/subscription_management_screen.dart';

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _rateApp() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.poyrazoncel.korubeni';
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
    final isPro = context.watch<SubscriptionProvider>().isPro;
    return Semantics(
      label: "semantics_settings_page".tr(),
      hint: "semantics_settings_page_hint".tr(),
      child: Scaffold(
        appBar: AppBar(title: Text("settings".tr())),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile section
            _buildProfileSection(provider),
            const SizedBox(height: 28),

            // KoruBeni Pro
            _buildSectionTitle('subscription_section_title'.tr()),
            const SizedBox(height: 14),
            _buildSettingsCard([
              _buildProTile(isPro),
            ]),
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
                      MaterialPageRoute(
                        builder: (_) => const BatteryOptimizationWizard(),
                      ),
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

            // Language
            _buildSectionTitle('settings_language_section'.tr()),
            const SizedBox(height: 14),
            _buildSettingsCard([
              _buildNavigationTile(
                icon: Icons.language_rounded,
                iconColor: AppColors.info,
                title: 'settings_language_title'.tr(),
                subtitle: context.locale.languageCode == 'tr'
                    ? 'Türkçe'
                    : 'English',
                onTap: () {
                  final currentLocale = context.locale;
                  final newLocale = currentLocale.languageCode == 'tr'
                      ? const Locale('en', 'US')
                      : const Locale('tr', 'TR');
                  final langName = newLocale.languageCode == 'tr'
                      ? 'Türkçe'
                      : 'English';
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('settings_language_confirm_title'.tr()),
                      content: Text('settings_language_confirm_body'.tr(
                        namedArgs: {'language': langName},
                      )),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('map_cancel'.tr()),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.setLocale(newLocale);
                          },
                          child: Text('confirm'.tr()),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 28),

            // Appearance / Theme
            _buildSectionTitle('settings_theme_section'.tr()),
            const SizedBox(height: 14),
            _buildSettingsCard([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings_theme_title'.tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ThemeSelector(
                      selected: provider.themeMode,
                      onChanged: provider.setThemeMode,
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 28),

            // SMS Template
            _buildSectionTitle('settings_sms_section'.tr()),
            const SizedBox(height: 14),
            _buildSettingsCard([
              _buildNavigationTile(
                icon: Icons.sms_rounded,
                iconColor: AppColors.accent,
                title: 'settings_sms_template_title'.tr(),
                subtitle: 'settings_sms_template_subtitle'.tr(),
                onTap: () => _showSmsTemplateDialog(context),
              ),
            ]),
            const SizedBox(height: 28),

            // Legal bilgiler
            _buildSectionTitle("settings_legal_section".tr()),
            const SizedBox(height: 14),
            _buildSettingsCard([
              _buildNavigationTile(
                icon: Icons.gavel_rounded,
                iconColor: AppColors.accent,
                title: "settings_legal_title".tr(),
                subtitle: "settings_legal_subtitle".tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalSettingsScreen(),
                    ),
                  );
                },
              ),
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
                    ? "settings_version".tr(
                        namedArgs: {
                          "version": _appVersion,
                          "build": _buildNumber,
                        },
                      )
                    : "...",
                onTap: () => _openDetail(
                  context,
                  "settings_about_app".tr(),
                  'settings_about_app',
                  Icons.info_outline_rounded,
                ),
              ),
              _buildDivider(),
              _buildNavigationTile(
                icon: Icons.description_outlined,
                iconColor: AppColors.textSecondary,
                title: "settings_privacy_policy".tr(),
                subtitle: "settings_privacy_subtitle".tr(),
                onTap: () => _openDetail(
                  context,
                  "settings_privacy_policy".tr(),
                  'settings_privacy_policy',
                  Icons.description_outlined,
                ),
              ),
              _buildDivider(),
              _buildNavigationTile(
                icon: Icons.open_in_browser_rounded,
                iconColor: AppColors.info,
                title: 'settings_privacy_web_title'.tr(),
                subtitle: 'settings_privacy_web_subtitle'.tr(),
                onTap: () async {
                  final uri = Uri.parse(AppConstants.privacyPolicyWebUrl);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              _buildDivider(),
              _buildNavigationTile(
                icon: Icons.balance_rounded,
                iconColor: const Color(0xFF9F7AEA),
                title: 'settings_legal_info_title'.tr(),
                subtitle: 'settings_legal_info_subtitle'.tr(),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalInfoScreen()),
                ),
              ),
              _buildDivider(),
              _buildNavigationTile(
                icon: Icons.help_outline_rounded,
                iconColor: AppColors.textSecondary,
                title: "settings_help".tr(),
                subtitle: "settings_help_subtitle".tr(),
                onTap: () => _openDetail(
                  context,
                  "settings_help".tr(),
                  'settings_help',
                  Icons.help_outline_rounded,
                ),
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
                label: Text(
                  "settings_logout".tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                        ? "settings_version".tr(
                            namedArgs: {
                              "version": _appVersion,
                              "build": _buildNumber,
                            },
                          )
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

  Widget _buildProTile(bool isPro) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isPro
                ? const SubscriptionManagementScreen()
                : const PaywallScreen(),
          ),
        ).then((_) {
          if (!mounted) return;
          context.read<SubscriptionProvider>().refresh();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPro
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: isPro ? AppColors.success : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'subscription_tile_title'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPro
                        ? 'subscription_tile_subtitle_pro'.tr()
                        : 'subscription_tile_subtitle_free'.tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isPro)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'subscription_badge_pro'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ).then((_) {
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
                child: const Icon(
                  Icons.person_rounded,
                  size: 36,
                  color: Colors.white,
                ),
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
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    String title,
    String sectionKey,
    IconData icon,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsDetailPage(
          title: title,
          sectionKey: sectionKey,
          icon: icon,
        ),
      ),
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
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
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
    AppResetHelper.showResetDialog(context);
  }

  void _showSmsTemplateDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pref_sms_template') ?? '';
    final controller = TextEditingController(text: saved);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'settings_sms_template_title'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'sms_template_hint'.tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'sms_template_placeholder'.tr(),
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await prefs.remove('pref_sms_template');
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('sms_template_reset'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await prefs.setString(
                          'pref_sms_template',
                          controller.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('save'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
