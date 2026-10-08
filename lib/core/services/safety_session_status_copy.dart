import 'package:easy_localization/easy_localization.dart';

/// Title and body of the ongoing status notification of a Check-In or Safe
/// Walk session.
///
/// Extracted from `check_in_service.dart`, which sits at the 800-line limit
/// and needed room for the monotonic deadline fix (chaos audit Y-01).
abstract final class SafetySessionStatusCopy {
  static ({String title, String body}) of({
    required bool isSafeWalk,
    required bool isGracePeriod,
    required int remainingSeconds,
  }) {
    final time = mmss(remainingSeconds);
    if (isSafeWalk) {
      return (
        title: 'foreground_active_title'.tr(),
        body: 'foreground_safe_walk_status'.tr(namedArgs: {'time': time}),
      );
    }
    return (
      title: isGracePeriod
          ? 'check_in_grace_label'.tr()
          : 'check_in_title'.tr(),
      body: '${'check_in_remaining'.tr()}: $time',
    );
  }

  /// `mm:ss`, minutes not wrapped at an hour.
  static String mmss(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
