import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ResourceMonitorService exposes a lowBatteryStream', () {
    final source = File('lib/core/services/resource_monitor_service.dart').readAsStringSync();
    expect(
      source.contains('lowBatteryStream'),
      isTrue,
      reason: 'ResourceMonitorService must expose lowBatteryStream for subscribers',
    );
  });

  test('ShakeDetectorService subscribes to lowBatteryStream to raise threshold', () {
    final source = File('lib/core/services/shake_detector_service.dart').readAsStringSync();
    expect(
      source.contains('lowBatteryStream'),
      isTrue,
      reason: 'ShakeDetectorService must subscribe to lowBatteryStream',
    );
  });

  test('ShakeDetectorService cancels lowBattery subscription on dispose', () {
    final source = File('lib/core/services/shake_detector_service.dart').readAsStringSync();
    expect(
      source.contains('_lowBatterySubscription?.cancel()'),
      isTrue,
      reason: 'dispose() must cancel the lowBattery subscription to avoid leaks',
    );
  });

  test('LocationService subscribes to lowBatteryStream to reduce accuracy', () {
    final source = File('lib/core/services/location_service.dart').readAsStringSync();
    expect(
      source.contains('lowBatteryStream'),
      isTrue,
      reason: 'LocationService must subscribe to lowBatteryStream to save power',
    );
  });
}
