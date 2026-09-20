/// Masks the emergency contact's name on surfaces reached WITHOUT the app PIN.
///
/// Why this exists
/// ---------------
/// The Quick Settings tile, the home-screen widget and the volume trigger all
/// open the countdown through `EmergencyTriggerHost._openCountdown`, which
/// runs the subscription gate and pushes `CountdownScreen` -- with no PIN gate
/// in between. That is deliberate and must stay: asking a panicking user for a
/// PIN would kill the feature.
///
/// What was NOT deliberate is that the countdown then printed the contact's
/// full name. Someone holding the victim's unlocked phone -- the exact
/// scenario the duress model is built around -- could tap the tile and read
/// who the victim would call, without knowing the PIN that protects the rest
/// of the app (audit A-009).
///
/// Masking costs the flow nothing: the call target is already frozen at arm
/// time, so the name on screen is decoration, not input.
///
/// What it deliberately does NOT do
/// --------------------------------
/// It is not a cryptographic measure and does not pretend to be. Someone who
/// already knows the victim can guess "A***". It removes the disclosure of a
/// name the attacker did not already have; it cannot remove confirmation of
/// one they did.
abstract final class ContactNameMask {
  /// The first character, then a fixed-width marker.
  ///
  /// Fixed width on purpose: `'A' + '*' * name.length` would leak the length
  /// of the real name, which narrows a guess considerably.
  ///
  /// Operates on runes rather than code units so a name starting with an
  /// astral character (an emoji, some scripts) is not cut in half into an
  /// unpaired surrogate.
  static String mask(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return '${String.fromCharCode(trimmed.runes.first)}***';
  }

  /// What a surface may display, given the arming-time identity and whether
  /// that surface was reached without the PIN.
  ///
  /// The decision lives here rather than in the screen so that BOTH places the
  /// countdown shows a name -- the live label and the hand-off to
  /// EmergencyCallScreen -- resolve it identically. Masking only the first
  /// would have been cosmetic: the name reappears ten seconds later on the
  /// call screen.
  static String forSurface(String? name, {required bool masked}) {
    final raw = name ?? '';
    return masked ? mask(raw) : raw;
  }
}
