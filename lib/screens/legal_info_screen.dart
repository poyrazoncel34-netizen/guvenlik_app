// ============================================================================
// YASAL BİLGİLER SAYFASI — Ayarlar menüsünden erişilen ⚖️ bölümü
// 7 liste öğesi: belgeler, KVKK başvuru, veri silme, loglar, hakkında
// ============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/legal_log_service.dart';
import '../core/services/app_reset_service.dart';

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key});

  Future<void> _launchUrl(String url, [BuildContext? context]) async {
    final uri = Uri.parse(url);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('link_open_failed'.tr()),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          '⚖️ Yasal Bilgiler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Belgeler bölümü ──
            _sectionTitle('Belgeler'),
            const SizedBox(height: 8),
            _card([
              _navTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF3182CE),
                title: 'Kullanım Şartları',
                subtitle: 'TBK Md. 20-25 uyumlu kullanım koşulları',
                onTap: () => _launchUrl(AppConstants.termsOfServiceUrl, context),
              ),
              _divider(),
              _navTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF38A169),
                title: 'Gizlilik Politikası',
                subtitle: 'Veri işleme ve gizlilik bilgileri',
                onTap: () => _launchUrl(AppConstants.privacyPolicyWebUrl, context),
              ),
              _divider(),
              _navTile(
                icon: Icons.article_outlined,
                iconColor: const Color(0xFF9F7AEA),
                title: 'Aydınlatma Metni (KVKK)',
                subtitle: 'KVKK Md. 10 — Veri sorumlusu bildirimi',
                onTap: () => _launchUrl(AppConstants.aydinlatmaMetniUrl, context),
              ),
            ]),
            const SizedBox(height: 20),

            // ── KVKK Hakları bölümü ──
            _sectionTitle('KVKK Hakları'),
            const SizedBox(height: 8),
            _card([
              _navTile(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFFDD6B20),
                title: 'KVKK Başvurusu Yap',
                subtitle: 'KVKK Md. 11 haklarınız için e-posta gönderin',
                onTap: () => _launchUrl(AppConstants.kvkkMailto, context),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Veri Yönetimi bölümü ──
            _sectionTitle('Veri Yönetimi'),
            const SizedBox(height: 8),
            _card([
              _navTile(
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFE53E3E),
                title: 'Tüm Verilerimi Sil',
                subtitle: 'Tüm uygulama verileri, kişiler ve ayarlar silinir',
                onTap: () => _showDeleteConfirm(context),
              ),
              _divider(),
              _navTile(
                icon: Icons.list_alt_rounded,
                iconColor: AppColors.textSecondary,
                title: 'Log Kayıtlarım',
                subtitle: 'Hukuki ispat kayıtlarını görüntüle ve sil',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _LogsScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Uygulama Hakkında ──
            _sectionTitle('Uygulama Hakkında'),
            const SizedBox(height: 8),
            _AppInfoCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );

  Widget _card(List<Widget> children) => Container(
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

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border.withValues(alpha: 0.5),
        indent: 60,
      );

  Widget _navTile({
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
        borderRadius: BorderRadius.circular(16),
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

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tüm Verilerimi Sil',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Tüm uygulama verileri, acil kişiler ve ayarlar silinecek.\n\n'
          'Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'İptal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAllData(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllData(BuildContext context) async {
    await LegalLogService.instance.logEvent('user_data_deleted');
    await AppResetService.clearLocalData(); // prefs + SecureStorage (PIN) + SQLite (contacts)
    await LegalLogService.instance.deleteLogs();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tüm veriler silindi.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

// ── Log Kayıtları Alt Sayfası ─────────────────────────────────────────────────
class _LogsScreen extends StatefulWidget {
  const _LogsScreen();

  @override
  State<_LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<_LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LegalLogService.instance.getLogs();
    if (mounted) setState(() { _logs = logs.reversed.toList(); _loading = false; });
  }

  Future<void> _deleteLogs() async {
    await LegalLogService.instance.deleteLogs();
    if (mounted) setState(() => _logs = []);
  }

  String _formatTimestamp(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Log Kayıtlarım',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        elevation: 0,
        actions: [
          if (_logs.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Log Kayıtlarını Sil', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                    content: const Text('Tüm log kayıtları silinecek. Emin misiniz?', style: TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: AppColors.textSecondary))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53E3E), foregroundColor: Colors.white),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) await _deleteLogs();
              },
              child: const Text('Tümünü Sil', style: TextStyle(color: Color(0xFFE53E3E))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Text(
                    'Henüz log kaydı yok.',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final log = _logs[i];
                    final event = log['event'] as String? ?? '';
                    final feature = log['feature'] as String?;
                    final result = log['result'] as String?;
                    final errorType = log['error_type'] as String?;
                    final ts = _formatTimestamp(log['timestamp'] as String?);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Text(
                                ts,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          if (feature != null) ...[
                            const SizedBox(height: 4),
                            Text('Özellik: $feature', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          if (result != null) ...[
                            const SizedBox(height: 2),
                            Text('Sonuç: $result', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          if (errorType != null) ...[
                            const SizedBox(height: 2),
                            Text('Hata: $errorType', style: const TextStyle(fontSize: 12, color: Color(0xFFE53E3E))),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Uygulama Hakkında Kartı ───────────────────────────────────────────────────
class _AppInfoCard extends StatefulWidget {
  @override
  State<_AppInfoCard> createState() => _AppInfoCardState();
}

class _AppInfoCardState extends State<_AppInfoCard> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KoruBeni — Kişisel Güvenlik Uygulaması',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          _infoRow('Sürüm', _version.isEmpty ? '...' : _version),
          _infoRow('Geliştirici', 'Poyraz Öncel'),
          _infoRow('İletişim', 'korubeni.destek@gmail.com'),
          const SizedBox(height: 8),
          const Text(
            '© 2026 KoruBeni. Tüm hakları saklıdır.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
}
