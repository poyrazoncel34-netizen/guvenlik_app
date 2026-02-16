// ============================================================================
// PANİK BUTONU - DEAD MAN'S SWITCH
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../screens/pin_verification_screen.dart';

class PanicButton extends StatefulWidget {
  const PanicButton({super.key});

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _armedPulseController;
  bool _isArmed = false;

  @override
  void initState() {
    super.initState();

    // Idle pulse animation (disabled to prevent unwanted movement)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 0.5, // Static position - no animation
    );

    // Armed pulse animation (when pressed/holding)
    _armedPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _armedPulseController.dispose();
    super.dispose();
  }

  void _onPressStart(LongPressStartDetails details) {
    HapticFeedback.heavyImpact();
    setState(() => _isArmed = true);

    // Start armed pulse
    _armedPulseController.repeat(reverse: true);
  }

  void _onPressEnd(LongPressEndDetails details) {
    setState(() => _isArmed = false);
    _armedPulseController.stop();
    _armedPulseController.reset();

    // Vibrate and navigate to PIN verification
    HapticFeedback.vibrate();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PinVerificationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortSide = size.shortestSide;
    // Scale button to ~38% of shortest side, clamped for small phones and large tablets
    final baseSize = (shortSide * 0.38).clamp(160.0, 240.0);
    final buttonSize = _isArmed ? baseSize * 0.92 : baseSize;
    final iconSize = (baseSize * 0.34).clamp(56.0, 88.0);
    final titleFontSize = (baseSize * 0.092).clamp(14.0, 24.0);
    final subtitleFontSize = (baseSize * 0.048).clamp(10.0, 13.0);

    return Semantics(
      label: "panic_button_semantics_label".tr(),
      hint: "panic_button_semantics_hint".tr(),
      button: true,
      child: GestureDetector(
        onLongPressStart: _onPressStart,
        onLongPressEnd: _onPressEnd,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings (shown when NOT armed)
          if (!_isArmed) ..._buildIdlePulseRings(baseSize),

          // Armed pulse rings (shown when armed)
          if (_isArmed) ..._buildArmedPulseRings(baseSize),

          // Main button
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
                    : [AppColors.primaryDark, AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isArmed ? AppColors.emergency : AppColors.primary)
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
                    key: ValueKey(_isArmed),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isArmed ? "BIRAK = ACIL" : "BASILI TUT",
                        style: TextStyle(
                          fontSize: _isArmed ? titleFontSize * 0.75 : titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: _isArmed ? 2.2 : 2.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isArmed ? "10 SANIYE GERİ SAYIM" : "GÜVENDE OLANA KADAR",
                        style: TextStyle(
                          fontSize: _isArmed ? subtitleFontSize * 0.95 : subtitleFontSize,
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
        ],
      ),
      ),
    );
  }

  // Idle state static rings (no animation) - scaled to baseSize
  List<Widget> _buildIdlePulseRings(double baseSize) {
    final scale = baseSize / 250;
    return [
      Container(
        width: 285 * scale,
        height: 285 * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 2.5,
          ),
        ),
      ),
      Container(
        width: 305 * scale,
        height: 305 * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
            width: 2,
          ),
        ),
      ),
    ];
  }

  // Armed state pulse rings (red - danger) - scaled to baseSize
  List<Widget> _buildArmedPulseRings(double baseSize) {
    final scale = baseSize / 250;
    return [
      AnimatedBuilder(
        animation: _armedPulseController,
        builder: (context, child) {
          final value = _armedPulseController.value;
          final size = (250 + (value * 30)) * scale;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emergency.withValues(alpha: 0.6 - (value * 0.4)),
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
          final size = (270 + (value * 40)) * scale;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emergency.withValues(alpha: 0.4 - (value * 0.3)),
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
          final size = (290 + (value * 50)) * scale;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.emergency.withValues(alpha: 0.25 - (value * 0.2)),
                width: 2,
              ),
            ),
          );
        },
      ),
    ];
  }
}
