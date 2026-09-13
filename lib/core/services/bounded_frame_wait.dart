import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Waits for the pending frame before the panic countdown arms -- but never
/// longer than [maxWait].
///
/// The countdown first slept a fixed 300ms before arming, which shifted every
/// dial 300ms later because the deadline is set at arm time. It then awaited
/// `endOfFrame` instead: fast while the app is visible, but UNBOUNDED
/// otherwise. [SchedulerBinding.scheduleFrame] is a no-op while the app is
/// `hidden` or `paused`, so a user who pressed panic and locked the phone
/// before the PIN/contact read finished got no native session at all until
/// the screen came back on (a widget probe saw no arm after 60 seconds).
///
/// With the bound, the visible case is unchanged -- the frame wins -- and the
/// locked case arms after at most [maxWait]. Arming early is never harmful:
/// nothing in the arm path needs the frame to have been rendered.
abstract final class BoundedFrameWait {
  /// The worst case the pre-`endOfFrame` code already paid on every dial.
  static const Duration maxWait = Duration(milliseconds: 300);

  static Future<void> nextFrame(
    SchedulerBinding binding, {
    Duration maxWait = BoundedFrameWait.maxWait,
  }) {
    final done = Completer<void>();
    final timer = Timer(maxWait, () {
      if (!done.isCompleted) done.complete();
    });
    unawaited(
      binding.endOfFrame.then((_) {
        timer.cancel();
        if (!done.isCompleted) done.complete();
      }),
    );
    return done.future;
  }
}
