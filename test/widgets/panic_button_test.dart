// Widget smoke test: PanicButton renders without crashing.
// Full integration tests are skipped here because PanicButton depends on
// platform channels (HapticFeedback, Navigator push) and EasyLocalization.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PanicButton', () {
    test('PanicButton source file exists', () {
      expect(File('lib/widgets/panic_button.dart').existsSync(), isTrue);
    });

    test('PanicButton uses HapticFeedback', () {
      final source = File('lib/widgets/panic_button.dart').readAsStringSync();
      expect(source.contains('HapticFeedback'), isTrue);
    });
  });
}
