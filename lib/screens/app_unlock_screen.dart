// ============================================================================
// UYGULAMA KİLİDİ - Uygulama açılışında PIN ile doğrulama (PIN tek yöntem)
// SECURITY RULE: Biyometrik kimlik doğrulama YASAKTIR (duress riski).
// ============================================================================

import '../core/design_tokens.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/constants/app_constants.dart';
import '../core/services/app_reset_service.dart';
import '../core/services/emergency_session_contract.dart';
import '../core/services/pin_lockout_service.dart';
import '../core/services/pin_verification_service.dart';
import '../core/services/safety_session_activity_probe.dart';
import 'settings_legal/legal_settings_screen.dart';
import 'splash_screen.dart';
import '../core/widgets/escape_dismissible.dart';

class AppUnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppUnlockScreen({super.key, required this.onUnlocked});

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen> {
  String _pin = '';
  PinState _pinState = PinState.loading;
  bool _verifying = false;
  bool _loading = true;

  DateTime? _lockoutEndTime;
  StreamSubscription<int>? _lockoutSubscription;
  int _lockoutRemaining = 0;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadPinState();
    await _syncLockoutState();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  /// Loads only the non-secret [PinState]. The configured PIN is never copied
  /// into widget state: verification goes through [PinVerificationService],
  /// which owns the constant-time comparison.
  Future<void> _loadPinState() async {
    final state = await PinVerificationService.instance.loadState();
    if (mounted) {
      setState(() {
        _pinState = state;
      });
    }
  }

  bool get _isLockedOut =>
      _lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!);

  Future<void> _syncLockoutState() async {
    final state = await PinLockoutService.instance.getState();
    if (!mounted) return;
    setState(() {
      _lockoutEndTime = state.lockedUntil;
      _lockoutRemaining = state.remainingSeconds;
    });
    if (state.isLocked) {
      _startLockoutCountdown(state);
    }
  }

  void _startLockoutCountdown(PinLockoutState state) {
    _lockoutSubscription?.cancel();
    _lockoutSubscription = PinLockoutService.instance
        .countdownStream(state)
        .listen((remaining) {
          if (!mounted) {
            return;
          }
          setState(() {
            _lockoutRemaining = remaining;
            if (remaining == 0) {
              _lockoutEndTime = null;
            }
          });
        });
  }

  @override
  void dispose() {
    _lockoutSubscription?.cancel();
    super.dispose();
  }

  void _onPinKey(String key) {
    if (_isLockedOut) return;

    if (key == 'DEL') {
      setState(() {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      });
      return;
    }
    if (_pin.length >= AppConstants.pinLength) return;
    setState(() => _pin += key);

    if (_pin.length == AppConstants.pinLength &&
        _pinState != PinState.absent) {
      unawaited(_submitPin());
    }
  }

  Future<void> _submitPin() async {
    if (_verifying) return;
    _verifying = true;
    try {
      final candidate = _pin;
      final result = await PinVerificationService.instance.verify(candidate);
      if (!mounted) return;
      setState(() => _pinState = result.state);

      if (result.state == PinState.readFailed) {
        // A storage failure is not a wrong PIN. Never consume a lockout
        // attempt for it and never let it read as "no PIN configured".
        setState(() => _pin = '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pin_state_read_failed'.tr()),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (result.matches) {
        HapticFeedback.lightImpact();
        unawaited(PinLockoutService.instance.reset());
        widget.onUnlocked();
      } else {
        HapticFeedback.vibrate();
        setState(() => _pin = '');
        PinLockoutService.instance.registerFailure().then((state) {
          if (!mounted) return;
          setState(() {
            _lockoutEndTime = state.lockedUntil;
            _lockoutRemaining = state.remainingSeconds;
          });
          if (state.isLocked) {
            _startLockoutCountdown(state);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'brute_force_locked'.tr(
                    namedArgs: {'seconds': '${state.remainingSeconds}'},
                  ),
                ),
                backgroundColor: AppColors.emergency,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('unlock_wrong_pin'.tr()),
              backgroundColor: AppColors.emergency,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }).catchError((Object error, StackTrace stack) {
          debugPrint('PinLockoutService.registerFailure failed: $error');
        });
      }
    } finally {
      _verifying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'unlock_semantics'.tr(),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalSettingsScreen(),
                  ),
                ),
                tooltip: 'Yasal Bilgiler',
              ),
            ],
          ),
          body: SafeArea(
            // LayoutBuilder, not MediaQuery arithmetic.
            //
            // This used to compute minHeight as `screen.height - padding.top -
            // padding.bottom`, which ignores TWO things that are really there:
            // the Scaffold's AppBar, and this scroll view's own 24px vertical
            // padding. The Column was therefore forced taller than the viewport
            // it actually had. At the default density the slack absorbed it; at
            // a large display size the content grows and the mismatch surfaces
            // as a real overflow -- measured on an API 36 emulator at density
            // 560: "RenderFlex overflowed by 15 pixels on the bottom", with the
            // 0/backspace row clipped and "Sifremi Unuttum" off-screen.
            //
            // That is not cosmetic on this screen. PIN entry locks out after 5
            // failures, so an unreachable backspace turns a single mistyped
            // digit into a failed attempt.
            //
            // `constraints.maxHeight` is the height the scroll view actually
            // offers, with app bar, safe area and padding already subtracted.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: IconSizes.illustration,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'unlock_title'.tr(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'unlock_subtitle'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    if (_loading) ...[
                      const SizedBox(height: 32),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          AppConstants.pinLength,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _pin.length
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isLockedOut)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emergency.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.emergency.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_clock_rounded,
                                  color: AppColors.emergency,
                                  size: IconSizes.action,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'brute_force_locked_short'.tr(
                                    namedArgs: {
                                      'seconds': '$_lockoutRemaining',
                                    },
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.emergency,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _buildNumPad(),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _showForgotPinDialog,
                        child: Text(
                          'forgot_pin_title'.tr(),
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPinDialog() async {
    // Duress guard: this dialog runs BEFORE authentication and its confirm
    // action cancels every PREPARING/ARMED native session before deleting
    // local data. An attacker holding the device must not be able to silence
    // a running Check-In / Safe Walk without the PIN. Fail-closed: an
    // unreadable projection counts as "a session may be live".
    if (await SafetySessionActivityProbe.instance.hasActiveSession()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('forgot_pin_blocked_active_session'.tr()),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    if (!mounted) return;

    final confirmController = TextEditingController();
    final resetToken = 'forgot_pin_reset_token'.tr();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EscapeDismissible(
        autofocus: false,
        child: StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.emergency,
                size: IconSizes.dialog,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'forgot_pin_title'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'forgot_pin_reset_body'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: confirmController,
                  onChanged: (v) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'forgot_pin_reset_hint'.tr(),
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: confirmController.text == resetToken
                  ? () async {
                      Navigator.pop(ctx);
                      final wipe = await AppResetService.clearLocalData();
                      if (!mounted) return;
                      if (wipe != WipeResult.completed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('data_delete_pending'.tr())),
                        );
                        return;
                      }
                      Navigator.of(context).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) => const SplashScreen(),
                          transitionsBuilder: (_, a, _, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: Motion.slow,
                        ),
                        (_) => false,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                disabledBackgroundColor: AppColors.emergency.withValues(
                  alpha: 0.3,
                ),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'forgot_pin_reset_button'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      ),
    );
    confirmController.dispose();
  }

  Widget _buildNumPad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'DEL'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, i) {
        if (keys[i].isEmpty) return const SizedBox();
        return _numKey(keys[i], isIcon: keys[i] == 'DEL');
      },
    );
  }

  Widget _numKey(String key, {bool isIcon = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onPinKey(key),
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: isIcon
                ? const Icon(
                    Icons.backspace_outlined,
                    size: IconSizes.dialog,
                    color: AppColors.textPrimary,
                  )
                : Text(
                    key,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
