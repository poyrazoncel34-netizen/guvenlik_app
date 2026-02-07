// ============================================================================
// KİŞİLER SAYFASI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttercontactpicker_plus/fluttercontactpicker_plus.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../presentation/providers/contacts_provider.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Acil Kişiler"),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, size: 20, color: AppColors.primary),
            ),
            onPressed: () => _showAddContactSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Quick dial section
          _buildQuickDialSection(),
          const SizedBox(height: 28),

          // Loading state
          if (provider.isLoading) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 28),
          ],

          // Emergency contacts header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Güvenlik Ağım",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEmergencyPicker(context),
                icon: const Icon(Icons.shield_rounded, size: 18),
                label: const Text("Acil kişi seç"),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact cards or empty state
          if (!provider.isLoading && !provider.hasContacts) ...[
            _buildEmptyContactsState(),
          ] else ...[
            ...provider.emergencyContacts.asMap().entries.map((entry) {
              final index = entry.key;
              final contact = entry.value;
              return _buildContactCard(context, index, contact, provider);
            }),
          ],

          if (provider.isAtLimit) ...[
            const SizedBox(height: 8),
            const Text(
              "Maksimum kisi sayisina ulastiniz",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],

          const SizedBox(height: 20),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Future<void> _dialNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final canLaunch = await launchUrl(uri);
    if (!canLaunch && mounted) {
      _showSnack("Arama başlatılamadı");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildQuickDialSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.emergency,
            AppColors.emergency.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.emergency.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                "Hızlı Arama",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickDialButton("155", "Polis", Icons.local_police_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickDialButton("112", "Ambulans", Icons.medical_services_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickDialButton("110", "İtfaiye", Icons.fire_truck_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDialButton(String number, String label, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          _dialNumber(number);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    int index,
    ContactItem contact,
    ContactsProvider provider,
  ) {
    final isEmergency = provider.selectedEmergencyPhone == contact.phone;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showContactOptions(context, contact, provider);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: contact.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(contact.icon, color: contact.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isEmergency) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.emergency.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "ACİL",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emergency,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_rounded, color: AppColors.success, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context, ContactItem contact, ContactsProvider provider) {
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                contact.icon,
                size: 40,
                color: contact.color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              contact.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              contact.phone,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSnack("Mesaj taslağı hazırlandı");
                    },
                    icon: const Icon(Icons.message_rounded, size: 20),
                    label: const Text("Mesaj", style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _dialNumber(contact.phone);
                    },
                    icon: const Icon(Icons.call_rounded, size: 20),
                    label: const Text("Ara", style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  provider.selectEmergencyContact(contact);
                  _showSnack("Acil kişi seçildi: ${contact.name}");
                },
                icon: const Icon(Icons.shield_rounded, size: 20),
                label: const Text("Acil Kişi Seç", style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyContactsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            "Henuz acil kisi eklenmedi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Rehberinizden guvendiginiz kisileri\nacil kisi olarak ekleyin.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _pickContactFromDevice(),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text("Kisi Ekle", style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.12)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_rounded, color: AppColors.info, size: 22),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              "Acil durumlarda bu kişiler otomatik olarak bilgilendirilecek",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
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
                child: const Icon(Icons.person_add_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                "Yeni Kişi Ekle",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              const Text(
                "Rehberinizden kişi seçerek acil kişilerinize ekleyin.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickContactFromDevice();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Rehberden Seç", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickContactFromDevice() async {
    try {
      if (kIsWeb) {
        _showSnack("Web sürümünde rehber seçimi desteklenmiyor");
        return;
      }
      final contact = await FlutterContactPicker.pickPhoneContact(askForPermission: true);
      if (!mounted) return;
      final name = (contact.fullName?.trim().isNotEmpty ?? false)
          ? contact.fullName!.trim()
          : "Bilinmeyen Kişi";
      final phone = contact.phoneNumber?.number?.trim() ?? "";

      if (phone.isEmpty) {
        _showSnack("Seçilen kişide telefon numarası yok");
        return;
      }

      final provider = context.read<ContactsProvider>();
      final added = await provider.addContact(name: name, phone: phone);
      if (!added) {
        _showSnack("Bu kişi zaten listede");
        return;
      }

      _showSnack("$name eklendi");
      HapticFeedback.mediumImpact();
    } on UserCancelledPickingException {
      // kullanıcı vazgeçti
    } catch (_) {
      _showSnack("Rehbere erişilemedi");
    }
  }

  void _showEmergencyPicker(BuildContext context) {
    final provider = context.read<ContactsProvider>();
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
            const SizedBox(height: 18),
            const Text(
              "Acil Kişi Seç",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            ...provider.emergencyContacts.map((contact) {
              final isSelected = provider.selectedEmergencyPhone == contact.phone;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: contact.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(contact.icon, color: contact.color),
                ),
                title: Text(
                  contact.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  contact.phone,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppColors.accent : AppColors.border,
                ),
                onTap: () {
                  Navigator.pop(context);
                  provider.selectEmergencyContact(contact);
                  _showSnack("Acil kişi seçildi: ${contact.name}");
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
