import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Emergency consent ordering', () {
    test('countdown_screen starts native call only from countdown execution', () {
      final content = File(
        'lib/screens/countdown_screen.dart',
      ).readAsStringSync();

      expect(
        content.contains('EmergencyOrchestrator.execute'),
        isFalse,
        reason: 'Stale emergency orchestrator path must not remain',
      );
      expect(
        content.contains('sendSms'),
        isFalse,
        reason: 'Countdown emergency flow must not send messages',
      );

      final executeMethodIndex = content.indexOf('_executeEmergency');
      final nativeCallIndex = content.indexOf(
        'executeEmergencyNative',
        executeMethodIndex,
      );
      expect(
        nativeCallIndex,
        greaterThan(executeMethodIndex),
        reason:
            'Native call must be reached only from countdown _executeEmergency.',
      );
    });
  });
}
