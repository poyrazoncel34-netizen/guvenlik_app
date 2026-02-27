import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/services/contact_service.dart';
import '../core/services/biometric_service.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_call_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  const PinVerificationScreen({super.key});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  int _timeLeft = 10;
  Timer? _timer;
  String _enteredPin = "";
  String? _correctPin; // Loaded from secure storage
  EmergencyContact? _emergencyContact;
  late final SecureStorage _secureStorage = serviceLocator<SecureStorage>();
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric'; // Updated by _checkBiometric()

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Ekran açık kalsın - cepte olsa bile geri sayım tamamlansın
    _loadPin();
    _loadEmergencyContact();
    _checkBiometric();
    _startTimer();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.instance.isAvailable();
    if (available && mounted) {
      final label = await BiometricService.instance.getBiometricLabel();
      setState(() {
        _biometricAvailable = true;
        _biometricLabel = label;
      });
      _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final success = await BiometricService.instance.authenticate(
      reason: "pin_verify_biometric_reason".tr(),
    );
    if (success && mounted) {
      _timer?.cancel();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("pin_verify_safe_cancelled".tr()),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "pin_verify_biometric_fail".tr(namedArgs: {"label": _biometricLabel}),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadPin() async {
    final secureValue = await _secureStorage.read(
      key: SecureStorageKeys.userPin,
    );
    if (secureValue != null && secureValue.isNotEmpty) {
      if (mounted) setState(() => _correctPin = secureValue);
      return;
    }
    // Legacy fallback: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(SecureStorageKeys.userPin);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: SecureStorageKeys.userPin, value: legacy);
      await prefs.remove(SecureStorageKeys.userPin);
      if (mounted) setState(() => _correctPin = legacy);
    }
  }

  Future<void> _loadEmergencyContact() async {
    final contact = await ContactService.getEmergencyContact();
    if (mounted) {
      setState(() => _emergencyContact = contact);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        _triggerSOS(); // SÜRE BİTTİ! ARAMAYI BAŞLAT!
      }
    });
  }

  // --- ARANACAK NUMARAYI BUL VE DOĞRUDAN ARA (onay penceresi olmadan) ---
  Future<void> _triggerSOS() async {
    final emergencyNumber = await ContactService.getEmergencyNumber();

    if (emergencyNumber != null && emergencyNumber.isNotEmpty) {
      try {
        FlutterDirectCallerPlugin.callNumber(emergencyNumber);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyCallScreen(
                name: _emergencyContact?.name ?? "pin_verify_emergency_contact".tr(),
                phone: emergencyNumber,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Arama hatası: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("pin_verify_call_failed".tr())),
          );
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("pin_verify_no_number".tr())),
        );
        Navigator.pop(context);
      }
    }
  }

  void _onNumberPress(String number) {
    setState(() {
      if (_enteredPin.length < 4) {
        _enteredPin += number;
      }
    });

    if (_enteredPin.length == 4) {
      if (_correctPin != null && _enteredPin == _correctPin) {
        _timer?.cancel();
        Navigator.pop(context); // Şifre doğru, iptal et
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("pin_verify_safe_cancelled".tr()),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _enteredPin = ""; // Yanlış şifre
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("pin_mismatch".tr()),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "semantics_pin_verify".tr(),
      hint: "semantics_pin_verify_hint".tr(),
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.emergency.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.emergency.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                "pin_verify_title".tr(),
                style: TextStyle(
                  color: AppColors.emergency,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "$_timeLeft",
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 80,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              "pin_verify_countdown_warning".tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_emergencyContact != null)
              Text(
                "pin_verify_emergency_name".tr(namedArgs: {"name": _emergencyContact!.name}),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              "pin_verify_cancel_hint".tr(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 40),
            // Şifre Noktaları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPin.length
                        ? AppColors.emergency
                        : AppColors.border,
                  ),
                );
              }),
            ),
            if (_biometricAvailable) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _authenticateWithBiometric,
                icon: Icon(
                  _biometricLabel == 'Face ID'
                      ? Icons.face_rounded
                      : Icons.fingerprint_rounded,
                  size: 22,
                ),
                label: Text("pin_verify_biometric_cancel_btn".tr(namedArgs: {"label": _biometricLabel})),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            // Numara Tuşları
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) return const SizedBox();
                  if (index == 11) {
                    // Silme Tuşu
                    return IconButton(
                      icon: const Icon(
                        Icons.backspace,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_enteredPin.isNotEmpty) {
                            _enteredPin = _enteredPin.substring(
                              0,
                              _enteredPin.length - 1,
                            );
                          }
                        });
                      },
                    );
                  }
                  String number = index == 10 ? "0" : "${index + 1}";
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBg,
                      shape: const CircleBorder(),
                    ),
                    onPressed: () => _onNumberPress(number),
                    child: Text(
                      number,
                      style: const TextStyle(
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
