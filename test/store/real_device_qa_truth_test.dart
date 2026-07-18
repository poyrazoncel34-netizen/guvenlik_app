import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real-device matrix distinguishes process death from force-stop', () {
    final matrix = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();

    expect(matrix, contains('adb shell am kill'));
    expect(matrix, contains('Android 15'));
    expect(matrix, contains('cancels all pending intents'));
    expect(
      matrix,
      contains(
        'https://developer.android.com/about/versions/15/behavior-changes-all',
      ),
    );
    expect(
      matrix,
      isNot(contains('FORCE-STOP the app; let main+grace expire')),
    );
    expect(matrix, isNot(contains('Dedup race under force-stop')));
  });

  test('real-device evidence language matches the retired FGS design', () {
    final matrix = File('store/REAL_DEVICE_QA_MATRIX.md').readAsStringSync();
    final submission = File('docs/play-submission.md').readAsStringSync();

    expect(matrix, isNot(contains('FGS notification content')));
    expect(matrix, isNot(contains('Foreground-service notification')));
    expect(matrix, isNot(contains('Alarm/FGS survives')));
    expect(matrix, isNot(contains('FGS demo video capture')));
    expect(matrix, isNot(contains('with DnD bypass')));
    expect(submission, isNot(contains('Console FGS beyan formuna eklenir')));
  });
}
