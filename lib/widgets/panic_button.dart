// ============================================================================
// PANİK BUTONU - DEAD MAN'S SWITCH
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Idle pulse animation (when not pressed)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

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
    return Semantics(
      label: 'Acil Durum Butonu',
      hint: 'Basılı tutarak acil yardım çağırın. İki saniye basılı tutun.',
      button: true,
      child: GestureDetector(
        onLongPressStart: _onPressStart,
        onLongPressEnd: _onPressEnd,
        child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings (shown when NOT armed)
          if (!_isArmed) ..._buildIdlePulseRings(),

          // Armed pulse rings (shown when armed)
          if (_isArmed) ..._buildArmedPulseRings(),

          // Main button
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: _isArmed ? 230 : 250,
            height: _isArmed ? 230 : 250,
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
                    size: _isArmed ? 80 : 90,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(_isArmed),
                    children: [
                      Text(
                        _isArmed ? "BIRAK = ACIL" : "BASILI TUT",
                        style: TextStyle(
                          fontSize: _isArmed ? 18 : 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: _isArmed ? 2.2 : 2.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isArmed ? "10 SANIYE GERİ SAYIM" : "GÜVENDE OLANA KADAR",
                        style: TextStyle(
                          fontSize: _isArmed ? 11 : 12,
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

  // Idle state pulse rings (blue/purple)
  List<Widget> _buildIdlePulseRings() {
    return [
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final opacity = (0.18 - (_pulseController.value * 0.12)).clamp(0.0, 1.0);
          return Container(
            width: 270 + (_pulseController.value * 45),
            height: 270 + (_pulseController.value * 45),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: opacity),
                width: 2.5,
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final opacity = (0.14 - (_pulseController.value * 0.09)).clamp(0.0, 1.0);
          return Container(
            width: 290 + (_pulseController.value * 25),
            height: 290 + (_pulseController.value * 25),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: opacity),
                width: 2,
              ),
            ),
          );
        },
      ),
    ];
  }

  // Armed state pulse rings (red - danger)
  List<Widget> _buildArmedPulseRings() {
    return [
      AnimatedBuilder(
        animation: _armedPulseController,
        builder: (context, child) {
          final value = _armedPulseController.value;
          return Container(
            width: 250 + (value * 30),
            height: 250 + (value * 30),
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
          return Container(
            width: 270 + (value * 40),
            height: 270 + (value * 40),
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
          return Container(
            width: 290 + (value * 50),
            height: 290 + (value * 50),
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
