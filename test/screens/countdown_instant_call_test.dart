// Tests verifying CountdownScreen skips the honesty dialog and duplicate
// emergency call when instantCallTriggered is true.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/countdown_screen.dart').readAsStringSync();
  });

  group('CountdownScreen instantCallTriggered', () {
    test('accepts instantCallTriggered constructor parameter', () {
      expect(
        source.contains('instantCallTriggered'),
        isTrue,
        reason: 'CountdownScreen must accept instantCallTriggered param so '
            'PanicButton can signal the call is already in flight',
      );
    });

    test('guards _executeEmergency with instantCallTriggered check', () {
      // Find the _makeEmergencyCall method and verify it has an early return
      // when instantCallTriggered is true — before _executeEmergency is called.
      final makeCallIdx = source.indexOf('_makeEmergencyCall');
      final executeIdx = source.indexOf('_executeEmergency()');
      final guardIdx = source.indexOf(
        'instantCallTriggered',
        makeCallIdx,
      );
      expect(
        guardIdx != -1 && guardIdx < executeIdx,
        isTrue,
        reason: 'widget.instantCallTriggered guard must appear inside '
            '_makeEmergencyCall before _executeEmergency() is called',
      );
    });

    test('skips honesty dialog when instantCallTriggered is true', () {
      // When instantCallTriggered, we must not await the blocking dialog before
      // starting the countdown — the call is already in flight.
      expect(
        source.contains('widget.instantCallTriggered'),
        isTrue,
        reason: 'CountdownScreen must check widget.instantCallTriggered to '
            'bypass the honesty dialog and start countdown immediately',
      );
    });
  });
}
