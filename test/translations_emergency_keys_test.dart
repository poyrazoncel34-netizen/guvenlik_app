import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'en-US.json contains emergency_failed_title without conflict markers',
    () {
      final source = File('assets/translations/en-US.json').readAsStringSync();
      expect(
        source.contains('<<<<<<<'),
        isFalse,
        reason: 'en-US.json must not contain git conflict markers',
      );
      expect(
        source.contains('"emergency_failed_title"'),
        isTrue,
        reason:
            'en-US.json must include emergency_failed_title key from PR #20',
      );
    },
  );

  test('en-US.json does not contain Turkish reboot copy', () {
    final source = File('assets/translations/en-US.json').readAsStringSync();
    expect(source.contains('yeniden başlatılır'), isFalse);
  });
}
