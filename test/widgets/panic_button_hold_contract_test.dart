import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PanicButton measures the hold from pointer-down with a monotonic clock',
    () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();

      expect(source, contains('Stopwatch'));
      expect(source, contains('PanicHoldGate.isComplete'));
      expect(source, contains('onTapDown: accessibleNavigation ? null'));
      expect(source, contains('onTapUp: accessibleNavigation ? null'));
      expect(source, contains('onTapCancel: accessibleNavigation ? null'));
      expect(
        source,
        isNot(contains('onLongPressEnd: accessibleNavigation ? null')),
        reason:
            'LongPressStart already consumes the platform long-press deadline; '
            'using its end callback made a ~500 ms hold look like three seconds.',
      );
    },
  );
}
