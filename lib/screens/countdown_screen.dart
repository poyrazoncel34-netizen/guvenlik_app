// ============================================================================
// GERİ SAYIM EKRANI – DRAMATIC UX (Gradient arc, pulsating glow, scale bounce)
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/di/service_locator.dart';
import '../core/security/secure_storage.dart';
import '../core/security/secure_storage_keys.dart';
import '../core/app_colors.dart';
import '../core/services/contact_service.dart';
import '../core/services/biometric_service.dart';
import '../core/services/sms_service.dart';
import '../domain/repositories/contacts_repository.dart';
// Emergency repository removed (offline-first)
import '../domain/repositories/location_repository.dart';
import '../core/services/activity_service.dart';
import '../core/services/call_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/offline_queue_service.dart';
import '../domain/models/activity_event.dart';
import 'emergency_call_screen.dart';
import '../core/services/foreground_service.dart';
import '../core/services/haptic_service.dart';

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
  String? _correctPin;
  late AnimationController _shakeController;
  late AnimationController _tickBounceController;
  late AnimationController _glowController;
  EmergencyContact? _emergencyContact;
  late final LocationRepository _locationRepository =
      serviceLocator<LocationRepository>();
  late final ContactsRepository _contactsRepository =
      serviceLocator<ContactsRepository>();
  // Offline-first: No EmergencyRepository (Firebase removed)
  late final SecureStorage _secureStorage = serviceLocator<SecureStorage>();
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biometric';
  bool _handoffToEmergencyScreen = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tickBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _loadPin();
    _loadEmergencyContact();
    _checkBiometric();
    _startCountdown();
    KoruBeniForegroundService.start();
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
      reason: "countdown_biometric_reason".tr(),
    );
    if (success && mounted) {
      _timer?.cancel();
      ActivityService.logEvent(
        type: ActivityType.emergencyCancelled,
        title: "countdown_cancelled_title".tr(),
        description: "countdown_cancelled_biometric".tr(
          namedArgs: {"label": _biometricLabel},
        ),
      );
      KoruBeniForegroundService.stop();
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "countdown_biometric_fail".tr(
              namedArgs: {"label": _biometricLabel},
            ),
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
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(SecureStorageKeys.userPin);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: SecureStorageKeys.userPin, value: legacy);
      await prefs.remove(SecureStorageKeys.userPin);
      if (mounted) setState(() => _correctPin = legacy);
    }
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
        HapticService.countdownTick(secondsRemaining: _countdown);
        // ── Tick bounce animation ──
        _tickBounceController.forward(from: 0);
      } else {
        timer.cancel();
        _makeEmergencyCall();
      }
    });
  }

  Future<void> _makeEmergencyCall() async {
    if (widget.isTestMode) {
      await KoruBeniForegroundService.stop();
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
      await KoruBeniForegroundService.stop();
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
        ? "countdown_emergency_msg".tr(
            namedArgs: {"lat": "$lat", "lng": "$lng"},
          )
        : "countdown_emergency_msg_no_loc".tr();

    final isOnline = ConnectivityService.instance.isOnline;

    if (isOnline) {
      try {
        // Offline-first: No cloud sync, emergency handled locally via EmergencyCoreService
        debugPrint('Emergency event logged locally (no Firebase)');
        if (lat != null && lng != null) {
          debugPrint('Location: $lat, $lng');
        }
        debugPrint('Message: $message');
      } catch (e) {
        debugPrint('>>> API failed, SMS fallback active: $e');
      }
    } else {
      await OfflineQueueService.instance.enqueue(
        OfflineEvent(
          type: 'emergency',
          title: "countdown_emergency_title".tr(),
          description: message,
          data: {'message': message, 'lat': lat, 'lng': lng},
        ),
      );
    }

    await ActivityService.logEvent(
      type: ActivityType.emergencyTriggered,
      title: "countdown_emergency_title".tr(),
      description: "countdown_emergency_desc".tr(),
    );

    await HapticService.emergencyTriggered();
    final smsResult = await SmsService.sendSms(
      numbers: numbers,
      message: message,
    );

    final primaryNumber =
        _emergencyContact?.phone ?? (numbers.isNotEmpty ? numbers.first : null);
    final callResult = primaryNumber != null && primaryNumber.isNotEmpty
        ? await CallService.startEmergencyCall(primaryNumber)
        : EmergencyCallResult.failed('');

    if (!smsResult.isSuccess && !callResult.isSuccess) {
      await KoruBeniForegroundService.stop();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('emergency_action_failed'.tr())));
        Navigator.pop(context);
      }
      return;
    }

    if (mounted) {
      _handoffToEmergencyScreen = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyCallScreen(
            name: _emergencyContact?.name ?? "countdown_emergency_label".tr(),
            phone: primaryNumber ?? "",
            callStatusMessage: callResult.statusMessage,
            smsStatusMessage: smsResult.statusMessage,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _tickBounceController.dispose();
    _glowController.dispose();
    if (!_handoffToEmergencyScreen) {
      KoruBeniForegroundService.stop();
    }
    super.dispose();
  }

  void _cancelWithoutPin() {
    _timer?.cancel();
    ActivityService.logEvent(
      type: ActivityType.emergencyCancelled,
      title: "countdown_cancelled_title".tr(),
      description: "emergency_cancelled_no_pin".tr(),
    );
    KoruBeniForegroundService.stop();
    Navigator.pop(context);
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
          KoruBeniForegroundService.stop();
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
    final isUrgent = _countdown <= 5;
    final urgentColor = isUrgent ? AppColors.emergency : AppColors.warning;

    return Semantics(
      label: "semantics_countdown".tr(),
      hint: "semantics_countdown_hint".tr(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            // ── Pulsating background glow in last 5 seconds ──
            final glowAlpha = isUrgent
                ? (0.03 + _glowController.value * 0.08)
                : 0.0;
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.emergency.withValues(alpha: glowAlpha),
                    AppColors.background,
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Warning banner
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
                  // ── Countdown circle with gradient arc + tick bounce ──
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gradient arc
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                          painter: _GradientArcPainter(
                            progress: _countdown / 10,
                            startColor: urgentColor,
                            endColor: isUrgent
                                ? const Color(0xFFFF8A65)
                                : AppColors.primary,
                            bgColor: AppColors.border.withValues(alpha: 0.5),
                            strokeWidth: 14,
                          ),
                        ),
                      ),
                      // Bouncing countdown number
                      AnimatedBuilder(
                        animation: _tickBounceController,
                        builder: (context, child) {
                          final bounceScale =
                              1.0 +
                              (sin(_tickBounceController.value * pi) * 0.12);
                          return Transform.scale(
                            scale: bounceScale,
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              "$_countdown",
                              style: TextStyle(
                                fontSize: 70,
                                fontWeight: FontWeight.w900,
                                color: urgentColor,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Text(
                    _correctPin == null
                        ? "settings_pin_not_found".tr()
                        : "countdown_enter_pin".tr(),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_emergencyContact != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "countdown_emergency_contact".tr(
                        namedArgs: {"name": _emergencyContact!.name},
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _correctPin == null
                        ? "emergency_no_pin_warning".tr()
                        : "countdown_disclaimer".tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
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
                      label: Text(
                        "countdown_biometric_cancel".tr(
                          namedArgs: {"label": _biometricLabel},
                        ),
                      ),
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
                  ],
                  const Spacer(),
                  if (_correctPin != null) ...[
                    // ── PIN dots with shake ──
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final offset =
                            sin(_shakeController.value * pi * 4) * 12;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < _pin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutBack,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: isFilled ? 20 : 18,
                            height: isFilled ? 20 : 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled
                                  ? AppColors.primary
                                  : AppColors.border,
                              boxShadow: isFilled
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 50),
                    _buildNumberPad(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
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
    return _ScaleTapButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Scale-bounce micro-animation for numpad buttons
class _ScaleTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleTapButton({required this.child, required this.onTap});

  @override
  State<_ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<_ScaleTapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Gradient arc painter for the countdown circle
class _GradientArcPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final Color bgColor;
  final double strokeWidth;

  _GradientArcPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.bgColor,
    this.strokeWidth = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Gradient arc
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [startColor, endColor],
      );
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor;
  }
}
