import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unlock widget never stores the configured PIN in widget state', () {
    final source = File(
      'lib/screens/app_unlock_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PinVerificationService'));
    expect(source, isNot(contains('_correctPin')));
    expect(source, isNot(contains('read(key: SecureStorageKeys.userPin)')));
  });
}
