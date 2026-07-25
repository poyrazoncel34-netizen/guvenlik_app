import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screenshots and screen recording are how a PIN typed under observation
/// leaves the device. The window flag is the only mechanism that stops it,
/// and it has to stay on the shipped build.
void main() {
  late String mainActivity;

  setUp(() {
    mainActivity = File(
      'android/app/src/main/kotlin/com/poyrazoncel/korubeni/MainActivity.kt',
    ).readAsStringSync();
  });

  test('release windows are marked FLAG_SECURE', () {
    expect(mainActivity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
    expect(mainActivity, contains('override fun onCreate('));

    final onCreateIndex = mainActivity.indexOf('override fun onCreate(');
    final flagIndex = mainActivity.indexOf(
      'WindowManager.LayoutParams.FLAG_SECURE',
    );
    final superIndex = mainActivity.indexOf(
      'super.onCreate(savedInstanceState)',
    );
    expect(onCreateIndex, lessThan(flagIndex));
    expect(
      flagIndex,
      lessThan(superIndex),
      reason:
          'The flag must be set before the window content is attached, '
          'otherwise the first frame can still be captured.',
    );
  });

  test('only debug builds are exempt, so store capture still works', () {
    expect(mainActivity, contains('if (!BuildConfig.DEBUG)'));
    expect(
      mainActivity,
      isNot(contains('clearFlags(WindowManager.LayoutParams.FLAG_SECURE)')),
      reason:
          'Nothing may clear the flag at runtime: a screen that turns it off '
          'is a screen that can be recorded.',
    );
  });

  test('BuildConfig generation stays enabled for that check', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('buildConfig = true'));
  });
}
