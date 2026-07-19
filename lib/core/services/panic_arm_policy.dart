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
