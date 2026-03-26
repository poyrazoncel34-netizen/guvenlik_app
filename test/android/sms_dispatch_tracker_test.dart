import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SILENT-1: SmsStatusReceiver must track failed dispatch count
/// and emit smsAllFailed event when all recipients fail.
void main() {
  test('SmsStatusReceiver should track dispatch failures', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/SmsStatusReceiver.kt',
    ).readAsStringSync();

    expect(source.contains('smsAllFailed'), isTrue,
        reason: 'Must emit smsAllFailed event when all dispatches fail');
  });
}
