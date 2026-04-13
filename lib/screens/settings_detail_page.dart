// ============================================================================
// AYARLAR DETAY SAYFASI
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../core/services/user_data_export_service.dart';

/// Section keys used for content lookup (locale-independent).
/// Must match the keys passed from settings_page (e.g. settings_about_app).
class SettingsDetailPage extends StatelessWidget {
  final String title;
  final String sectionKey;
  final IconData icon;

  const SettingsDetailPage({
    super.key,
    required this.title,
    required this.sectionKey,
    required this.icon,
  });

  List<_DetailSection> _sectionsForTitle({
    String? version,
    String? buildNumber,
  }) {
    final ver = version ?? '-';
    final build = buildNumber ?? '-';
    switch (sectionKey) {
      case 'settings_about_app':
        return [
          _DetailSection(
            heading: "detail_about_heading_mission".tr(),
            body: "detail_about_body_mission".tr(),
          ),
          _DetailSection(
            heading: "detail_about_heading_features".tr(),
            body: "detail_about_body_features".tr(),
          ),
          _DetailSection(
            heading: "detail_about_heading_version".tr(),
            body: "detail_about_body_version".tr(
              namedArgs: {'version': ver, 'build': build},
            ),
          ),
          _DetailSection(
            heading: "detail_about_heading_disclaimer".tr(),
            body: "detail_about_body_disclaimer".tr(),
          ),
        ];
      case 'settings_privacy_policy':
        return [
          _DetailSection(
            heading: "detail_privacy_heading_1".tr(),
            body: "detail_privacy_body_1".tr(),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_2".tr(),
            body: "detail_privacy_body_2".tr(),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_3".tr(),
            body: "detail_privacy_body_3".tr(),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_4".tr(),
            body: "detail_privacy_body_4".tr(),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_5".tr(),
            body: "detail_privacy_body_5".tr(),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_6".tr(),
            body: "detail_privacy_body_6".tr(),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_7".tr(),
            body: "detail_privacy_body_7".tr(
              namedArgs: {'rights_contact': "support_contact_rights".tr()},
            ),
          ),
          _DetailSection(
            heading: "detail_privacy_heading_8".tr(),
            body: "detail_privacy_body_8".tr(
              namedArgs: {'email_line': "support_email_line".tr()},
            ),
          ),
        ];
      case 'settings_help':
        return [
          _DetailSection(
            heading: "detail_help_heading_howto".tr(),
            body: "detail_help_body_howto".tr(),
          ),
          _DetailSection(
            heading: "detail_help_heading_faq".tr(),
            body: "detail_help_body_faq".tr(),
          ),
          _DetailSection(
            heading: "detail_help_heading_support".tr(),
            body: "detail_help_body_support".tr(
              namedArgs: {'email_line': "support_email_line".tr()},
            ),
          ),
          _DetailSection(
            heading: "detail_help_heading_emergency".tr(),
            body: "detail_help_body_emergency".tr(),
          ),
        ];
      case 'settings_notifications':
        return [
          _DetailSection(
            heading: "settings_notifications_info_heading".tr(),
            body: "settings_notifications_info_body".tr(),
          ),
        ];
      default:
        return [
          _DetailSection(
            heading: "detail_default_heading".tr(),
            body: "detail_default_body".tr(),
          ),
        ];
    }
  }

  String _introForTitle() {
    switch (sectionKey) {
      case 'settings_about_app':
        return "detail_intro_about".tr();
      case 'settings_privacy_policy':
        return "detail_intro_privacy".tr();
      case 'settings_help':
        return "detail_intro_help".tr();
      case 'settings_notifications':
        return "settings_notifications_info_intro".tr();
      default:
        return "detail_intro_default".tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sectionKey == 'settings_about_app') {
      return FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version;
          final buildNumber = snapshot.data?.buildNumber;
          final sections = _sectionsForTitle(
            version: version,
            buildNumber: buildNumber,
          );
          return _buildBody(context, sections);
        },
      );
    }
    final sections = _sectionsForTitle();
    return _buildBody(context, sections);
  }

  Widget _buildBody(BuildContext context, List<_DetailSection> sections) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _introForTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...sections.map(
            (section) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sectionKey == 'settings_privacy_policy') ...[
            const SizedBox(height: 8),
            const _DataExportButton(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DataExportButton extends StatefulWidget {
  const _DataExportButton();

  @override
  State<_DataExportButton> createState() => _DataExportButtonState();
}

class _DataExportButtonState extends State<_DataExportButton> {
  bool _exporting = false;

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final exportData = await UserDataExportService.buildExportData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/korubeni_verilerim.json');
      await file.writeAsString(jsonStr);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'KoruBeni — KVKK Md.11 Veri Dışa Aktarma',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('data_export_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verilerimi Dışa Aktar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'KVKK Madde 11/f kapsamında kişisel verilerinizin bir kopyasını JSON formatında alabilirsiniz.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : _exportData,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_exporting ? 'Hazırlanıyor...' : 'Verilerimi İndir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection {
  final String heading;
  final String body;

  const _DetailSection({required this.heading, required this.body});
}
