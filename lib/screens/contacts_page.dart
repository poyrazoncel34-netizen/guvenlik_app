// ============================================================================
// KİŞİLER SAYFASI
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/consent_gate_service.dart';
import '../core/services/native_contact_picker_service.dart';
import '../core/services/subscription_gate.dart';
import '../core/utils/emergency_number_validator.dart';
import '../models/consent_record.dart';
import '../presentation/providers/contacts_provider.dart';
import '../presentation/providers/home_provider.dart';
import '../widgets/emergency_contact_consent_dialog.dart';
import '../core/widgets/escape_dismissible.dart';

const int _manualContactPhoneInputLimit = 32;
const int _manualContactNameInputLimit = 60;

/// Validates a manually entered emergency-contact phone number.
///
/// Returns a translation key for the error message, or null when the number is
/// acceptable. Kept as a pure top-level function so it can be unit-tested and
/// reused by the inline field validator. The same rule is enforced again at
/// submit time in [_addManualContact] (defense in depth).
String? manualContactPhoneError(String raw) {
  if (EmergencyNumberValidator.normalizedCallableTargetOrNull(raw) == null) {
    return 'contacts_manual_invalid_phone';
  }
  return null;
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _AddContactSheetResult {
  const _AddContactSheetResult.pickFromDevice()
    : pickFromDevice = true,
      name = '',
      phone = '';

  const _AddContactSheetResult.manual(this.name, this.phone)
    : pickFromDevice = false;

  final bool pickFromDevice;
  final String name;
  final String phone;
}

class _ContactsPageState extends State<ContactsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsProvider>().initialize();
    });
  }

  bool _requireEmergencyContactConsent() {
    if (!mounted) return false;
    return ConsentGateService.requireConsent(
      context,
      ConsentRecord.typeEmergencyContacts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactsProvider>();
    return Semantics(
      label: "semantics_contacts_page".tr(),
      hint: "semantics_contacts_page_hint".tr(),
      child: Scaffold(
        appBar: AppBar(
          title: Text("contacts_emergency_title".tr()),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              onPressed: () async {
                final allowed = await SubscriptionGate.ensureAccess(
                  context,
                  PremiumFeature.emergencyContactAdd,
                );
                if (!allowed || !context.mounted) return;
                if (!_requireEmergencyContactConsent()) return;
                _showAddContactSheet();
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Loading state
            if (provider.isLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 28),
            ],

            // Emergency contacts header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "contacts_network_title".tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: provider.hasContacts
                      ? () async {
                          final allowed = await SubscriptionGate.ensureAccess(
                            context,
                            PremiumFeature.emergencyContactSelect,
                          );
                          if (!allowed || !context.mounted) return;
                          _showEmergencyPicker(context);
                        }
                      : null,
                  icon: const Icon(Icons.shield_rounded, size: 18),
                  label: Text("contacts_select_emergency".tr()),
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
              Text(
                'contacts_reorder_hint'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: provider.emergencyContacts.length * 110.0,
                child: ReorderableListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: provider.emergencyContacts.length,
                  onReorder: (oldIndex, newIndex) {
                    HapticFeedback.mediumImpact();
                    provider.reorderContact(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final contact = provider.emergencyContacts[index];
                    return KeyedSubtree(
                      key: ValueKey(contact.phone),
                      child: _buildContactCard(
                        context,
                        index,
                        contact,
                        provider,
                      ),
                    );
                  },
                ),
              ),
            ],

            if (provider.isAtLimit) ...[
              const SizedBox(height: 8),
              Text(
                "contacts_max_reached".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 20),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _dialNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnack(
          "contacts_call_failed".tr(),
          backgroundColor: AppColors.emergency,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
          "contacts_call_failed".tr(),
          backgroundColor: AppColors.emergency,
        );
      }
    }
  }

  void _showSnack(String message, {Color backgroundColor = AppColors.success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _refreshHomeProvider() async {
    if (!mounted) return;
    await context.read<HomeProvider>().refreshAfterContactsChanged();
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
                const BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
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
                          Flexible(
                            child: Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isEmergency) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.emergency.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "contacts_emergency_badge".tr(),
                                maxLines: 1,
                                style: const TextStyle(
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
                  child: const Icon(
                    Icons.call_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContactOptions(
    BuildContext context,
    ContactItem contact,
    ContactsProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EscapeDismissible(child: Container(
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
              child: Icon(contact.icon, size: 40, color: contact.color),
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
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _dialNumber(contact.phone);
                    },
                    icon: const Icon(Icons.call_rounded, size: 20),
                    label: Text(
                      "contacts_call".tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final allowed = await SubscriptionGate.ensureAccess(
                    context,
                    PremiumFeature.emergencyContactSelect,
                  );
                  if (!allowed || !mounted) return;
                  await provider.selectEmergencyContact(contact);
                  await _refreshHomeProvider();
                  if (!mounted) return;
                  _showSnack(
                    "contacts_emergency_selected".tr(
                      namedArgs: {"name": contact.name},
                    ),
                  );
                },
                icon: const Icon(Icons.shield_rounded, size: 20),
                label: Text(
                  "contacts_select_emergency_btn".tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await _confirmRemoveContact(contact);
                  if (!confirmed || !mounted) return;
                  final removed = await provider.removeContact(contact.phone);
                  await _refreshHomeProvider();
                  if (!mounted) return;
                  _showSnack(
                    removed
                        ? "contacts_removed".tr(
                            namedArgs: {"name": contact.name},
                          )
                        : "contacts_remove_failed".tr(),
                    backgroundColor: removed
                        ? AppColors.warning
                        : AppColors.emergency,
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: Text(
                  "contacts_remove".tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emergency,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      )),
    );
  }

  Future<bool> _confirmRemoveContact(ContactItem contact) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EscapeDismissible(child: AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "contacts_remove_confirm_title".tr(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          "contacts_remove_confirm_desc".tr(namedArgs: {"name": contact.name}),
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
            ),
            child: Text("btn_delete".tr()),
          ),
        ],
      )),
    );
    return confirmed == true;
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
            child: const Icon(
              Icons.people_outline_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "contacts_empty".tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "contacts_empty_subtitle".tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final allowed = await SubscriptionGate.ensureAccess(
                context,
                PremiumFeature.emergencyContactAdd,
              );
              if (!allowed || !mounted) return;
              if (!_requireEmergencyContactConsent()) return;
              await _pickContactFromDevice();
            },
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(
              "contacts_add_person".tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: AppColors.info, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "contacts_info_text".tr(),
              style: const TextStyle(
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

  Future<void> _showContactKvkkInfoIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(AppConstants.prefContactConsentShown) ?? false;
    if (shown || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => EscapeDismissible(child: AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'kvkk_contact_consent_title'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'kvkk_contact_consent_body'.tr(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_ok'.tr()),
          ),
        ],
      )),
    );
    await prefs.setBool(AppConstants.prefContactConsentShown, true);
  }

  void _showAddContactSheet() {
    if (!_requireEmergencyContactConsent()) return;
    _showAddContactSheetFlow();
  }

  Future<void> _showAddContactSheetFlow() async {
    await _showContactKvkkInfoIfNeeded();
    if (!mounted) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final phoneFocusNode = FocusNode();
    // D3: the sheet already uses isScrollControlled + viewInsets padding, but on
    // a tall sheet the auto-scroll can leave the focused phone field behind the
    // keyboard. When it gains focus, explicitly scroll it into view above the
    // IME (after the keyboard's inset has settled).
    phoneFocusNode.addListener(() {
      if (!phoneFocusNode.hasFocus) return;
      Future.delayed(const Duration(milliseconds: 300), () {
        final fieldContext = phoneFocusNode.context;
        if (fieldContext == null || !fieldContext.mounted) return;
        Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      });
    });

    try {
      final result = await showModalBottomSheet<_AddContactSheetResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => EscapeDismissible(child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
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
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "contacts_add_new".tr(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "contacts_add_new_subtitle".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "contacts_picker_user_selected_only".tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      const _AddContactSheetResult.pickFromDevice(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      "contacts_pick_from_contacts".tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  maxLength: _manualContactNameInputLimit,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      _manualContactNameInputLimit,
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: "contacts_manual_name_label".tr(),
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  focusNode: phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(
                      _manualContactPhoneInputLimit,
                    ),
                  ],
                  validator: (value) {
                    final errorKey = manualContactPhoneError(value ?? '');
                    return errorKey?.tr();
                  },
                  decoration: InputDecoration(
                    labelText: "contacts_manual_phone_label".tr(),
                    prefixIcon: const Icon(Icons.phone_rounded),
                  ),
                  onFieldSubmitted: (_) => Navigator.pop(
                    sheetContext,
                    _AddContactSheetResult.manual(
                      nameController.text,
                      phoneController.text,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _AddContactSheetResult.manual(
                        nameController.text,
                        phoneController.text,
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: Text("contacts_manual_save".tr()),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        )),
      );
      if (!mounted || result == null) return;
      if (result.pickFromDevice) {
        await _pickContactFromDevice();
      } else {
        await _addManualContact(result.name, result.phone);
      }
    } finally {
      nameController.dispose();
      phoneController.dispose();
      phoneFocusNode.dispose();
    }
  }

  Future<void> _addManualContact(String rawName, String rawPhone) async {
    final allowed = await SubscriptionGate.ensureAccess(
      context,
      PremiumFeature.emergencyContactAdd,
    );
    if (!allowed || !mounted) return;
    if (!_requireEmergencyContactConsent()) return;

    final name = rawName.trim();
    if (name.isEmpty) {
      _showSnack(
        "contacts_manual_name_required".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final phone = EmergencyNumberValidator.normalizedCallableTargetOrNull(
      rawPhone,
    );
    if (phone == null) {
      _showSnack(
        "contacts_manual_invalid_phone".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final consentGiven = await EmergencyContactConsentDialog.show(
      context: context,
      contactName: name,
    );
    if (!consentGiven || !mounted) return;

    final provider = context.read<ContactsProvider>();
    final added = await provider.addContact(name: name, phone: phone);
    if (!added) {
      _showSnack(
        provider.isAtLimit
            ? "contacts_max_reached".tr()
            : "contacts_already_in_list".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }

    await _refreshHomeProvider();
    _showSnack("contacts_added".tr(namedArgs: {"name": name}));
    HapticFeedback.mediumImpact();
  }

  Future<void> _pickContactFromDevice() async {
    final allowed = await SubscriptionGate.ensureAccess(
      context,
      PremiumFeature.emergencyContactAdd,
    );
    if (!allowed || !mounted) return;
    if (!_requireEmergencyContactConsent()) return;

    if (kIsWeb) {
      _showSnack(
        "contacts_web_picker_unsupported".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }

    // Permissionless native picker (ACTION_PICK on the phone data URI), reached
    // through the single access path in NativeContactPickerService.
    final result = await NativeContactPickerService.pickPhoneContact();
    if (!mounted) return;
    if (result.isUnavailable) {
      _showSnack(
        "contacts_picker_failed".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }
    final picked = result.contact;
    if (picked == null) {
      // User cancelled, or the picked contact had no usable number.
      return;
    }

    final name = picked.name.isNotEmpty
        ? picked.name
        : "contacts_unknown".tr();
    final phone = EmergencyNumberValidator.normalizedCallableTargetOrNull(
      picked.number,
    );
    if (phone == null) {
      _showSnack(
        "contacts_no_phone".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }

    // KVKK: Kişi ekleme öncesi rıza onayı
    final consentGiven = await EmergencyContactConsentDialog.show(
      context: context,
      contactName: name,
    );
    if (!consentGiven || !mounted) return;

    final provider = context.read<ContactsProvider>();
    final added = await provider.addContact(name: name, phone: phone);
    if (!added) {
      _showSnack(
        provider.isAtLimit
            ? "contacts_max_reached".tr()
            : "contacts_already_in_list".tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }

    await _refreshHomeProvider();
    _showSnack("contacts_added".tr(namedArgs: {"name": name}));
    HapticFeedback.mediumImpact();
  }

  void _showEmergencyPicker(BuildContext context) {
    final provider = context.read<ContactsProvider>();
    if (!provider.hasContacts) {
      _showSnack("contacts_empty".tr(), backgroundColor: AppColors.warning);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EscapeDismissible(child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            top: false,
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
                Text(
                  "contacts_select_emergency_btn".tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...provider.emergencyContacts.map((contact) {
                  final isSelected =
                      provider.selectedEmergencyPhone == contact.phone;
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      contact.phone,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? AppColors.accent : AppColors.border,
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final allowed = await SubscriptionGate.ensureAccess(
                        context,
                        PremiumFeature.emergencyContactSelect,
                      );
                      if (!allowed || !mounted) return;
                      await provider.selectEmergencyContact(contact);
                      await _refreshHomeProvider();
                      if (!mounted) return;
                      _showSnack(
                        "contacts_emergency_selected".tr(
                          namedArgs: {"name": contact.name},
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      )),
    );
  }
}
