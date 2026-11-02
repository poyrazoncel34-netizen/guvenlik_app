import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../design_tokens.dart';
import '../utils/emergency_number_validator.dart';
import 'escape_dismissible.dart';

const int _manualContactPhoneInputLimit = 32;
const int _manualContactNameInputLimit = 60;

String? manualContactPhoneError(String raw) {
  if (EmergencyNumberValidator.normalizedContactInputOrNull(raw) == null) {
    return 'contacts_manual_invalid_phone';
  }
  return null;
}

class AddContactSheetResult {
  const AddContactSheetResult.pickFromDevice()
    : pickFromDevice = true,
      name = '',
      phone = '';

  const AddContactSheetResult.manual(this.name, this.phone)
    : pickFromDevice = false;

  final bool pickFromDevice;
  final String name;
  final String phone;
}

/// The contacts page's "Yeni Kişi Ekle" sheet. It pops an
/// [AddContactSheetResult], or nothing when dismissed; the page runs the gates
/// and the add flow.
///
/// The sheet owns its text controllers and the phone focus node. The route's
/// future resolves at pop while the exit animation still runs, and focus
/// leaving the closing route rebuilds the fields, so only [State.dispose] --
/// after the route's subtree is gone -- may release them.
class AddContactSheet extends StatefulWidget {
  const AddContactSheet({super.key});

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // D3: the sheet already uses isScrollControlled + viewInsets padding, but on
    // a tall sheet the auto-scroll can leave the focused phone field behind the
    // keyboard. When it gains focus, explicitly scroll it into view above the
    // IME (after the keyboard's inset has settled).
    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) return;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final fieldContext = _phoneFocusNode.context;
        if (fieldContext == null || !fieldContext.mounted) return;
        Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _submitManual() {
    // Validate before closing: an invalid entry keeps the sheet, what was typed
    // and the error under its field. The page still re-checks both values.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      AddContactSheetResult.manual(_nameController.text, _phoneController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EscapeDismissible(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                    size: IconSizes.feature,
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
                      context,
                      const AddContactSheetResult.pickFromDevice(),
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
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  maxLength: _manualContactNameInputLimit,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      _manualContactNameInputLimit,
                    ),
                  ],
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? "contacts_manual_name_required".tr()
                      : null,
                  decoration: InputDecoration(
                    labelText: "contacts_manual_name_label".tr(),
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
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
                  onFieldSubmitted: (_) => _submitManual(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _submitManual,
                    icon: const Icon(Icons.save_rounded),
                    label: Text("contacts_manual_save".tr()),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
