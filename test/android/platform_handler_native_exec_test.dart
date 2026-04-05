import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 4B: EmergencyPlatformHandler must register executeEmergencyNative.
void main() {
  test('EmergencyPlatformHandler should handle executeEmergencyNative', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyPlatformHandler.kt',
    ).readAsStringSync();

    expect(
      source.contains('executeEmergencyNative'),
      isTrue,
      reason: 'EmergencyPlatformHandler must route executeEmergencyNative to EmergencyExecutor',
    );

    expect(
      source.contains('EmergencyExecutor'),
      isTrue,
      reason: 'Must delegate to EmergencyExecutor',
    );
  });
}
