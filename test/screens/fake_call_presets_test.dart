import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finding 6 (LOW): fake-call preset templates contained dummy phone
/// numbers like +90 555 000 00 01. This contract test enforces that no
/// such dummy numbers remain — preset templates fill the name only and
/// leave the phone field blank.
void main() {
  test('fake_call_screen presets contain no dummy +90 555 000 00 0X numbers',
      () {
    final source = File(
      'lib/screens/fake_call_screen.dart',
    ).readAsStringSync();
    final dummy = RegExp(r'\+90\s*555\s*000\s*00');
    expect(
      dummy.hasMatch(source),
      isFalse,
      reason:
          'fake_call_screen.dart preset templates must not contain dummy '
          '+90 555 000 00 ... phone numbers. Use empty strings instead.',
    );
  });
}
