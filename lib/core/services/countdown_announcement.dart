// ============================================================================
// COUNTDOWN ANNOUNCEMENT (screen-reader schedule)
// ============================================================================
// Extracted from countdown_screen.dart, which sits on its size ratchet: the
// bucketing is pure logic and belongs next to the other countdown services.
// ============================================================================

import 'package:easy_localization/easy_localization.dart';

abstract final class CountdownAnnouncement {
  /// Localized live-region label, or an empty string when the countdown should
  /// stay silent.
  static String labelFor(int seconds) {
    final bucket = bucketFor(seconds);
    if (bucket == null) return '';
    return 'countdown_seconds_remaining'.tr(namedArgs: {'seconds': '$bucket'});
  }

  /// Sparse-announcement bucket — every value in [seconds] maps to a stable
  /// bucket label so the Semantics.label only changes (and therefore TalkBack
  /// only announces) when the bucket does:
  ///   10 -> 10 | 9, 8 -> 8 | 7, 6, 5 -> 5 | 4 -> 4 | 3 -> 3 | 2 -> 2 |
  ///   1 -> 1 | 0 and below -> null (silent).
  ///
  /// Eight announcements across a ten-second countdown. The doc comment this
  /// replaced claimed 9 -> 10 and 7, 6 -> 8, which the thresholds never did;
  /// the thresholds are the pinned behaviour, so the comment was the error.
  static int? bucketFor(int seconds) {
    if (seconds >= 10) return 10;
    if (seconds >= 8) return 8;
    if (seconds >= 5) return 5;
    if (seconds >= 1) return seconds;
    return null;
  }
}
