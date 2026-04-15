import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Blocker 1: cancelCountdownAlarm exception must never block _executeEmergency.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/countdown_screen.dart').readAsStringSync();
  });

  test(
    'cancelCountdownAlarm is wrapped in try-catch so dispatch is never blocked',
    () {
      final makeCallIdx = source.indexOf('Future<void> _makeEmergencyCall()');
      final executeIdx = source.indexOf('await _executeEmergency()', makeCallIdx);

      final body = source.substring(makeCallIdx, executeIdx);

      final cancelIdx = body.indexOf('cancelCountdownAlarm');
      final tryBeforeCancel = body.lastIndexOf('try {', cancelIdx);
      expect(
        tryBeforeCancel,
        isNot(-1),
        reason:
            'cancelCountdownAlarm must be inside a try block so exceptions do not kill dispatch',
      );

      final catchAfterCancel = body.indexOf('} on Exception catch', cancelIdx);
      expect(
        catchAfterCancel,
        isNot(-1),
        reason:
            'Exception from cancelCountdownAlarm must be caught; dispatch must continue',
      );
    },
  );
}
