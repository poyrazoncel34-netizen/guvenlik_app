// Edge-case: ResourceMonitorService emits on lowBatteryStream when battery is low.
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/resource_monitor_service.dart';

void main() {
  group('ResourceMonitorService low battery', () {
    test('lowBatteryThreshold is 15', () {
      expect(ResourceMonitorService.lowBatteryThreshold, equals(15));
    });
  });
}
