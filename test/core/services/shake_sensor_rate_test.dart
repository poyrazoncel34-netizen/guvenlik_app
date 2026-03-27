// ShakeDetectorService should use SENSOR_DELAY_NORMAL for background
// monitoring, not SENSOR_DELAY_GAME which causes excessive battery drain.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShakeDetectorService sensor rate', () {
    test('must use SENSOR_DELAY_NORMAL not SENSOR_DELAY_GAME for background monitoring', () {
      final content = File(
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/ShakeDetectorService.kt',
      ).readAsStringSync();

      expect(
        content,
        isNot(contains('SENSOR_DELAY_GAME')),
        reason:
            'SENSOR_DELAY_GAME is the highest frequency sensor rate, intended '
            'for games. Background shake detection should use SENSOR_DELAY_NORMAL '
            'to avoid excessive battery drain and Play Store policy violation.',
      );

      expect(
        content,
        contains('SENSOR_DELAY_NORMAL'),
        reason: 'ShakeDetectorService must use SENSOR_DELAY_NORMAL for battery efficiency',
      );
    });
  });
}
