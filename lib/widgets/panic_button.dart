// ============================================================================
// PANİK BUTONU - DEAD MAN'S SWITCH (PREMIUM BREATHING GLOW)
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/subscription_gate.dart';
import '../core/widgets/feature_warning_dialog.dart';
import '../presentation/providers/subscription_provider.dart';
import '../screens/countdown_screen.dart';

class PanicButton extends StatefulWidget {
  const PanicButton({super.key});

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _armedPulseController;
  late AnimationController _progressController;
  bool _isArmed = false;
  bool _countdownOpening = false;
  Timer? _hapticTimer;
  int _holdSeconds = 0;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();

    // ── Subtle breathing glow animation (idle) ──
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Armed pulse animation (when pressed/holding)
    _armedPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Progress ring animation (fills while holding)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    _armedPulseController.dispose();
    _progressController.dispose();
    _hapticTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _onPressStart(LongPressStartDetails details) async {
    _hapticTimer?.cancel();
    _holdTimer?.cancel();
    if (_isArmed) return;

    final allowed = await SubscriptionGate.ensureAccess(
      context,
      PremiumFeature.panic,
    );
    if (!allowed || !mounted) return;

    // İlk kullanımda uyarı dialogu göster; dialog varsa press iptal edilir.
    final shown = await FeatureWarningHelper.showIfNeeded(
      context,
      prefKey: AppConstants.prefWarningPanic,
      featureName: 'panic_button',
      title: FeatureWarningHelper.panicTitle,
      content: FeatureWarningHelper.panicContent,
    );
    if (!shown || !mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isArmed = true;
      _holdSeconds = 0;
    });

    // Start armed pulse
    _armedPulseController.repeat(reverse: true);

    // Start progress ring
    _progressController.forward(from: 0);

    // Periodic haptic feedback every 500ms
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      HapticFeedback.mediumImpact();
    });

    // Count seconds held
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _holdSeconds++);
      }
    });
  }

  void _onPressEnd(LongPressEndDetails details) {
    final wasArmed = _isArmed;
    setState(() => _isArmed = false);
    _armedPulseController.stop();
    _armedPulseController.reset();
    _progressController.stop();
    _progressController.reset();
    _hapticTimer?.cancel();
    _holdTimer?.cancel();
    _holdSeconds = 0;

    // Vibrate
    HapticFeedback.vibrate();

    if (!wasArmed) return;
    _openCountdownScreen();
  }

  void _openCountdownScreen() {
    if (_countdownOpening || !mounted) return;
    _countdownOpening = true;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CountdownScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).whenComplete(() => _countdownOpening = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<SubscriptionProvider>().isPro;
    final size = MediaQuery.sizeOf(context);
    final shortSide = size.shortestSide;
    // Scale button to ~38% of shortest side, clamped
    final baseSize = (shortSide * 0.38).clamp(160.0, 240.0);
    final buttonSize = _isArmed ? baseSize * 0.92 : baseSize;
    final iconSize = (baseSize * 0.34).clamp(56.0, 88.0);
    final titleFontSize = (baseSize * 0.092).clamp(14.0, 24.0);
    final subtitleFontSize = (baseSize * 0.048).clamp(10.0, 13.0);

    return Semantics(
      label: isPro
          ? "panic_button_semantics_label".tr()
          : "panic_button_locked_semantics_label".tr(),
      hint: isPro
          ? "panic_button_semantics_hint".tr()
          : "panic_button_locked_semantics_hint".tr(),
      button: true,
      child: GestureDetector(
        onLongPressStart: _onPressStart,
        onLongPressEnd: _onPressEnd,
        child: SizedBox(
          width: baseSize * 1.4,
          height: baseSize * 1.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Breathing glow rings (idle) ──
              if (!_isArmed && isPro) ..._buildBreathingRings(baseSize),

              // Armed pulse rings
              if (_isArmed) ..._buildArmedPulseRings(baseSize),

              // Progress ring (shown when armed)
              if (_isArmed)
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return SizedBox(
                      width: baseSize + 20,
                      height: baseSize + 20,
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          progress: _progressController.value,
                          color: AppColors.emergency,
                          strokeWidth: 4.0,
                        ),
                      ),
                    );
                  },
                ),

              // Main button with gradient
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isArmed
                        ? [AppColors.emergency, const Color(0xFFB32020)]
                        : isPro
                        ? [AppColors.primaryDark, AppColors.primary]
                        : [const Color(0xFF3A4656), const Color(0xFF222A35)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isArmed
                                  ? AppColors.emergency
                                  : isPro
                                  ? AppColors.primary
                                  : AppColors.textSecondary)
                              .withValues(alpha: _isArmed ? 0.7 : 0.5),
                      blurRadius: _isArmed ? 50 : 35,
                      spreadRadius: _isArmed ? 5 : 0,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        _isArmed ? Icons.warning_rounded : Icons.shield_rounded,
                        key: ValueKey(_isArmed),
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: baseSize * 0.048),

                    // Text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        key: ValueKey('$_isArmed$_holdSeconds'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isArmed
                                ? "panic_button_armed_title".tr()
                                : isPro
                                ? "panic_button_hold_title".tr()
                                : "panic_button_locked_title".tr(),
                            style: TextStyle(
                              fontSize: _isArmed
                                  ? titleFontSize * 0.75
                                  : titleFontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: _isArmed ? 2.2 : 2.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isArmed
                                ? "${_holdSeconds}s"
                                : isPro
                                ? "panic_button_hold_subtitle".tr()
                                : "panic_button_locked_subtitle".tr(),
                            style: TextStyle(
                              fontSize: _isArmed
                                  ? subtitleFontSize * 1.2
                                  : subtitleFontSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPro && !_isArmed)
                Positioned(
                  top: baseSize * 0.22,
                  right: baseSize * 0.18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'subscription_badge_pro'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Breathing glow rings (smooth, subtle) ──
  List<Widget> _buildBreathingRings(double baseSize) {
    final scale = baseSize / 250;
    return [
      // Outer glow ring
      AnimatedBuilder(
        animation: _breathController,
        builder: (context, child) {
          final value = _breathController.value;
          final ringSize = (300 + (value * 15)) * scale;
          return Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: 0.06 + (value * 0.06),
                ),
                width: 2,
              ),
            ),
          );
        },
      ),
      // Inner glow ring
      AnimatedBuilder(
        animation: _breathController,
        builder: (context, child) {
          final value = _breathController.value;
          final ringSize = (280 + (value * 10)) * scale;
          return Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: 0.1 + (value * 0.08),
                ),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: 0.03 + (value * 0.05),
                  ),
                  blurRadius: 15 + (value * 10),
                  spreadRadius: value * 3,
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  // Armed state pulse rings (red - danger) — scaled
  List<Widget> _buildArmedPulseRings(double baseSize) {
    final scale = baseSize / 250;
    return [
      AnimatedBuilder(
        animation: _armedPulseController,
        builder: (context, child) {
          final value = _armedPulseController.value;
          final ringSize = (250 + (value * 30)) * scale;
          return Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emergency.withValues(
                  alpha: 0.6 - (value * 0.4),
                ),
                width: 4,
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _armedPulseController,
        builder: (context, child) {
          final value = _armedPulseController.value;
          final ringSize = (270 + (value * 40)) * scale;
          return Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emergency.withValues(
                  alpha: 0.4 - (value * 0.3),
                ),
                width: 3,
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _armedPulseController,
        builder: (context, child) {
          final value = _armedPulseController.value;
          final ringSize = (290 + (value * 50)) * scale;
          return Container(
            width: ringSize,
            height: ringSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emergency.withValues(
                  alpha: 0.25 - (value * 0.2),
                ),
                width: 2,
              ),
            ),
          );
        },
      ),
    ];
  }
}

/// Custom painter for the progress ring around the panic button.
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
