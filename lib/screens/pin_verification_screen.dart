import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/services/contact_service.dart';
import '../core/services/call_service.dart';
import '../core/services/sms_service.dart';
import '../core/services/android_intent_service.dart';
import 'package:flutter/services.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/utils/emergency_message_helper.dart';
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

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Ekran açık kalsın - cepte olsa bile geri sayım tamamlansın
    _loadPin();
    _loadEmergencyContact();
    _startTimer();
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

  // --- DUAL-ACTION: SMS + ARAMA (ZERO-FAULT) ---
  Future<void> _triggerSOS() async {
    try {
      await _executeSOS();
    } catch (e) {
      debugPrint("SOS execution crashed: $e");
      if (mounted) {
        await _showBlockingFailure(
          title: 'emergency_total_failure_title'.tr(),
          body: 'emergency_total_failure_body'.tr(),
          phoneNumber: _emergencyContact?.phone ?? '',
        );
      }
    }
  }

  Future<void> _executeSOS() async {
    final emergencyNumber = await ContactService.getEmergencyNumber();

    if (emergencyNumber == null || emergencyNumber.isEmpty) {
      if (mounted) {
        await _showBlockingFailure(
          title: 'countdown_no_contact_title'.tr(),
          body: 'countdown_no_contact_body'.tr(),
          phoneNumber: '',
        );
      }
      return;
    }

    final messagePayload =
        await EmergencyMessageHelper.buildPanicButtonMessage();
    final smsMessage = messagePayload.message;

    final allNumbers = await ContactService.getAllEmergencyNumbers();
    final smsNumbers = allNumbers.isNotEmpty ? allNumbers : [emergencyNumber];
    final smsResult = await SmsService.sendSms(
      numbers: smsNumbers,
      message: smsMessage,
    );

    // NO permission dialog here. Check silently, use dialer fallback.
    final callResult = await CallService.startEmergencyCall(emergencyNumber);

    // BOTH completely failed — show blocking fullscreen error
    if (smsResult.isFailed && callResult.isFailed) {
      if (mounted) {
        await _showBlockingFailure(
          title: 'emergency_total_failure_title'.tr(),
          body: 'emergency_total_failure_body'.tr(),
          phoneNumber: emergencyNumber,
          emergencyMessage: smsMessage,
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyCallScreen(
            name:
                _emergencyContact?.name ??
                "pin_verify_emergency_contact".tr(),
            phone: emergencyNumber,
            callResult: callResult,
            smsResult: smsResult,
            locationStatusMessage: messagePayload.locationStatusMessage,
            emergencyMessage: smsMessage,
          ),
        ),
      );
    }
  }

  /// Shows a FULLSCREEN BLOCKING failure dialog. No snackbar. No silent path.
  Future<void> _showBlockingFailure({
    required String title,
    required String body,
    required String phoneNumber,
    String? emergencyMessage,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_rounded, color: AppColors.emergency, size: 42),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(body, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5), textAlign: TextAlign.center),
              if (phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Text(phoneNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5), textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
          actions: [
            if (phoneNumber.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async => await AndroidIntentService.openDialer(phoneNumber),
                  icon: const Icon(Icons.call, size: 20),
                  label: Text('emergency_manual_call_now'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergency, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            if (emergencyMessage != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: emergencyMessage));
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('emergency_message_copied'.tr()), backgroundColor: AppColors.success));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('emergency_copy_message'.tr()),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                child: Text('emergency_dismiss'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
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
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context); // Şifre doğru, iptal et
        messenger.showSnackBar(
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

  void _cancelWithoutPin() {
    _timer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text("emergency_cancelled_no_pin".tr()),
        backgroundColor: AppColors.warning,
      ),
    );
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
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
                  "pin_verify_emergency_name".tr(
                    namedArgs: {"name": _emergencyContact!.name},
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                _correctPin == null
                    ? "emergency_no_pin_warning".tr()
                    : "pin_verify_cancel_hint".tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              if (_correctPin == null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _cancelWithoutPin,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: Text("emergency_cancel_without_pin".tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ] else ...[
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
              ],
              const SizedBox(height: 40),
              if (_correctPin != null)
                // Numara Tuşları
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
