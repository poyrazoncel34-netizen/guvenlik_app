// ============================================================================
// SAHTE ÇAĞRI
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/services/activity_service.dart';
import '../domain/models/activity_event.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  String _callerName = "Arkadaşım";
  String _callerNumber = "+90 555 XXX XX XX";
  String? _avatarPath;
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
    _startRingtone();
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
        _callerName = name ?? _callerName;
        _callerNumber = number ?? _callerNumber;
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
    if (mounted && (legacyName != null || legacyNumber != null || legacyAvatar != null)) {
      setState(() {
        _callerName = legacyName ?? _callerName;
        _callerNumber = legacyNumber ?? _callerNumber;
        _avatarPath = legacyAvatar ?? _avatarPath;
      });
    }
  }

  Future<void> _startRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/ringtone.wav'));
    } catch (_) {}
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                    ),
                    TextButton.icon(
                      onPressed: _showCustomizeDialog,
                      icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 18),
                      label: const Text("Ayarla", style: TextStyle(color: Colors.white70)),
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
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[850]),
                      child: _avatarPath != null && File(_avatarPath!).existsSync()
                          ? ClipOval(
                              child: Image.file(
                                File(_avatarPath!),
                                fit: BoxFit.cover,
                                width: 130,
                                height: 130,
                              ),
                            )
                          : const Icon(Icons.person_rounded, size: 70, color: Colors.white60),
                    ),
                    const SizedBox(height: 28),
                    Text(
                        _callerName, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text(_callerNumber,
                        style: const TextStyle(color: Colors.white54, fontSize: 19, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.phone_callback_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "sizi arıyor...",
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75), fontSize: 17, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 70, left: 50, right: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCallButton(AppColors.emergency, Icons.call_end_rounded, "Reddet", () {
                      _stopRingtone();
                      ActivityService.logEvent(
                        type: ActivityType.fakeCallUsed,
                        title: "Sahte Cagri Kullanildi",
                        description: "$_callerName'den gelen sahte cagri reddedildi",
                      );
                      Navigator.pop(context);
                    }),
                    _buildCallButton(AppColors.success, Icons.call_rounded, "Kabul Et", () {
                      _stopRingtone();
                      ActivityService.logEvent(
                        type: ActivityType.fakeCallUsed,
                        title: "Sahte Cagri Kullanildi",
                        description: "$_callerName'den gelen sahte cagri kabul edildi",
                      );
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(Color color, IconData icon, String label, VoidCallback onTap) {
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
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              const Text(
                "Sahte Çağrı Ayarları",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Arayan adı",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0B1F32),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                  label: const Text("Galeriden Fotoğraf Seç"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Telefon numarası",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0B1F32),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                      _callerName = nameController.text.isEmpty ? "Arkadaşım" : nameController.text;
                      _callerNumber = phoneController.text.isEmpty ? "+90 555 XXX XX XX" : phoneController.text;
                    });
                    await _secureStorage.write(key: _keyName, value: _callerName);
                    await _secureStorage.write(key: _keyNumber, value: _callerNumber);
                    if (_avatarPath != null) {
                      await _secureStorage.write(key: _keyAvatar, value: _avatarPath!);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Kaydet", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final targetPath = '${dir.path}/fake_call_avatar.$ext';
      final saved = await File(picked.path).copy(targetPath);
      if (mounted) {
        setState(() => _avatarPath = saved.path);
      }
    } catch (_) {}
  }
}
