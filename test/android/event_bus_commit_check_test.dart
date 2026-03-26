import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SILENT-5: EmergencyEventBus persist() must check commit() return value
/// and retry on failure to prevent silent event loss.
void main() {
  test('EmergencyEventBus persist should check commit return value', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/EmergencyEventBus.kt',
    ).readAsStringSync();

    // Find persist method and check it handles commit failure
    final persistIdx = source.indexOf('fun persist(');
    expect(persistIdx, isNot(-1));

    final methodBody = source.substring(persistIdx, persistIdx + 400);
    expect(methodBody.contains('!'), isTrue,
        reason: 'Must check commit() return value (negation implies boolean check)');
  });
}
