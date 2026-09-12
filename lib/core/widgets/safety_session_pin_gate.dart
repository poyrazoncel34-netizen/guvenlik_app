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
    bool enforceLockout = false,
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
        child: _SafetyPinDialog(service: service, enforceLockout: enforceLockout),
      ),
      );
      return verified == true;
    } on StateError catch (_) {
      // Dependency not wired. Fail closed: an unverified PIN must never be
      // reported as verified, because the caller uses that answer to cancel or
      // extend an armed session.
      debugPrint('SafetySessionPinGate: verification unavailable');
      return false;
    } on Exception catch (_) {
      debugPrint('SafetySessionPinGate: verification failed');
      return false;
    } finally {
      _dialogInProgress = false;
    }
  }
}

class _SafetyPinDialog extends StatefulWidget {
  const _SafetyPinDialog({required this.service, required this.enforceLockout});

  final bool enforceLockout;

  final PinVerificationService service;

  @override
  State<_SafetyPinDialog> createState() => _SafetyPinDialogState();
}

class _SafetyPinDialogState extends State<_SafetyPinDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _errorVisible = false;
  String? _policyError;
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
      _policyError = null;
    });
    if (widget.enforceLockout) {
      try {
        final state = await PinLockoutService.instance.getState();
        if (state.isLocked) {
          if (mounted) {
            setState(() {
              _verificationInProgress = false;
              _policyError = 'brute_force_locked'.tr(
                namedArgs: {'seconds': '${state.remainingSeconds}'},
              );
            });
          }
          return;
        }
      } catch (_) {
        // An unreadable counter cannot prove the attempt is allowed. Keep the
        // modal open and say so, rather than silently verifying unthrottled.
        if (mounted) {
          setState(() {
            _verificationInProgress = false;
            _policyError = 'pin_state_read_failed'.tr();
          });
        }
        return;
      }
      try {
        // Reserve this attempt durably before comparing the candidate. A disk
        // failure must not provide an uncounted guess on each reopened modal.
        await PinLockoutService.instance.registerFailure();
      } catch (_) {
        // The attempt could not be debited, so it must not be spent. Deny the
        // whole action instead of leaving an unmetered retry in the dialog.
        if (mounted) Navigator.pop(context, false);
        return;
      }
    }
    final result = await widget.service.verify(_controller.text);
    if (result.state == PinState.configured && result.matches) {
      // Clear the counter the same way the unlock screen does, so a legitimate
      // cancel does not leave the user one mistake away from a locked app.
      if (widget.enforceLockout) {
        try {
          await PinLockoutService.instance.reset();
        } catch (_) {
          if (mounted) {
            setState(() {
              _verificationInProgress = false;
              _policyError = 'pin_state_read_failed'.tr();
            });
          }
          return;
        }
      } else {
        await _recordLockout(reset: true);
      }
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
    if (!widget.enforceLockout) {
      await _recordLockout(reset: false);
    }
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
          errorText: _policyError ?? (_errorVisible ? 'settings_pin_wrong'.tr() : null),
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
