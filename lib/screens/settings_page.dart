// ============================================================================
// AYARLAR SAYFASI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/app_colors.dart';
import '../core/services/activity_service.dart';
import '../domain/models/activity_event.dart';
import 'profile_page.dart';
import 'settings_detail_page.dart';
import '../presentation/providers/settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ayarlar"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile section
          _buildProfileSection(provider),
          const SizedBox(height: 28),

          // Security settings
          _buildSectionTitle("Güvenlik"),
          const SizedBox(height: 14),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.notifications_rounded,
              iconColor: AppColors.warning,
              title: "Bildirimler",
              subtitle: "Acil durum bildirimleri",
              value: provider.notificationsEnabled,
              onChanged: provider.setNotifications,
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.info,
              title: "Konum Servisi",
              subtitle: "Konum takibi aktif",
              value: provider.locationEnabled,
              onChanged: provider.setLocation,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.lock_rounded,
              iconColor: AppColors.primary,
              title: "PIN Ayarları",
              subtitle: "Güvenlik PIN'inizi değiştirin",
              onTap: () => _showPinSettings(context),
            ),
          ]),
          const SizedBox(height: 28),

          // Sound & Vibration
          _buildSectionTitle("Ses & Titreşim"),
          const SizedBox(height: 14),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.volume_up_rounded,
              iconColor: AppColors.success,
              title: "Ses Efektleri",
              subtitle: "Siren ve uyarı sesleri",
              value: provider.soundEnabled,
              onChanged: provider.setSound,
            ),
            _buildDivider(),
            _buildSwitchTile(
              icon: Icons.vibration_rounded,
              iconColor: AppColors.emergency,
              title: "Titreşim",
              subtitle: "Dokunsal geri bildirim",
              value: provider.vibrationEnabled,
              onChanged: provider.setVibration,
            ),
          ]),
          const SizedBox(height: 28),

          // About section
          _buildSectionTitle("Hakkında"),
          const SizedBox(height: 14),
          _buildSettingsCard([
            _buildNavigationTile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: "Uygulama Hakkında",
              subtitle: "Sürüm 1.0.0",
              onTap: () => _openDetail(context, "Uygulama Hakkında", Icons.info_outline_rounded),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.description_outlined,
              iconColor: AppColors.textSecondary,
              title: "Gizlilik Politikası",
              subtitle: "Verileriniz güvende",
              onTap: () => _openDetail(context, "Gizlilik Politikası", Icons.description_outlined),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: "Yardım & Destek",
              subtitle: "SSS ve iletişim",
              onTap: () => _openDetail(context, "Yardım & Destek", Icons.help_outline_rounded),
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
              label: const Text("Çıkış Yap", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                  "KoruBeni",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sürüm 1.0.0 (Build 1)",
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
                      style: TextStyle(
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

  void _openDetail(BuildContext context, String title, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsDetailPage(title: title, icon: icon)),
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
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              "PIN Ayarları",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Güvenliğiniz için PIN'inizi düzenli olarak güncelleyin.",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: oldController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Eski PIN",
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Yeni PIN (4 hane)",
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final secureStorage = serviceLocator<SecureStorage>();
                  final prefs = await SharedPreferences.getInstance();
                  // Load PIN from secure storage (no hardcoded fallback)
                  String? currentPin = await secureStorage.read(key: SecureStorageKeys.userPin);
                  // Legacy migration from SharedPreferences
                  if (currentPin == null || currentPin.isEmpty) {
                    final legacy = prefs.getString(SecureStorageKeys.userPin);
                    if (legacy != null && legacy.isNotEmpty) {
                      await secureStorage.write(key: SecureStorageKeys.userPin, value: legacy);
                      await prefs.remove(SecureStorageKeys.userPin);
                      currentPin = legacy;
                    }
                  }
                  if (!context.mounted) return;
                  if (currentPin == null || currentPin.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("PIN bulunamadı. Lütfen yeniden oluşturun."), backgroundColor: AppColors.warning),
                    );
                    return;
                  }
                  if (oldController.text != currentPin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Eski PIN yanlış"), backgroundColor: AppColors.emergency),
                    );
                    return;
                  }
                  if (newController.text.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("PIN 4 hane olmalıdır"), backgroundColor: AppColors.warning),
                    );
                    return;
                  }
                  await secureStorage.write(key: SecureStorageKeys.userPin, value: newController.text);
                  await prefs.remove(SecureStorageKeys.userPin);
                  await ActivityService.logEvent(
                    type: ActivityType.pinChanged,
                    title: "PIN Degistirildi",
                    description: "Guvenlik PIN'iniz basariyla guncellendi",
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("PIN güncellendi"), backgroundColor: AppColors.success),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Kaydet", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
            const Text(
              "Çıkış Yap",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              "Hesabınızdan çıkış yapmak istediğinizden emin misiniz?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
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
                    child: const Text("İptal", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white),
                              SizedBox(width: 12),
                              Text("Çıkış yapıldı", style: TextStyle(fontWeight: FontWeight.w600)),
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
                    child: const Text("Çıkış Yap", style: TextStyle(fontWeight: FontWeight.w700)),
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
