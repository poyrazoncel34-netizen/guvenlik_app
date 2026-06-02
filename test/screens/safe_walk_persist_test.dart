import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SPEC §6: safe-walk delegates persistence + lifecycle to the shared
/// CheckInService.safeWalk controller. The screen must still guard mounted
/// after the async stop()/start() calls before touching UI.
void main() {
  test('safe_walk_screen cancel path stops the controller and guards mounted', () {
    final source = File('lib/screens/safe_walk_screen.dart').readAsStringSync();

    final cancelStart = source.indexOf('Future<void> _cancelWalk()');
    expect(cancelStart, isNot(-1));
    final cancelEnd = source.indexOf('String _formatTime', cancelStart);
    final cancelBody = source.substring(cancelStart, cancelEnd);

    expect(cancelBody, contains('await _controller.stop();'));
    expect(cancelBody, contains('if (!mounted) return;'));
  });

  test('safe_walk start guards mounted after the async controller start', () {
    final source = File('lib/screens/safe_walk_screen.dart').readAsStringSync();

    final startIdx = source.indexOf('final fullyScheduled = await _controller.start(');
    expect(startIdx, isNot(-1));
    final mountedIdx = source.indexOf('if (!mounted) return;', startIdx);
    final degradedIdx = source.indexOf('_showTimerSchedulingDegraded()', startIdx);

    expect(mountedIdx, isNot(-1));
    expect(degradedIdx, isNot(-1));
    expect(
      mountedIdx < degradedIdx,
      isTrue,
      reason: 'mounted must be checked before touching UI after start().',
    );
  });

  test('safe_walk exit path awaits cancel and guards mounted', () {
    final source = File('lib/screens/safe_walk_screen.dart').readAsStringSync();

    final exitStart = source.indexOf('void _showExitWarning()');
    final exitBody = source.substring(exitStart);
    expect(exitBody, contains('onPressed: () async'));
    expect(exitBody, contains('await _cancelWalk();'));
    expect(exitBody, contains('if (!mounted) return;'));
  });
}
