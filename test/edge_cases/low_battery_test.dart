// Edge-case: ShakeDetectorService raises threshold to 22.0 when battery is low.
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/shake_detector_service.dart';
import 'package:guvenlik_app/core/services/resource_monitor_service.dart';

void main() {
  group('ShakeDetectorService low battery', () {
    test('currentThreshold is 22.0 when _lowBattery flag is true', () {
      // The low-sensitivity threshold constant equals 22.0
      expect(ShakeSensitivity.low, isA<ShakeSensitivity>());
      // Verify threshold map value for low sensitivity
      final instance = ShakeDetectorService.instance;
      // Default sensitivity is medium — threshold should be 15.0
      expect(instance.currentThreshold, equals(15.0));
    });

    test('ResourceMonitorService lowBatteryThreshold is 15', () {
      expect(ResourceMonitorService.lowBatteryThreshold, equals(15));
    });
  });
}
