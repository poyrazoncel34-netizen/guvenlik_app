import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/bounded_frame_wait.dart';

void _goTo(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('a delivered frame completes the wait and cancels the timer', (
    tester,
  ) async {
    var done = false;
    unawaited(
      BoundedFrameWait.nextFrame(
        tester.binding,
        maxWait: const Duration(seconds: 10),
      ).then((_) => done = true),
    );
    expect(done, isFalse);

    await tester.pump();
    await tester.idle();

    // The 10s timer must already be cancelled: testWidgets fails on a
    // pending timer, so a leaked one would surface here.
    expect(done, isTrue);
  });

  testWidgets('a locked screen delivers no frame, so the bound completes it', (
    tester,
  ) async {
    _goTo(tester, <AppLifecycleState>[
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    addTearDown(
      () => _goTo(tester, <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]),
    );
    expect(tester.binding.framesEnabled, isFalse);

    var done = false;
    unawaited(
      BoundedFrameWait.nextFrame(tester.binding).then((_) => done = true),
    );

    await tester.binding.delayed(
      BoundedFrameWait.maxWait - const Duration(milliseconds: 1),
    );
    expect(done, isFalse, reason: 'still inside the bound');

    await tester.binding.delayed(const Duration(milliseconds: 2));
    expect(done, isTrue, reason: 'no frame came; the bound must release it');
  });
}
