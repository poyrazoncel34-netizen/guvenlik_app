import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/emergency_session_contract.dart';
import '../services/pin_verification_service.dart';
import 'safety_session_pin_gate.dart';

/// PIN gate for destructive or data-disclosing actions that are NOT an armed
/// safety session (data export, sharing the local record).
///
/// It differs from [SafetySessionPinGate] in exactly one way: when no PIN is
/// configured the action is allowed. A user who never set a lock has nothing
/// for this gate to protect, and blocking them would deny access to their own
/// data (KVKK portability) in the name of a lock they did not ask for.
///
/// A PIN that exists but cannot be read is treated as "locked", not "absent".
class SensitiveActionPinGate {
  SensitiveActionPinGate._();

  static Future<bool> ensure(
    BuildContext context, {
    PinVerificationService? verificationService,
  }) async {
    final service = verificationService ?? PinVerificationService.instance;
    final state = await service.loadState();
    if (!context.mounted) return false;

    switch (state) {
      case PinState.absent:
        return true;
      case PinState.configured:
        return SafetySessionPinGate.verify(
          context,
          verificationService: service,
        );
      case PinState.loading:
      case PinState.readFailed:
        // Never downgrade an unreadable lock into no lock: that is exactly the
        // state an attacker can provoke by exhausting or corrupting storage.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('pin_state_read_failed'.tr()),
            backgroundColor: AppColors.emergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
    }
  }
}
