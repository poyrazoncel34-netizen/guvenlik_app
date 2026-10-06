// Cross-surface duplicate countdown.
//
// R2-02 closed the duplicate window for the quick-access entries among
// THEMSELVES. The in-app PanicButton opens its CountdownScreen on the same root
// Navigator through its own path, and the host knew nothing about it: with a
// panic-button countdown on screen, a volume pattern, a Quick Settings tile tap
// or a widget tap pushed a SECOND countdown. Its native arm is rejected with
// `activeSessionExists`, which surfaces as the blocking "safety session not
// ready" dialog ON TOP of the genuinely armed countdown, hiding its PIN-cancel
// pad. Both entry points now share PanicCountdownGuard.
//
// The panic-button side is driven through PanicCountdownGuard.open, which is
// the exact call PanicButton._openCountdownScreen makes (pinned at the bottom).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/navigation/app_navigator.dart';
import 'package:guvenlik_app/core/services/panic_countdown_guard.dart';
import 'package:guvenlik_app/core/services/subscription_access_state.dart';

import 'emergency_trigger_duplicate_guard_test.dart' as harness;

/// Resolution that fails with an ordinary exception, not a timeout.
class _ThrowingProvider extends harness.ParkedSubscriptionProvider {
  _ThrowingProvider() : super(harness.entitledButUnverifiable());

  @override
  Future<SubscriptionAccessState> resolveAccess() async {
    resolveCalls++;
    throw const SocketException('store unreachable');
  }
}

Future<void> _openPanicButtonCountdown(Object owner) async {
  final opened = PanicCountdownGuard.open(
    owner,
    () => rootNavigatorKey.currentState!.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            const Scaffold(body: Center(child: Text('PANIC_BUTTON_COUNTDOWN'))),
        transitionDuration: Duration.zero,
      ),
    ),
  );
  expect(opened, isNotNull, reason: 'precondition: guard was free');
  unawaited(opened);
}

void main() {
  harness.installHostTestHooks();

  testWidgets(
    'a quick-access trigger does not stack a second countdown over an open '
    'panic-button countdown, and works again once it closes',
    (tester) async {
      final provider = harness.ParkedSubscriptionProvider(
        harness.entitledButUnverifiable(),
      );
      provider.gate.complete();
      final observer = harness.PushCounter();
      final state = await harness.pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );

      final panicButton = Object();
      await _openPanicButtonCountdown(panicButton);
      await harness.settle(tester);
      expect(find.text('PANIC_BUTTON_COUNTDOWN'), findsOneWidget);
      observer.pushed.clear();

      unawaited(state.triggerPanicForTest());
      await harness.settle(tester);
      expect(
        observer.pushed,
        isEmpty,
        reason:
            'a second countdown was pushed over the open panic-button '
            'countdown; its arm is rejected natively (activeSessionExists) and '
            'the blocking failure dialog covers the real PIN-cancel pad',
      );
      expect(provider.resolveCalls, 1, reason: 'the trigger was evaluated');

      rootNavigatorKey.currentState!.pop();
      await harness.settle(tester);
      expect(PanicCountdownGuard.isHeld, isFalse);

      unawaited(state.triggerPanicForTest());
      await harness.settle(tester);
      expect(observer.pushed, hasLength(1));
      expect(find.text('STUB_COUNTDOWN'), findsOneWidget);
      rootNavigatorKey.currentState!.pop();
      await harness.settle(tester);
      expect(PanicCountdownGuard.isHeld, isFalse);
      await harness.drainHostTimers(tester);
    },
  );

  testWidgets(
    'a panic-button press during quick-access resolution is not dropped, and '
    'the host then stacks nothing on it',
    (tester) async {
      final provider = harness.ParkedSubscriptionProvider(
        harness.entitledButUnverifiable(),
      );
      final observer = harness.PushCounter();
      final state = await harness.pumpHost(
        tester,
        provider: provider,
        observer: observer,
      );

      unawaited(state.triggerPanicForTest()); // parked in entitlement resolve
      await tester.pump();
      expect(
        PanicCountdownGuard.isHeld,
        isFalse,
        reason: 'the shared guard must never be held across an await',
      );

      await _openPanicButtonCountdown(Object());
      await harness.settle(tester);
      expect(find.text('PANIC_BUTTON_COUNTDOWN'), findsOneWidget);
      observer.pushed.clear();

      provider.gate.complete();
      await harness.settle(tester);
      expect(observer.pushed, isEmpty);
      expect(find.text('STUB_COUNTDOWN'), findsNothing);

      rootNavigatorKey.currentState!.pop();
      await harness.settle(tester);
      expect(PanicCountdownGuard.isHeld, isFalse);
      await harness.drainHostTimers(tester);
    },
  );

  testWidgets('the panic button cannot open over the host countdown', (
    tester,
  ) async {
    final provider = harness.ParkedSubscriptionProvider(
      harness.entitledButUnverifiable(),
    );
    provider.gate.complete();
    final state = await harness.pumpHost(
      tester,
      provider: provider,
      observer: harness.PushCounter(),
    );
    unawaited(state.triggerPanicForTest());
    await harness.settle(tester);
    expect(find.text('STUB_COUNTDOWN'), findsOneWidget);

    var pushed = false;
    expect(
      PanicCountdownGuard.open(Object(), () async {
        pushed = true;
      }),
      isNull,
    );
    expect(pushed, isFalse);

    rootNavigatorKey.currentState!.pop();
    await harness.settle(tester);
    expect(PanicCountdownGuard.isHeld, isFalse);
    await harness.drainHostTimers(tester);
  });

  testWidgets('a rejected quick-access trigger releases the shared guard', (
    tester,
  ) async {
    final provider = harness.ParkedSubscriptionProvider(
      const SubscriptionAccessState.uninitialized(),
    );
    provider.gate.complete();
    final state = await harness.pumpHost(
      tester,
      provider: provider,
      observer: harness.PushCounter(),
    );
    await state.triggerPanicForTest();
    await harness.settle(tester);
    expect(PanicCountdownGuard.isHeld, isFalse);
    await harness.drainHostTimers(tester);
  });

  testWidgets('a quick-access trigger that throws releases the shared guard', (
    tester,
  ) async {
    final provider = _ThrowingProvider();
    final state = await harness.pumpHost(
      tester,
      provider: provider,
      observer: harness.PushCounter(),
    );
    await expectLater(
      state.triggerPanicForTest(),
      throwsA(isA<SocketException>()),
    );
    expect(provider.resolveCalls, 1);
    expect(PanicCountdownGuard.isHeld, isFalse);
    await harness.drainHostTimers(tester);
  });

  testWidgets('tearing the host down with its countdown still open releases '
      'the shared guard', (tester) async {
    final provider = harness.ParkedSubscriptionProvider(
      harness.entitledButUnverifiable(),
    );
    provider.gate.complete();
    final state = await harness.pumpHost(
      tester,
      provider: provider,
      observer: harness.PushCounter(),
    );
    unawaited(state.triggerPanicForTest());
    await harness.settle(tester);
    expect(find.text('STUB_COUNTDOWN'), findsOneWidget);
    expect(PanicCountdownGuard.isHeld, isTrue);
    await harness.drainHostTimers(tester);

    // The Navigator goes down with the route on it, so the push future never
    // completes; only the host's dispose can free the guard.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(PanicCountdownGuard.isHeld, isFalse);
  });

  testWidgets('disposing the host mid-resolve never takes the shared guard', (
    tester,
  ) async {
    final provider = harness.ParkedSubscriptionProvider(
      harness.entitledButUnverifiable(),
    );
    final observer = harness.PushCounter();
    final state = await harness.pumpHost(
      tester,
      provider: provider,
      observer: observer,
    );
    final trigger = state.triggerPanicForTest();
    await tester.pump();
    expect(PanicCountdownGuard.isHeld, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());

    // The orphaned trigger finishes without pushing and without re-taking
    // the guard for a host that no longer exists.
    var finished = false;
    unawaited(trigger.whenComplete(() => finished = true));
    provider.gate.complete();
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(finished, isTrue);
    expect(observer.pushed, isEmpty);
    expect(PanicCountdownGuard.isHeld, isFalse);
  });

  test('PanicButton opens its countdown only through the shared guard', () {
    final source = File('lib/widgets/panic_button.dart').readAsStringSync();
    final body = source.substring(
      source.indexOf('Future<void> _openCountdownScreen() async {'),
    );
    final open = body.indexOf('PanicCountdownGuard.open(');
    expect(open, isNot(-1));
    expect(
      body.indexOf('CountdownScreen(entitlementDecision'),
      greaterThan(open),
    );
    expect(body, contains('if (opened == null) return;'));
    expect(
      RegExp(r'Navigator\.push\(').allMatches(body).length,
      1,
      reason: 'a second, unguarded push path would reintroduce the defect',
    );
    expect(
      source,
      contains('unawaited(_openCountdownScreen());'),
      reason: 'hold release and the screen-reader path share the guarded open',
    );
  });
}
