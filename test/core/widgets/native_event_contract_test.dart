import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native alarm receivers and the Flutter listener are written in
/// different languages against an untyped map. Nothing in the compiler
/// connects them, so the seam is pinned here: every event name the native
/// side can emit must be handled on the Dart side, and vice versa.
void main() {
  final nativeSources = <String>[
    'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CountdownAlarmReceiver.kt',
    'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/CheckInAlarmReceiver.kt',
  ];

  Set<String> emittedEventTypes() {
    final pattern = RegExp(r'"type"\s+to\s+"([A-Za-z]+)"');
    final emitted = <String>{};
    for (final path in nativeSources) {
      final source = File(path).readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        emitted.add(match.group(1)!);
      }
    }
    return emitted;
  }

  test('native receivers still emit at least one event type', () {
    expect(
      emittedEventTypes(),
      isNotEmpty,
      reason:
          'If the regex stops matching, this test must fail loudly instead '
          'of trivially passing an empty set.',
    );
  });

  test('every natively emitted event type is handled in Dart', () {
    final host = File(
      'lib/core/widgets/emergency_trigger_host.dart',
    ).readAsStringSync();

    for (final type in emittedEventTypes()) {
      expect(
        host,
        contains("'$type'"),
        reason:
            'Native emits "$type" but no Dart branch consumes it. The '
            'payload is then consumed and discarded, so a background '
            'dispatch never reaches the UI, the timeline, or the local '
            'session projection.',
      );
    }
  });

  test('a background dispatch reconciles the long-running sessions', () {
    final host = File(
      'lib/core/widgets/emergency_trigger_host.dart',
    ).readAsStringSync();
    final pendingStart = host.indexOf('Future<void> _consumePendingTrigger');
    expect(pendingStart, greaterThan(-1));
    final pending = host.substring(pendingStart);

    expect(pending, contains("emergencySessionDispatched"));
    expect(pending, contains('CheckInService.instance.handleAppResumed()'));
    expect(pending, contains('CheckInService.safeWalk.handleAppResumed()'));
  });
}
