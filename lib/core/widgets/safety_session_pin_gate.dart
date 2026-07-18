import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../constants/app_constants.dart';
import '../services/emergency_session_contract.dart';
import '../services/pin_verification_service.dart';

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
        builder: (_) => _SafetyPinDialog(service: service),
      );
      return verified == true;
    } catch (_) {
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
    if (!mounted) return;
    if (result.state == PinState.configured && result.matches) {
      Navigator.pop(context, true);
      return;
    }
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
