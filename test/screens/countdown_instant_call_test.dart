import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/countdown_screen.dart').readAsStringSync();
  });

  group('CountdownScreen deterministic dispatch contract', () {
    test('does not accept instantCallTriggered constructor parameter', () {
      expect(
        source.contains('instantCallTriggered'),
        isFalse,
        reason: 'No native call may be in flight before countdown expiry.',
      );
    });

    test('dispatch is gated by _emergencyDispatched', () {
      final makeCallIdx = source.indexOf('_makeEmergencyCall');
      final gateIdx = source.indexOf('_emergencyDispatched', makeCallIdx);
      final executeIdx = source.indexOf('_executeEmergency()', makeCallIdx);
      expect(
        gateIdx != -1 && gateIdx < executeIdx,
        isTrue,
        reason:
            'Countdown must prevent duplicate dispatch before executing native flow.',
      );
    });

    test('executeEmergencyNative is called from countdown path', () {
      final executeIdx = source.indexOf('_executeEmergency');
      final nativeIdx = source.indexOf('executeEmergencyNative', executeIdx);
      expect(
        nativeIdx > executeIdx,
        isTrue,
        reason:
            'Native emergency call must live under countdown execution, not PanicButton.',
      );
    });
  });
}
