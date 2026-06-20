// ============================================================================
// RIZA YÖNETİMİ EKRANI — Mevcut rızaları göster ve geri çek
// KVKK Madde 11 — geri çekme hakkı
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/consent_manager.dart';
import '../../models/consent_record.dart';
import '../../core/di/service_locator.dart';

class ConsentManagementScreen extends StatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  State<ConsentManagementScreen> createState() =>
      _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends State<ConsentManagementScreen> {
  late ConsentManager _cm;
  Map<String, bool> _consentStatus = {};
  bool _loading = false;

  final List<_ConsentItem> _items = const [
    _ConsentItem(
      type: ConsentRecord.typeLocation,
      titleKey: 'legal_consent_location',
      subtitleKey: 'legal_consent_location_sub',
      icon: Icons.location_on_rounded,
      color: AppColors.info,
    ),
    _ConsentItem(
      type: ConsentRecord.typeEmergencyContacts,
      titleKey: 'legal_consent_emergency_contacts',
      subtitleKey: 'legal_consent_emergency_contacts_sub',
      icon: Icons.contacts_rounded,
      color: AppColors.primary,
    ),
    _ConsentItem(
      type: ConsentRecord.typeProfile,
      titleKey: 'legal_consent_profile',
      subtitleKey: 'legal_consent_profile_sub',
      icon: Icons.person_rounded,
      color: AppColors.accent,
    ),
    _ConsentItem(
      type: ConsentRecord.typeFakeCall,
      titleKey: 'legal_consent_fake_call',
      subtitleKey: 'legal_consent_fake_call_sub',
      icon: Icons.phone_in_talk_rounded,
      color: AppColors.success,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cm = serviceLocator<ConsentManager>();
    _loadStatus();
  }

  void _loadStatus() {
    setState(() {
      _consentStatus = Map.from(_cm.getAllConsentStatus());
    });
  }

  Future<void> _toggle(String type, bool newValue) async {
    setState(() => _loading = true);
    HapticFeedback.lightImpact();
    try {
      final locale = context.locale.languageCode;
      if (newValue) {
        await _cm.grantConsent(type, locale: locale);
      } else {
        // Geri çekme onay dialog'u
        final confirmed = await _showRevokeConfirmation(type);
        if (!confirmed) {
          setState(() => _loading = false);
          return;
        }
        await _cm.revokeConsent(type, locale: locale);
        await _updatePrefs(type, false);
      }
      if (newValue) await _updatePrefs(type, true);
      _loadStatus();
    } on Exception catch (e) {
      // Storage write failed (e.g. keystore error). Tell the user the change
      // was NOT saved and re-sync the switches to the real (unchanged) state.
      debugPrint('[ConsentManagement] toggle persist failed: $e');
      if (mounted) {
        _loadStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('consent_save_failed'.tr()),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePrefs(String type, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefKeyForType(type);
    if (key != null) await prefs.setBool(key, value);
  }

  String? _prefKeyForType(String type) {
    switch (type) {
      case ConsentRecord.typeLocation:
        return AppConstants.prefConsentLocation;
      case ConsentRecord.typeEmergencyContacts:
        return AppConstants.prefConsentEmergencyContacts;
      case ConsentRecord.typeProfile:
        return AppConstants.prefConsentProfile;
      default:
        return null;
    }
  }

  Future<bool> _showRevokeConfirmation(String type) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'consent_revoke_title'.tr(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'consent_revoke_desc'.tr(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('consent_revoke_confirm'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'consent_mgmt_title'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textSecondary,
          ),
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
          if (_cm.loadFailed)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'consent_load_failed'.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.warning,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Bilgi kutusu
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
            ),
            child: Text(
              'consent_mgmt_info'.tr(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.info,
                height: 1.5,
              ),
            ),
          ),

          // Rıza öğeleri
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final granted = _consentStatus[item.type] ?? false;
                return Column(
                  children: [
                    _buildConsentTile(item, granted),
                    if (index < _items.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border.withValues(alpha: 0.5),
                        indent: 60,
                      ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 24),

          // Geri çekme tarihi notu
          Text(
            'consent_mgmt_footer'.tr(),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConsentTile(_ConsentItem item, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.titleKey.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitleKey.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: granted,
              onChanged: _loading ? null : (v) => _toggle(item.type, v),
              activeThumbColor: item.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentItem {
  final String type;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final Color color;

  const _ConsentItem({
    required this.type,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.color,
  });
}
