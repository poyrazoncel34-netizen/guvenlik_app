import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Countdown PIN and dispatch first-wins contract', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/countdown_screen.dart').readAsStringSync();
    });

    test(
      'dispatch does not start while cancellation/navigation is in progress',
      () {
        final makeCallIdx = source.indexOf('Future<void> _makeEmergencyCall()');
        final body = source.substring(
          makeCallIdx,
          source.indexOf('// WakeLock'),
        );

        expect(
          body,
          contains('if (_emergencyDispatched || _isNavigating) return;'),
          reason: 'PIN cancellation can win if it began before dispatch.',
        );
        expect(
          body.indexOf('if (_emergencyDispatched || _isNavigating) return;') <
              body.indexOf('_emergencyDispatched = true;'),
          isTrue,
          reason: 'Dispatch must set its terminal flag only after the guard.',
        );
      },
    );

    test('PIN cancellation cannot cancel an already dispatched emergency', () {
      final cancelIdx = source.indexOf('Future<void> _cancelCountdownAndExit');
      final handlePinIdx = source.indexOf('void _handlePinInput');
      final cancelBody = source.substring(cancelIdx, handlePinIdx);

      expect(
        cancelBody,
        contains('if (_isNavigating || _emergencyDispatched) return;'),
        reason: 'After dispatch starts, cancel path must be ignored.',
      );
    });

    test('PIN input is ignored after emergency dispatch starts', () {
      final handlePinIdx = source.indexOf('void _handlePinInput');
      final buildIdx = source.indexOf('@override', handlePinIdx);
      final pinBody = source.substring(handlePinIdx, buildIdx);

      expect(
        pinBody,
        contains('_emergencyDispatched'),
        reason: 'Late PIN input must not race with emergency dispatch.',
      );
      expect(pinBody, contains('_verificationInProgress'));
    });
  });
}
