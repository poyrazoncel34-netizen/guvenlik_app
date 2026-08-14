import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../constants/app_constants.dart';
import '../services/emergency_session_contract.dart';
import '../services/pin_lockout_service.dart';
import '../services/pin_verification_service.dart';
import 'escape_dismissible.dart';

/// Fail-closed PIN gate for any user action that cancels or extends an armed
/// safety session. The configured PIN never enters widget state; only the
/// candidate is held for the lifetime of this modal.
class SafetySessionPinGate {
  SafetySessionPinGate._();

  static bool _dialogInProgress = false;

  static Future<bool> verify(
    BuildContext context, {
    PinVerificationService? verificationService,
  }) async {
    if (_dialogInProgress) return false;
    _dialogInProgress = true;
    final service = verificationService ?? PinVerificationService.instance;
    try {
      final state = await service.loadState();
      if (state != PinState.configured || !context.mounted) return false;

      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EscapeDismissible(
        autofocus: false,
        child: _SafetyPinDialog(service: service),
      ),
      );
      return verified == true;
    } on StateError catch (error) {
      // Dependency not wired. Fail closed: an unverified PIN must never be
      // reported as verified, because the caller uses that answer to cancel or
      // extend an armed session.
      debugPrint('SafetySessionPinGate: verification unavailable: $error');
      return false;
    } on Exception catch (error) {
      debugPrint('SafetySessionPinGate: verification failed: $error');
      return false;
    } finally {
      _dialogInProgress = false;
    }
  }
}

class _SafetyPinDialog extends StatefulWidget {
  const _SafetyPinDialog({required this.service});

  final PinVerificationService service;

  @override
  State<_SafetyPinDialog> createState() => _SafetyPinDialogState();
}

class _SafetyPinDialogState extends State<_SafetyPinDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _errorVisible = false;
  bool _verificationInProgress = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lockout bookkeeping that can never break the dialog above it.
  ///
  /// This gate cancels an ARMED session. If the counter cannot be read or
  /// written -- storage fault, dependency not wired -- the correct outcome is
  /// an unrecorded attempt, never a dialog that throws and leaves the user
  /// unable to stop a countdown. Types are named rather than swallowed wholesale
  /// so a genuine programming error still surfaces in tests.
  Future<void> _recordLockout({required bool reset}) async {
    try {
      if (reset) {
        await PinLockoutService.instance.reset();
      } else {
        await PinLockoutService.instance.registerFailure();
      }
    } on StateError catch (error) {
      debugPrint('SafetySessionPinGate: lockout unavailable: $error');
    } on Exception catch (error) {
      debugPrint('SafetySessionPinGate: lockout write failed: $error');
    }
  }

  Future<void> _submit() async {
    if (_verificationInProgress ||
        _controller.text.length != AppConstants.pinLength) {
      return;
    }
    setState(() {
      _verificationInProgress = true;
      _errorVisible = false;
    });
    final result = await widget.service.verify(_controller.text);
    if (result.state == PinState.configured && result.matches) {
      // Clear the counter the same way the unlock screen does, so a legitimate
      // cancel does not leave the user one mistake away from a locked app.
      await _recordLockout(reset: true);
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }
    // Wrong PIN. Record it against the SAME counter the unlock screen reads.
    //
    // This gate deliberately does NOT block or throttle on the lockout state,
    // unlike AppUnlockScreen. It guards cancelling or extending an ARMED
    // session: any delay imposed here is a delay in front of a user trying to
    // stop a call that is already counting down, and a legitimate user who
    // mistypes under stress must never be locked out of their own cancel.
    // Recording still closes the real hole -- unlimited attempts that left no
    // trace anywhere. Matches countdown_screen's treatment of the same trade.
    await _recordLockout(reset: false);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _verificationInProgress = false;
      _errorVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'reset_pin_verify_title'.tr(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        enabled: !_verificationInProgress,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(AppConstants.pinLength),
        ],
        decoration: InputDecoration(
          hintText: 'reset_pin_verify_hint'.tr(),
          errorText: _errorVisible ? 'settings_pin_wrong'.tr() : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verificationInProgress
              ? null
              : () => Navigator.pop(context, false),
          child: Text(
            'settings_cancel'.tr(),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _verificationInProgress ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emergency,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('reset_pin_verify_confirm'.tr()),
        ),
      ],
    );
  }
}
