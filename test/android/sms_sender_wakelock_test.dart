import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// System 3C: SmsSender must acquire PARTIAL_WAKE_LOCK during SMS dispatch.
void main() {
  test('SmsSender should use PARTIAL_WAKE_LOCK for SMS dispatch', () {
    final source = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency/SmsSender.kt',
    ).readAsStringSync();

    expect(source.contains('PARTIAL_WAKE_LOCK'), isTrue,
        reason: 'Must acquire PARTIAL_WAKE_LOCK to keep CPU awake during SMS');
    expect(source.contains('KoruBeni:SmsSend'), isTrue,
        reason: 'Wake lock must have KoruBeni:SmsSend tag');
    expect(source.contains('AtomicInteger'), isTrue,
        reason: 'Must track active threads with AtomicInteger');
  });
}
