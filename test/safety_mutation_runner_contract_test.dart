import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release mutation runner owns all six mandatory regressions', () {
    final source = File(
      'scripts/run_safety_mutations.py',
    ).readAsStringSync();

    for (final mutation in <String>[
      'M01_CANCEL_RESULT_SWALLOWED',
      'M02_STALE_GENERATION_ACCEPTED',
      'M03_PIN_READ_FAILURE_AS_ABSENT',
      'M04_LOG_BEFORE_DISPATCH',
      'M05_NOTIFICATION_RESULT_IGNORED',
      'M06_DISPOSE_NATIVE_CANCEL',
    ]) {
      expect(source, contains(mutation));
    }
    expect(source, contains('BASELINE_FAILED'));
    expect(source, contains('MUTATION_NOT_KILLED'));
    expect(source, contains('SAFETY_MUTATION_PASS'));
    expect(source, contains('shutil.rmtree(workspace'));
  });
}
