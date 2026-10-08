import 'emergency_platform_service.dart';
import 'emergency_session_contract.dart';
import 'safety_clock.dart';

/// A panic session native still holds ARMED after the screen that armed it
/// died with its process (chaos audit A-11).
///
/// Reproduced on an API 35 emulator: a countdown's process was killed at T+2;
/// reopening showed the splash and the unlock screen, never the countdown, and
/// native called at the deadline. The user lost the PIN-cancel surface for the
/// seconds that were still left.
///
/// Discovery only ADOPTS what native holds. It never arms, never revises and
/// never moves a deadline: the countdown that re-shows the session uses
/// native's token, deadline and target exactly as stored.
final class PanicReattachment {
  const PanicReattachment._(this.armed, this.target);

  /// The armed session, as native holds it.
  final Armed armed;

  /// The immutable arming-time target, for the foreground dial fallback.
  final String? target;

  /// The session to re-show, or null when there is nothing to cancel any more.
  static Future<PanicReattachment?> discover(
    EmergencyPlatformService platform, {
    SafetyClock clock = SafetyClock.system,
  }) async {
    if (!platform.isSupported) return null;
    final snapshot = await platform.discoverEmergencySession(
      EmergencySessionKind.panic,
    );
    final token = snapshot.token;
    final mainDeadline = snapshot.mainDeadline;
    final finalDeadline = snapshot.finalDeadline;
    if (!snapshot.isPresent ||
        snapshot.lifecycleState != EmergencySessionLifecycle.armed ||
        token == null ||
        token.kind != EmergencySessionKind.panic ||
        mainDeadline == null ||
        finalDeadline == null ||
        !finalDeadline.isAfter(clock.now())) {
      return null;
    }
    final target = snapshot.target;
    return PanicReattachment._(
      Armed(
        sessionToken: token,
        mainDeadline: mainDeadline,
        finalDeadline: finalDeadline,
      ),
      target == null || target.isEmpty ? null : target,
    );
  }
}
