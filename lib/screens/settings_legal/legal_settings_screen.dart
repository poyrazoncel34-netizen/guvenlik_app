// ============================================================================
// YASAL BİLGİLER AYARLAR EKRANI
// Ayarlar > Yasal Bilgiler menüsü
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../screens/legal/terms_of_service_screen.dart';
import '../../screens/legal/kvkk_disclosure_screen.dart';
import '../../screens/legal/consent_management_screen.dart';
import 'data_export_screen.dart';
import 'data_deletion_screen.dart';

class LegalSettingsScreen extends StatelessWidget {
  const LegalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'legal_settings_title'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Belgeler ──────────────────────────────────────────────────────
          _buildSectionTitle('legal_settings_section_documents'.tr()),
          const SizedBox(height: 12),
          _buildCard([
            _buildTile(
              context,
              icon: Icons.description_rounded,
              color: AppColors.primary,
              titleKey: 'legal_tos_title',
              subtitleKey: 'legal_settings_tos_subtitle',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsOfServiceScreen(isReadOnly: true),
                ),
              ),
            ),
            _buildDivider(),
            _buildTile(
              context,
              icon: Icons.verified_user_rounded,
              color: AppColors.accent,
              titleKey: 'legal_kvkk_title',
              subtitleKey: 'legal_settings_kvkk_subtitle',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const KvkkDisclosureScreen(isReadOnly: true),
                ),
              ),
            ),
            _buildDivider(),
            _buildTile(
              context,
              icon: Icons.open_in_browser_rounded,
              color: AppColors.info,
              titleKey: 'legal_settings_privacy_web',
              subtitleKey: 'legal_settings_privacy_web_subtitle',
              onTap: () async {
                final uri = Uri.parse(AppConstants.privacyPolicyUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
          ]),

          const SizedBox(height: 24),

          // ── Veri Hakları ──────────────────────────────────────────────────
          _buildSectionTitle('legal_settings_section_data_rights'.tr()),
          const SizedBox(height: 12),
          _buildCard([
            _buildTile(
              context,
              icon: Icons.manage_accounts_rounded,
              color: AppColors.warning,
              titleKey: 'consent_mgmt_title',
              subtitleKey: 'legal_settings_consent_subtitle',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConsentManagementScreen(),
                ),
              ),
            ),
            _buildDivider(),
            _buildTile(
              context,
              icon: Icons.download_rounded,
              color: AppColors.success,
              titleKey: 'data_export_title',
              subtitleKey: 'legal_settings_export_subtitle',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DataExportScreen(),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Tehlikeli İşlemler ────────────────────────────────────────────
          _buildSectionTitle('legal_settings_section_danger'.tr()),
          const SizedBox(height: 12),
          _buildCard([
            _buildTile(
              context,
              icon: Icons.delete_forever_rounded,
              color: AppColors.emergency,
              titleKey: 'data_delete_title',
              subtitleKey: 'legal_settings_delete_subtitle',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DataDeletionScreen(),
                ),
              ),
              isDanger: true,
            ),
          ]),

          const SizedBox(height: 24),

          // ── KVKK Başvuru ──────────────────────────────────────────────────
          _buildSectionTitle('legal_settings_section_kvkk_apply'.tr()),
          const SizedBox(height: 12),
          _buildCard([
            _buildTile(
              context,
              icon: Icons.mail_rounded,
              color: AppColors.primary,
              titleKey: 'legal_settings_kvkk_apply_title',
              subtitleKey: 'legal_settings_kvkk_apply_subtitle',
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: AppConstants.supportEmail,
                  queryParameters: {
                    'subject': 'KVKK Başvurusu',
                    'body':
                        'Ad-Soyad: \nBaşvuru Konusu: \nTalep Edilen İşlem: ',
                  },
                );
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
          ]),

          const SizedBox(height: 32),

          Center(
            child: Text(
              'legal_settings_response_time'.tr(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String titleKey,
    required String subtitleKey,
    required VoidCallback onTap,
    bool isDanger = false,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleKey.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDanger
                            ? AppColors.emergency
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleKey.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDanger
                    ? AppColors.emergency.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
