import 'arm_remedy.dart';
import 'emergency_result_policy.dart';
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
  /// Without exact-alarm access there is no native backup at all, so it is
  /// NOT here (Y-11, owner decision 2026-10-09): a dialer-only countdown looked
  /// exactly like a protected one, and a process death during it called nobody.
  static const Set<String> _foregroundDialReasons = <String>{
    'callPermissionDenied',
    'notificationsDisabled',
    'alertChannelNotHigh',
  };

  /// Authorization and target refusals. Offering a call for one of these would
  /// bypass the gate that refused (entitlement, PIN) or dial a number that
  /// failed validation, so the dialog offers only their fix.
  static const Set<String> _gateRefusals = <String>{
    'entitlementDenied',
    'entitlementUnknown',
    'pinNotConfigured',
    'pinReadFailed',
    'targetNotCallable',
    'callableTargetMissing',
    'invalidTarget',
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
      'callableTargetMissing' ||
      'invalidTarget' => 'timer_emergency_contact_required',
      'exactAlarmDenied' => EmergencyResultPolicy.exactAlarmRequiredBodyKey,
      _ => 'safety_session_not_ready',
    };
  }

  /// The one-tap fix the blocked-arm dialog offers, or null when nothing on
  /// this device can remove the refusal (no telephony, a protocol mismatch, a
  /// code this build does not know); the manual call is then all there is.
  ///
  /// The three foreground-dial refusals never reach the dialog (Y-11), but
  /// they are mapped too: the dialog walks the capabilities in native order
  /// after the user returns from Settings, and the sequential setup asks for
  /// the same four.
  static ArmRemedy? remedyFor(ArmResult result) {
    if (result is! ArmRejected) return null;
    return switch (result.reasonCode) {
      'entitlementDenied' || 'entitlementUnknown' => ArmRemedy.subscription,
      'pinNotConfigured' => ArmRemedy.pinSetup,
      'pinReadFailed' => ArmRemedy.pinSettings,
      'targetNotCallable' ||
      'callableTargetMissing' ||
      'invalidTarget' => ArmRemedy.emergencyContact,
      // The alarm could not be scheduled after the capability check passed:
      // access revoked in between is the common cause. If it is in fact on,
      // the dialog's own readiness probe drops the button.
      'exactAlarmDenied' || 'exactAlarmScheduleFailed' => ArmRemedy.exactAlarm,
      'callPermissionDenied' => ArmRemedy.callPermission,
      'notificationsDisabled' => ArmRemedy.notifications,
      'alertChannelNotHigh' => ArmRemedy.alertChannel,
      _ => null,
    };
  }

  /// [blockedMessageKey] and [remedyFor] as one value: the countdown hands the
  /// dialog both in a single argument, so a sentence cannot be paired with
  /// another refusal's fix.
  static ArmRefusal refusalFor(ArmResult result) =>
      ArmRefusal(bodyKey: blockedMessageKey(result), remedy: remedyFor(result));

  /// Number the blocked-arm dialog may offer for a MANUAL call, or ''.
  ///
  /// Every native refusal except the gate refusals qualifies (2026-11-02,
  /// owner decision): a missing bridge (A-005), missing exact-alarm access
  /// (Y-11: "call your contact now" beside "turn on background protection"),
  /// a device without telephony, a protocol mismatch, a code this build does
  /// not know. By the time the native arm is invoked, entitlement, PIN and a
  /// callable target have already been verified in Dart, and [armedTarget] is
  /// set only after that; what is absent is the automatic, Doze-proof session.
  /// The system dialer is reached over a separate channel, so the user is
  /// offered it at once instead of a dialog with nothing to press. Gate
  /// refusals get their fix instead ([remedyFor]): a call there would bypass
  /// the gate that refused.
  static String manualDialNumber(ArmResult result, String? armedTarget) =>
      result is ArmRejected && !_gateRefusals.contains(result.reasonCode)
      ? (armedTarget ?? '')
      : '';

  /// Heading of the running countdown. A dialer-only countdown has no native
  /// session behind it, so a process death during it calls nobody; it must
  /// not carry the heading of a protected one (Y-11, owner decision).
  static String countdownTitleKey(ArmResult? result) =>
      result != null &&
          dispositionFor(result) == PanicArmDisposition.foregroundDialCountdown
      ? 'countdown_limited_protection_title'
      : 'countdown_warning_title';

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
