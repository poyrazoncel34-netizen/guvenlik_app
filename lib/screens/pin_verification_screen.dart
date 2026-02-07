import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/services/contact_service.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _loadPin();
    _loadEmergencyContact();
    _startTimer();
  }

  Future<void> _loadPin() async {
    final secureValue = await _secureStorage.read(key: SecureStorageKeys.userPin);
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

  // --- ARANACAK NUMARAYI BUL VE ARA ---
  Future<void> _triggerSOS() async {
    // 1. Kayıtlı numarayı getir
    final emergencyNumber = await ContactService.getEmergencyNumber();

    // 2. Numara varsa aramayı başlat
    if (emergencyNumber != null && emergencyNumber.isNotEmpty) {
      final Uri url = Uri(scheme: 'tel', path: emergencyNumber);
      try {
        final launched = await launchUrl(url);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Arama başlatılamadı")),
          );
        }
      } catch (e) {
        debugPrint("Arama hatası: $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aranacak kayıtlı numara yok!")),
        );
      }
    }

    // İşlem bitince ekranı kapat
    if (mounted) {
      Navigator.pop(context);
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
          const SnackBar(
            content: Text("Güvendesiniz. Alarm iptal edildi."),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _enteredPin = ""; // Yanlış şifre
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PIN eşleşmedi, tekrar deneyin."),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                border: Border.all(color: AppColors.emergency.withValues(alpha: 0.4)),
              ),
              child: const Text(
                "GÜVENLİK DOĞRULAMASI",
                style: TextStyle(color: AppColors.emergency, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "$_timeLeft",
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 80, fontWeight: FontWeight.w800),
            ),
            const Text(
              "saniye içinde PIN girilmezse\nACİL ARAMA YAPILACAK",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_emergencyContact != null)
              Text(
                "Acil kişi: ${_emergencyContact!.name}",
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 10),
            const Text(
              "İstediğiniz an PIN girerek işlemi iptal edebilirsiniz.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                    color: index < _enteredPin.length ? AppColors.emergency : AppColors.border,
                  ),
                );
              }),
            ),
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
                  if (index == 11) { // Silme Tuşu
                    return IconButton(
                      icon: const Icon(Icons.backspace, color: AppColors.textPrimary),
                      onPressed: () {
                        setState(() {
                          if (_enteredPin.isNotEmpty) {
                            _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
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
                    child: Text(number, style: const TextStyle(fontSize: 24, color: AppColors.textPrimary)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
