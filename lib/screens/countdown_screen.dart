// ============================================================================
// GERİ SAYIM EKRANI
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/di/service_locator.dart';
import '../main.dart' show kFirebaseReady;
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/app_colors.dart';
import '../core/services/contact_service.dart';
import '../core/services/biometric_service.dart';
import '../core/services/sms_service.dart';
import '../domain/repositories/contacts_repository.dart';
import '../domain/repositories/emergency_repository.dart';
import '../domain/repositories/location_repository.dart';
import '../core/services/activity_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/offline_queue_service.dart';
import '../domain/models/activity_event.dart';
import 'emergency_call_screen.dart';

class CountdownScreen extends StatefulWidget {
  final bool isTestMode;

  const CountdownScreen({super.key, this.isTestMode = false});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with TickerProviderStateMixin {
  int _countdown = 10;
  Timer? _timer;
  String _pin = "";
  String? _correctPin; // null until loaded - no default fallback
  late AnimationController _shakeController;
  EmergencyContact? _emergencyContact;
  late final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();
  late final ContactsRepository _contactsRepository =
      serviceLocator<ContactsRepository>();
  EmergencyRepository? get _emergencyRepository =>
      kFirebaseReady ? serviceLocator<EmergencyRepository>() : null;
  late final SecureStorage _secureStorage = serviceLocator<SecureStorage>();
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadPin();
    _loadEmergencyContact();
    _checkBiometric();
    _startCountdown();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.instance.isAvailable();
    if (available && mounted) {
      final label = await BiometricService.instance.getBiometricLabel();
      setState(() {
        _biometricAvailable = true;
        _biometricLabel = label;
      });
      // Auto-prompt biometric on entry
      _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final success = await BiometricService.instance.authenticate(
      reason: "countdown_biometric_reason".tr(),
    );
    if (success && mounted) {
      _timer?.cancel();
      ActivityService.logEvent(
        type: ActivityType.emergencyCancelled,
        title: "countdown_cancelled_title".tr(),
        description: "countdown_cancelled_biometric".tr(namedArgs: {"label": _biometricLabel}),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "countdown_biometric_fail".tr(namedArgs: {"label": _biometricLabel}),
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
    // Legacy migration from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(SecureStorageKeys.userPin);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: SecureStorageKeys.userPin, value: legacy);
      await prefs.remove(SecureStorageKeys.userPin);
      if (mounted) setState(() => _correctPin = legacy);
    }
    // If still null, PIN was never set - this shouldn't happen because
    // auth_gate now forces PIN setup, but handle gracefully
  }

  Future<void> _loadEmergencyContact() async {
    final contact = await _contactsRepository.getPrimaryEmergencyContact();
    if (mounted) {
      setState(() => _emergencyContact = contact);
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
        HapticFeedback.mediumImpact();
      } else {
        timer.cancel();
        _makeEmergencyCall();
      }
    });
  }

  Future<void> _makeEmergencyCall() async {
    if (widget.isTestMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("countdown_test_complete".tr()),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    final numbers = await _contactsRepository.getAllEmergencyNumbers();
    if (numbers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("countdown_no_contact".tr())));
        Navigator.pop(context);
      }
      return;
    }

    final locationResult = await _locationRepository.getCurrentLocation();
    final lat = locationResult.position?.latitude;
    final lng = locationResult.position?.longitude;
    final message = locationResult.isSuccess && lat != null && lng != null
        ? "countdown_emergency_msg".tr(namedArgs: {"lat": "$lat", "lng": "$lng"})
        : "countdown_emergency_msg_no_loc".tr();

    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      await OfflineQueueService.instance.enqueue(
        OfflineEvent(
          type: 'emergency',
          title: "countdown_emergency_title".tr(),
          description: message,
          data: {'message': message, 'lat': lat, 'lng': lng},
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "countdown_offline_saved".tr(),
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (lat != null && lng != null) {
        await _emergencyRepository?.updateLocation(lat: lat, lng: lng);
      }
      try {
        await _emergencyRepository?.createEmergencyEvent(
          title: "countdown_emergency_title".tr(),
          message: message,
          lat: lat,
          lng: lng,
        );
      } catch (_) {
        // Continue even if Firebase fails - emergency must proceed
      }
    }

    await ActivityService.logEvent(
      type: ActivityType.emergencyTriggered,
      title: "countdown_emergency_title".tr(),
      description: "countdown_emergency_desc".tr(),
    );

    await SmsService.sendSms(numbers: numbers, message: message);

    final primaryNumber =
        _emergencyContact?.phone ?? (numbers.isNotEmpty ? numbers.first : null);
    if (primaryNumber != null && primaryNumber.isNotEmpty) {
      bool callMade = false;
      try {
        // Direct call — dials immediately without user confirmation (Android)
        await FlutterDirectCallerPlugin.callNumber(primaryNumber);
        callMade = true;
      } catch (_) {
        callMade = false;
      }
      if (!callMade) {
        // Fallback: open dialer with the number pre-filled
        try {
          final telUri = Uri(scheme: 'tel', path: primaryNumber);
          await launchUrl(telUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyCallScreen(
            name: _emergencyContact?.name ?? "countdown_emergency_label".tr(),
            phone: primaryNumber ?? "",
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _handlePinInput(String key) {
    HapticFeedback.lightImpact();

    if (key == "DEL") {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }

    if (_pin.length < 4) {
      setState(() => _pin += key);

      if (_pin.length == 4) {
        if (_correctPin != null && _pin == _correctPin) {
          _timer?.cancel();
          ActivityService.logEvent(
            type: ActivityType.emergencyCancelled,
            title: "countdown_cancelled_title".tr(),
            description: "countdown_cancelled_pin".tr(),
          );
          Navigator.pop(context);
        } else {
          _shakeController.forward(from: 0);
          HapticFeedback.vibrate();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _pin = "");
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.emergency.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: AppColors.emergency,
                      size: 26,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "countdown_warning_title".tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isTestMode) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    "countdown_test_mode".tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 50),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: _countdown / 10,
                      strokeWidth: 14,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _countdown > 5
                            ? AppColors.warning
                            : AppColors.emergency,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        "$_countdown",
                        style: TextStyle(
                          fontSize: 70,
                          fontWeight: FontWeight.w900,
                          color: _countdown > 5
                              ? AppColors.warning
                              : AppColors.emergency,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "countdown_seconds".tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Text(
                "countdown_enter_pin".tr(),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_emergencyContact != null) ...[
                const SizedBox(height: 6),
                Text(
                  "countdown_emergency_contact".tr(namedArgs: {"name": _emergencyContact!.name}),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                "countdown_disclaimer".tr(),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_biometricAvailable) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _authenticateWithBiometric,
                  icon: Icon(
                    _biometricLabel == 'Face ID'
                        ? Icons.face_rounded
                        : Icons.fingerprint_rounded,
                    size: 22,
                  ),
                  label: Text("countdown_biometric_cancel".tr(namedArgs: {"label": _biometricLabel})),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
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
              const Spacer(),
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = sin(_shakeController.value * pi * 4) * 12;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _pin.length
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 50),
              _buildNumberPad(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox();
        if (index == 11) {
          return _buildPadButton(
            child: const Icon(Icons.backspace_outlined, size: 26),
            onTap: () => _handlePinInput("DEL"),
          );
        }
        final value = index == 10 ? "0" : "${index + 1}";
        return _buildPadButton(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          onTap: () => _handlePinInput(value),
        );
      },
    );
  }

  Widget _buildPadButton({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
