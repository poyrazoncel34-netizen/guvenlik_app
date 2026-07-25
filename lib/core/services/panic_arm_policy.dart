import 'emergency_session_contract.dart';

/// Determines what the visible Panic countdown may do after the native arm
/// boundary responds. Authorization failures must never be collapsed into a
/// foreground dial fallback, while a small allowlist of platform capability
/// failures retains the acute, user-visible ACTION_DIAL path.
enum PanicArmDisposition {
  nativeProtectedCountdown,
  uncertainNativeCountdown,
  foregroundDialCountdown,
  blocked,
}

abstract final class PanicArmPolicy {
  static const Set<String> _foregroundDialReasons = <String>{
    'callPermissionDenied',
    'exactAlarmDenied',
    'notificationsDisabled',
    'alertChannelNotHigh',
  };

  /// Translation key explaining a blocked arm. Lives here, next to the
  /// disposition mapping it mirrors: two switches over the same reason codes
  /// in two files drift apart silently.
  static String blockedMessageKey(ArmResult result) {
    if (result is! ArmRejected) return 'safety_session_not_ready';
    return switch (result.reasonCode) {
      'entitlementDenied' ||
      'entitlementUnknown' => 'safety_session_entitlement_unverified',
      'pinNotConfigured' => 'safety_session_pin_required',
      'pinReadFailed' => 'pin_state_read_failed',
      'targetNotCallable' ||
      'callableTargetMissing' => 'timer_emergency_contact_required',
      _ => 'safety_session_not_ready',
    };
  }

  static PanicArmDisposition dispositionFor(ArmResult result) {
    if (result is Armed) {
      return PanicArmDisposition.nativeProtectedCountdown;
    }
    if (result is ArmUnknown) {
      return PanicArmDisposition.uncertainNativeCountdown;
    }
    if (result is ArmRejected &&
        _foregroundDialReasons.contains(result.reasonCode)) {
      return PanicArmDisposition.foregroundDialCountdown;
    }
    return PanicArmDisposition.blocked;
  }

  /// A rejected proposal is not an active native session. Its diagnostic
  /// token must never be passed to cancel/dispatch as if ARMED were durable.
  static SessionToken? activeOrUncertainToken(ArmResult result) =>
      switch (result) {
        Armed armed => armed.sessionToken,
        ArmUnknown unknown => unknown.uncertainToken,
        ArmRejected _ => null,
      };

  static bool shouldStartCountdown(ArmResult result) =>
      dispositionFor(result) != PanicArmDisposition.blocked;
}
