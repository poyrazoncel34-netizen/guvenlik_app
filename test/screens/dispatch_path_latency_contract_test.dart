// Source contract for panic-moment latency and motion.
//
// Convention in this repo: screen-level guarantees are asserted at the source
// (see countdown_live_region_test.dart). CountdownScreen cannot be pumped
// without platform channels (Wakelock, AlarmManager, haptics) and a configured
// ServiceLocator, and route transition durations are not observable from a
// service test -- so the contract lives here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String countdown;
  late String panicButton;
  late String triggerHost;

  setUpAll(() {
    countdown = File('lib/screens/countdown_screen.dart').readAsStringSync();
    panicButton = File('lib/widgets/panic_button.dart').readAsStringSync();
    triggerHost = File(
      'lib/core/widgets/emergency_trigger_host.dart',
    ).readAsStringSync();
  });

  group('no fixed delay before arming', () {
    test('the countdown waits for the pending frame, not a timer', () {
      expect(
        countdown.contains('await WidgetsBinding.instance.endOfFrame'),
        isTrue,
      );
      expect(
        countdown.contains('Future.delayed'),
        isFalse,
        reason:
            'A fixed pre-arm delay is added to every dial: the deadline is set '
            'at arm time, so the whole session shifts later.',
      );
    });
  });

  group('no transition animation on the dispatch path', () {
    test('the panic button opens the countdown with no transition', () {
      expect(panicButton.contains('transitionDuration: Duration.zero'), isTrue);
      expect(
        panicButton.contains('reverseTransitionDuration: Duration.zero'),
        isTrue,
      );
      expect(
        panicButton.contains('transitionsBuilder'),
        isFalse,
        reason: 'Screen time before the countdown can arm is latency.',
      );
    });

    test('the volume-trigger path matches the panic button', () {
      expect(triggerHost.contains('transitionDuration: Duration.zero'), isTrue);
      expect(
        triggerHost.contains('MaterialPageRoute('),
        isFalse,
        reason:
            'MaterialPageRoute default transition made the volume path slower '
            'than the button path for the same session.',
      );
    });

    test('the acknowledgement haptic is not awaited before pushing', () {
      expect(triggerHost.contains('unawaited('), isTrue);
      expect(
        triggerHost.contains('HapticFeedback.heavyImpact().catchError'),
        isTrue,
        reason:
            'Fire-and-forget on the dispatch path must not leave an unhandled '
            'async error if the vibration channel is missing.',
      );
      expect(
        triggerHost.contains('await HapticFeedback.heavyImpact()'),
        isFalse,
        reason: 'The vibration channel must never gate the arm request.',
      );
    });
  });

  group('armed states breathe instead of blinking', () {
    test('the countdown urgent glow runs a slow cycle', () {
      final glowStart = countdown.indexOf('_glowController = AnimationController');
      expect(glowStart, isNot(-1));
      final window = countdown.substring(glowStart, glowStart + 200);
      expect(
        window.contains('milliseconds: 1400'),
        isTrue,
        reason: '800ms out-and-back reads as a flash, not a pulse.',
      );
    });

    test('the panic hold pulse runs a slow cycle', () {
      final pulseStart = panicButton.indexOf(
        '_armedPulseController = AnimationController',
      );
      expect(pulseStart, isNot(-1));
      final window = panicButton.substring(pulseStart, pulseStart + 200);
      expect(window.contains('milliseconds: 1200'), isTrue);
    });
  });

  group('reduce-motion is respected', () {
    test('the countdown routes its animations through the policy', () {
      expect(countdown.contains('ReducedMotionPolicy.isReduced(context)'), isTrue);
      expect(
        countdown.contains('ReducedMotionPolicy.pulse(_glowController'),
        isTrue,
      );
      expect(countdown.contains('_tickBounceController,\n          reduced:'), isTrue);
      expect(
        countdown.contains('ReducedMotionPolicy.playOnce(_shakeController'),
        isTrue,
      );
      expect(
        countdown.contains('..repeat(reverse: true)'),
        isFalse,
        reason: 'An unconditional repeat ignores the platform preference.',
      );
    });

    test('the panic button routes its pulse through the policy', () {
      expect(
        panicButton.contains('ReducedMotionPolicy.isReduced(context)'),
        isTrue,
      );
      expect(
        panicButton.contains('ReducedMotionPolicy.pulse(_armedPulseController'),
        isTrue,
      );
      expect(
        panicButton.contains('_armedPulseController.repeat('),
        isFalse,
      );
    });

    test('haptics stay unconditional -- the phone may be in a pocket', () {
      // Suppressing motion must not suppress the channel a user feels.
      expect(
        countdown.contains('HapticService.countdownTick(secondsRemaining:'),
        isTrue,
      );
      expect(
        countdown.contains('_reduceMotion) HapticService'),
        isFalse,
        reason: 'Reduce-motion must never gate the haptic channel.',
      );
      expect(
        panicButton.contains('HapticFeedback.mediumImpact();'),
        isTrue,
        reason: 'The 500ms hold heartbeat must keep firing.',
      );
    });
  });

  group('the display still reads from the absolute deadline', () {
    test('countdown seconds come from CountdownClock, not tick counting', () {
      expect(
        countdown.contains('CountdownClock.secondsUntil(deadline)'),
        isTrue,
      );
    });
  });
}
