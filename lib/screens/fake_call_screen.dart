// ============================================================================
// SAHTE ÇAĞRI
// ============================================================================

import 'dart:io';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/di/service_locator.dart';
import '../services/consent_manager.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/services/activity_service.dart';
import '../core/services/app_settings_service.dart';
import '../core/services/consent_gate_service.dart';
import '../domain/models/activity_event.dart';
import '../models/consent_record.dart';
import '../core/widgets/escape_dismissible.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  String _callerName = "";
  String _callerNumber = "";
  String? _avatarPath;
  bool _ringtoneError = false;
  final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  static const String _keyName = SecureStorageKeys.fakeCallName;
  static const String _keyNumber = SecureStorageKeys.fakeCallNumber;
  static const String _keyAvatar = SecureStorageKeys.fakeCallAvatar;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _loadSavedSettings();
    // The ringtone used to start here, before either gate below had run. A
    // scheduled fake call could therefore play audio on a device whose owner
    // had already withdrawn fake-call consent -- the sound is the feature, so
    // playing it first made the gate cosmetic. It now starts only after both
    // the first-use warning and the consent gate have passed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Show the first-use warning FIRST — accepting it grants fake-call consent
      // — so a cold first use can grant consent here. (Note: home_page also
      // gates entry on consent, so the reachable case is mainly defense in
      // depth for scheduled calls.)
      await _checkFirstUseWarning();
      if (!mounted) return;
      // Defense-in-depth gate: a delayed/scheduled fake call may push this
      // screen even after consent was withdrawn from settings.
      if (!ConsentGateService.requireConsent(
        context,
        ConsentRecord.typeFakeCall,
      )) {
        Navigator.of(context).maybePop();
        return;
      }
      if (!mounted) return;
      _startRingtone();
    });
  }

  Future<void> _checkFirstUseWarning() async {
    final prefs = await SharedPreferences.getInstance();
    final warned = prefs.getBool('pref_fake_call_warned') ?? false;
    if (warned || !mounted) return;
    await _stopRingtone();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EscapeDismissible(
        child: AlertDialog(
        backgroundColor: const Color(0xFF10263A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB547).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFFB547),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'fake_call_warning_title'.tr(),
                style: const TextStyle(
                  color: Color(0xFFF3F7FF),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'fake_call_warning_desc'.tr(),
          style: const TextStyle(
            color: Color(0xFF9BB0C7),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Color(0xFF9BB0C7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB547),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('fake_call_warning_accept'.tr()),
          ),
        ],
      ),
      ),
    );
    if (confirmed == true) {
      await prefs.setBool('pref_fake_call_warned', true);
      // Consent log
      try {
        final cm = serviceLocator<ConsentManager>();
        await cm.grantConsent('fake_call');
      } catch (_) {}
      if (mounted) _startRingtone();
    } else {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final name = await _secureStorage.read(key: _keyName);
    final number = await _secureStorage.read(key: _keyNumber);
    final avatar = await _secureStorage.read(key: _keyAvatar);
    if (mounted) {
      setState(() {
        _callerName = name ?? "fake_call_default_name".tr();
        _callerNumber = number ?? "fake_call_default_number".tr();
        _avatarPath = avatar;
      });
    }
    if (name != null || number != null || avatar != null) return;
    // Legacy fallback: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final legacyName = prefs.getString(_keyName);
    final legacyNumber = prefs.getString(_keyNumber);
    final legacyAvatar = prefs.getString(_keyAvatar);
    if (legacyName != null) {
      await _secureStorage.write(key: _keyName, value: legacyName);
      await prefs.remove(_keyName);
    }
    if (legacyNumber != null) {
      await _secureStorage.write(key: _keyNumber, value: legacyNumber);
      await prefs.remove(_keyNumber);
    }
    if (legacyAvatar != null) {
      await _secureStorage.write(key: _keyAvatar, value: legacyAvatar);
      await prefs.remove(_keyAvatar);
    }
    if (mounted &&
        (legacyName != null || legacyNumber != null || legacyAvatar != null)) {
      setState(() {
        _callerName = legacyName ?? _callerName;
        _callerNumber = legacyNumber ?? _callerNumber;
        _avatarPath = legacyAvatar ?? _avatarPath;
      });
    }
    // Ensure defaults are set if still empty after legacy migration
    if (mounted && _callerName.isEmpty) {
      setState(() {
        _callerName = "fake_call_default_name".tr();
        _callerNumber = _callerNumber.isEmpty
            ? "fake_call_default_number".tr()
            : _callerNumber;
      });
    }
  }

  Future<void> _startRingtone() async {
    if (!await AppSettingsService.soundEnabled()) {
      if (mounted) setState(() => _ringtoneError = true);
      return;
    }

    try {
      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      if (kIsWeb) {
        // On web, AssetSource paths resolve differently.
        // Use UrlSource with the correct Flutter web asset path.
        await _audioPlayer.play(UrlSource('assets/assets/sounds/ringtone.wav'));
      } else {
        // Play the ringtone asset on native platforms
        await _audioPlayer.play(AssetSource('sounds/ringtone.wav'));
      }

      // Log success for debugging
      debugPrint('FakeCallScreen: Ringtone started playing');
    } catch (e) {
      debugPrint(
        'FakeCallScreen: Error playing ringtone (asset may be missing): $e',
      );
      if (mounted) setState(() => _ringtoneError = true);
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "semantics_fake_call".tr(),
      hint: "semantics_fake_call_hint".tr(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1C1E), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          _stopRingtone();
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showCustomizeDialog,
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                        label: Text(
                          "fake_call_settings".tr(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1 + (_pulseController.value * 0.04),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[850],
                        ),
                        child:
                            !kIsWeb &&
                                _avatarPath != null &&
                                File(_avatarPath!).existsSync()
                            ? ClipOval(
                                child: Image.file(
                                  File(_avatarPath!),
                                  fit: BoxFit.cover,
                                  width: 130,
                                  height: 130,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 70,
                                color: Colors.white60,
                              ),
                      ),
                      const SizedBox(height: 28),
                      // The caller name IS this screen's heading (MP-12-017).
                      Semantics(
                        header: true,
                        child: Text(
                          _callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _callerNumber,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.phone_callback_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _ringtoneError
                                ? "fake_call_no_audio".tr()
                                : "fake_call_calling".tr(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 70,
                    left: 50,
                    right: 50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCallButton(
                        AppColors.emergency,
                        Icons.call_end_rounded,
                        "fake_call_decline".tr(),
                        () {
                          HapticFeedback.heavyImpact();
                          _stopRingtone();
                          ActivityService.logEvent(
                            type: ActivityType.fakeCallUsed,
                            title: "fake_call_activity_title".tr(),
                            description: "fake_call_declined_desc".tr(
                              namedArgs: {"name": _callerName},
                            ),
                          );
                          Navigator.pop(context);
                        },
                      ),
                      _buildCallButton(
                        AppColors.success,
                        Icons.call_rounded,
                        "fake_call_accept".tr(),
                        () {
                          HapticFeedback.mediumImpact();
                          _stopRingtone();
                          ActivityService.logEvent(
                            type: ActivityType.fakeCallUsed,
                            title: "fake_call_activity_title".tr(),
                            description: "fake_call_accepted_desc".tr(
                              namedArgs: {"name": _callerName},
                            ),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(
    Color color,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showCustomizeDialog() {
    final nameController = TextEditingController(text: _callerName);
    final phoneController = TextEditingController(text: _callerNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF10263A),
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "fake_call_settings_title".tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              // Preset scenario templates
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildTemplateChip(
                      nameController,
                      phoneController,
                      'fake_template_boss'.tr(),
                      '',
                    ),
                    const SizedBox(width: 8),
                    _buildTemplateChip(
                      nameController,
                      phoneController,
                      'fake_template_spouse'.tr(),
                      '',
                    ),
                    const SizedBox(width: 8),
                    _buildTemplateChip(
                      nameController,
                      phoneController,
                      'fake_template_mom'.tr(),
                      '',
                    ),
                    const SizedBox(width: 8),
                    _buildTemplateChip(
                      nameController,
                      phoneController,
                      'fake_template_custom'.tr(),
                      '',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                maxLength: 40,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "fake_call_caller_name".tr(),
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0B1F32),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickProfileImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text("fake_call_pick_photo".tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 20,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "fake_call_phone_number".tr(),
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0B1F32),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _callerName = nameController.text.isEmpty
                          ? "fake_call_default_name".tr()
                          : nameController.text;
                      _callerNumber = phoneController.text.isEmpty
                          ? "fake_call_default_number".tr()
                          : phoneController.text;
                    });
                    await _secureStorage.write(
                      key: _keyName,
                      value: _callerName,
                    );
                    await _secureStorage.write(
                      key: _keyNumber,
                      value: _callerNumber,
                    );
                    if (_avatarPath != null) {
                      await _secureStorage.write(
                        key: _keyAvatar,
                        value: _avatarPath!,
                      );
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  Future<void> _pickProfileImage() async {
    if (kIsWeb) {
      if (mounted) {
        _showWarningSnack('fake_call_photo_pick_failed'.tr());
      }
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final targetPath = '${dir.path}/fake_call_avatar.$ext';
      final saved = await File(picked.path).copy(targetPath);
      if (mounted) {
        setState(() => _avatarPath = saved.path);
      }
    } catch (_) {
      if (mounted) {
        _showWarningSnack('fake_call_photo_pick_failed'.tr());
      }
    }
  }

  void _showWarningSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTemplateChip(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    String label,
    String phone,
  ) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        nameCtrl.text = label;
        if (phone.isNotEmpty) phoneCtrl.text = phone;
      },
    );
  }
}
