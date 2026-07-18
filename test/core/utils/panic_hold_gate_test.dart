import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/utils/panic_hold_gate.dart';

void main() {
  group('PanicHoldGate', () {
    test('rejects every duration below the full three-second contract', () {
      expect(
        PanicHoldGate.isComplete(const Duration(milliseconds: 2999)),
        isFalse,
      );
    });

    test('accepts exactly three seconds and longer', () {
      expect(PanicHoldGate.isComplete(const Duration(seconds: 3)), isTrue);
      expect(
        PanicHoldGate.isComplete(const Duration(milliseconds: 3500)),
        isTrue,
      );
    });
  });
}
