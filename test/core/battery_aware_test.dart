import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ResourceMonitorService exposes a lowBatteryStream', () {
    final source = File(
      'lib/core/services/resource_monitor_service.dart',
    ).readAsStringSync();
    expect(
      source.contains('lowBatteryStream'),
      isTrue,
      reason:
          'ResourceMonitorService must expose lowBatteryStream for subscribers',
    );
  });
}
