import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 4A: Native EmergencyExecutor must exist for chaos resilience.
/// If Flutter dies mid-emergency, the native side continues independently.
void main() {
  test('EmergencyExecutor.kt should exist with executeEmergency method', () {
    final file = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyExecutor.kt',
    );
    expect(file.existsSync(), isTrue,
        reason: 'EmergencyExecutor.kt must exist for native-side dispatch');

    final source = file.readAsStringSync();
    expect(source.contains('executeEmergency'), isTrue,
        reason: 'Must have executeEmergency method');
    expect(source.contains('PARTIAL_WAKE_LOCK'), isTrue,
        reason: 'Must acquire wake lock for background execution');
    expect(source.contains('SmsSender'), isTrue,
        reason: 'Must dispatch SMS via SmsSender');
  });
}
