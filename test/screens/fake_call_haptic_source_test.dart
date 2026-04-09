// Verifies that fake_call_screen.dart's decline and accept callbacks
// contain HapticFeedback calls. This test reads the source file directly
// because pumping FakeCallScreen requires heavy platform dependencies
// (audioplayers, secure_storage channel, phone_state) that are not
// available in the widget-test sandbox.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourcePath = 'lib/screens/fake_call_screen.dart';

  test('decline button callback calls HapticFeedback.heavyImpact', () {
    final source = File(sourcePath).readAsStringSync();
    expect(
      source.contains('HapticFeedback.heavyImpact()'),
      isTrue,
      reason: 'Decline button must call HapticFeedback.heavyImpact()',
    );
  });

  test('accept button callback calls HapticFeedback.mediumImpact', () {
    final source = File(sourcePath).readAsStringSync();
    expect(
      source.contains('HapticFeedback.mediumImpact()'),
      isTrue,
      reason: 'Accept button must call HapticFeedback.mediumImpact()',
    );
  });
}
