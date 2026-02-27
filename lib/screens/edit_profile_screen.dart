import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../presentation/providers/settings_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String email;

  const EditProfileScreen({super.key, required this.name, required this.email});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalController;
  late TextEditingController _emergencyNotesController;
  final _formKey = GlobalKey<FormState>();
  String _selectedBloodType = '';

  static const List<String> _bloodTypes = [
    '', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<SettingsProvider>();
    _nameController = TextEditingController(
      text: widget.name == "settings_default_user".tr() ? '' : widget.name,
    );
    _emailController = TextEditingController(text: widget.email);
    _allergiesController = TextEditingController(text: provider.allergies);
    _medicalController = TextEditingController(text: provider.medicalConditions);
    _emergencyNotesController = TextEditingController(text: provider.emergencyNotes);
    _selectedBloodType = provider.bloodType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _allergiesController.dispose();
    _medicalController.dispose();
    _emergencyNotesController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "edit_profile_name_required".tr();
    }
    if (value.trim().length < 2) {
      return "edit_profile_name_min_length".tr();
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email optional
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return "edit_profile_email_invalid".tr();
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SettingsProvider>();
    await provider.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      bloodType: _selectedBloodType,
      allergies: _allergiesController.text.trim(),
      medicalConditions: _medicalController.text.trim(),
      emergencyNotes: _emergencyNotesController.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text("edit_profile_success".tr()),
            ],
          ),
          backgroundColor: AppColors.success,
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
      appBar: AppBar(title: Text("edit_profile_title".tr())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Personal info section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    validator: _validateName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: "edit_profile_name_hint".tr(),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      labelText: "edit_profile_name_label".tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    decoration: InputDecoration(
                      hintText: "edit_profile_email_hint".tr(),
                      prefixIcon: const Icon(Icons.email_outlined),
                      labelText: "edit_profile_email_label".tr(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Medical info section
            Text(
              "profile_medical_title".tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "profile_medical_desc".tr(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Blood type dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _bloodTypes.contains(_selectedBloodType)
                        ? _selectedBloodType
                        : '',
                    items: _bloodTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.isEmpty ? "profile_blood_type_select".tr() : type,
                          style: TextStyle(
                            color: type.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedBloodType = value ?? '');
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.bloodtype_rounded, color: AppColors.emergency),
                      labelText: "profile_blood_type".tr(),
                    ),
                    dropdownColor: AppColors.cardBg,
                  ),
                  const SizedBox(height: 12),
                  // Allergies
                  TextFormField(
                    controller: _allergiesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "profile_allergies_hint".tr(),
                      prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      labelText: "profile_allergies".tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Medical conditions
                  TextFormField(
                    controller: _medicalController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "profile_medical_hint".tr(),
                      prefixIcon: const Icon(Icons.medical_information_rounded, color: AppColors.info),
                      labelText: "profile_medical_conditions".tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Emergency notes
                  TextFormField(
                    controller: _emergencyNotesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "profile_emergency_notes_hint".tr(),
                      prefixIcon: const Icon(Icons.note_rounded, color: AppColors.accent),
                      labelText: "profile_emergency_notes".tr(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "save".tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
