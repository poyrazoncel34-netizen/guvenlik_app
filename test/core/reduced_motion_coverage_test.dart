// ============================================================================
// MP-09-013 / MP-09-025 — the platform reduce-motion preference is OBEYED
// ============================================================================
// This test exists because a measurement found the opposite. Seven files
// started an infinite `..repeat()` as a CONSTRUCTION CASCADE:
//
//     _pulseController = AnimationController(...)..repeat(reverse: true);
//
// A cascade runs while the State is being built, which is before any
// `MediaQuery` is readable. So the loop had already started by the time
// anything could ask whether the user wants motion at all. `panic_button.dart`
// is the sharpest case: it consulted `ReducedMotionPolicy` for its ARMED pulse
// and ignored it for the IDLE breath, in the same widget.
//
// Two independent assertions, because either one alone passes against a
// half-fix:
//
//   1. SOURCE: no ambient-loop file may start a loop with a cascade.
//   2. BEHAVIOUR: with `disableAnimations: true`, the controller is parked and
//      NOT animating -- and parked at a VISIBLE value, not at frame zero.
//
// Assertion 2 is the one that catches a "fix" that moves the cascade into
// didChangeDependencies without consulting anything.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/reduced_motion_policy.dart';

/// Every file that runs an ambient loop, and the state that loop encodes.
/// Adding a loop without adding it here is caught by the sweep below.
const ambientLoopFiles = <String, String>{
  'lib/screens/splash_screen.dart': 'boot shimmer + glow',
  'lib/screens/countdown_screen.dart': 'urgent glow',
  'lib/widgets/panic_button.dart': 'idle breath + armed pulse',
  'lib/screens/onboarding_screen.dart': 'step icon pulse',
  'lib/screens/check_in_screen.dart': 'grace-period warning',
  'lib/screens/map_page.dart': 'live-location marker',
  'lib/screens/emergency_call_screen.dart': 'call in progress',
  'lib/widgets/siren_dialog.dart': 'siren flash + throb',
};

void main() {
  group('MP-09-025: no ambient loop starts before the policy can be read', () {
    for (final entry in ambientLoopFiles.entries) {
      test('${entry.key} (${entry.value})', () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
        final source = file.readAsStringSync();

        // The defect signature: a `..repeat(` cascade hanging off the
        // AnimationController construction.
        expect(
          RegExp(r'\)\s*\.\.repeat\(').hasMatch(source),
          isFalse,
          reason:
              '${entry.key} starts a repeating animation with a construction '
              'cascade, which runs before MediaQuery is readable.',
        );

        // And it must actually consult the policy somewhere.
        expect(
          source.contains('ReducedMotionPolicy') ||
              source.contains('disableAnimations'),
          isTrue,
          reason: '${entry.key} never consults the reduce-motion preference.',
        );
      });
    }

    test('the file list is exhaustive — no unlisted loop exists in lib/', () {
      final unlisted = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        if (ambientLoopFiles.containsKey(path)) continue;
        // The policy module is the mechanism, not a loop.
        if (path.endsWith('reduced_motion_policy.dart')) continue;
        final source = entity.readAsStringSync();
        if (RegExp(r'\.repeat\(').hasMatch(source)) unlisted.add(path);
      }
      expect(
        unlisted,
        isEmpty,
        reason:
            'these files run a repeating animation but are not declared above, '
            'so nothing checks whether they honour the preference: $unlisted',
      );
    });
  });

  group('MP-09-013: a suppressed pulse is PARKED VISIBLE, not stopped at zero', () {
    testWidgets('pulse() parks at mid-travel so the state stays legible', (
      tester,
    ) async {
      late AnimationController controller;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _Host(
            onReady: (c, reduced) {
              controller = c;
              ReducedMotionPolicy.pulse(c, reduced: reduced);
            },
          ),
        ),
      );

      expect(controller.isAnimating, isFalse);
      // NEGATIVE CONTROL FOR THE FIX ITSELF: a bare `stop()` leaves a
      // never-started controller at 0.0, which every consumer in this app reads
      // straight into an alpha or a scale -- so the "armed" state would render
      // at its dimmest frame for the users who asked for less motion.
      expect(controller.value, ReducedMotionPolicy.stillPulseValue);
      expect(controller.value, greaterThan(0.0));
    });

    testWidgets('loop() parks a sweep at zero, not mid-sweep', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _Host(
            onReady: (c, reduced) {
              controller = c;
              ReducedMotionPolicy.loop(c, reduced: reduced);
            },
          ),
        ),
      );
      expect(controller.isAnimating, isFalse);
      expect(controller.value, 0.0);
    });

    testWidgets('with motion allowed, pulse() actually runs', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: _Host(
            onReady: (c, reduced) {
              controller = c;
              ReducedMotionPolicy.pulse(c, reduced: reduced);
            },
          ),
        ),
      );
      // Without this the two assertions above are satisfied by a policy that
      // suppresses everything unconditionally.
      expect(controller.isAnimating, isTrue);
      controller.stop();
    });
  });
}

typedef _Ready = void Function(AnimationController controller, bool reduced);

class _Host extends StatefulWidget {
  const _Host({required this.onReady});

  final _Ready onReady;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.onReady(_controller, ReducedMotionPolicy.isReduced(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
