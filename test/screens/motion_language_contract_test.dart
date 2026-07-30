// Source contract for the shared motion language.
//
// Twenty scattered duration values are what made the app feel unpolished; a
// scale only helps if new code keeps using it. These tests are the ratchet.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<File> dartFiles;

  setUpAll(() {
    dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  });

  /// Drops comment lines so a rule is not tripped by the comment explaining it.
  String codeOnly(String source) => source
      .split('\n')
      .where((line) {
        final t = line.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  group('no overshoot curves anywhere in lib/', () {
    test('easeOutBack, elasticOut and friends are gone', () {
      const forbidden = [
        'Curves.easeOutBack',
        'Curves.easeInBack',
        'Curves.easeInOutBack',
        'Curves.elasticOut',
        'Curves.elasticIn',
        'Curves.bounceOut',
        'Curves.bounceIn',
      ];
      final violations = <String>[];
      for (final file in dartFiles) {
        final source = codeOnly(file.readAsStringSync());
        for (final curve in forbidden) {
          if (source.contains(curve)) violations.add('${file.path}: $curve');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Overshoot and bounce read as playful. Use Motion.enter/exit; if a '
            'case genuinely needs overshoot, add it to Motion with a reason.',
      );
    });
  });

  group('route transitions come from the scale', () {
    test('no raw millisecond literal is used as a transitionDuration', () {
      final violations = <String>[];
      for (final file in dartFiles) {
        for (final line in codeOnly(file.readAsStringSync()).split('\n')) {
          if (!line.contains('transitionDuration:') &&
              !line.contains('reverseTransitionDuration:')) {
            continue;
          }
          if (line.contains('Motion.') || line.contains('Duration.zero')) {
            continue;
          }
          violations.add('${file.path}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Page transitions must use Motion.slow or Duration.zero.',
      );
    });
  });

  group('the dispatch path stays outside the scale', () {
    test('the two countdown entry points animate for zero milliseconds', () {
      // Belt and braces with dispatch_path_latency_contract_test: that file
      // guards the panic path specifically, this one guards it from a
      // well-meaning sweep that "harmonises" every route to Motion.slow.
      for (final path in <String>[
        'lib/widgets/panic_button.dart',
        'lib/core/widgets/emergency_trigger_host.dart',
      ]) {
        final source = codeOnly(File(path).readAsStringSync());
        expect(
          source,
          contains('transitionDuration: Duration.zero'),
          reason: '$path must not adopt a scale rung.',
        );
        expect(
          source.contains('transitionDuration: Motion.'),
          isFalse,
          reason: '$path is the dispatch path; it gets no transition at all.',
        );
      }
    });

    test('Motion documents why dispatch is separate', () {
      final motion = File('lib/core/motion.dart').readAsStringSync();
      expect(motion, contains('static const Duration dispatch = Duration.zero'));
      expect(
        motion.contains('not a tuning knob'),
        isTrue,
        reason: 'The next reader must not treat dispatch as a rung to adjust.',
      );
    });
  });

  group('the tuned panic pulses were not swept into the scale', () {
    test('the countdown glow and the armed pulse keep their own periods', () {
      // These were set deliberately (a ~2.8s breath and a 2.4s one). A blanket
      // "align every duration" pass would undo that.
      final countdown = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();
      final panic = File('lib/widgets/panic_button.dart').readAsStringSync();

      expect(countdown, contains('milliseconds: 1400'));
      expect(panic, contains('milliseconds: 1200'));
      expect(panic, contains('milliseconds: 2400'));
    });
  });
}
