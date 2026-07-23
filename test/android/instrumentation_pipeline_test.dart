import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI runs host and connected Android safety tests', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(workflow, contains('app:testPlayDebugUnitTest'));
    expect(workflow, contains('app:assemblePlayDebugAndroidTest'));
    expect(workflow, contains('app:connectedPlayDebugAndroidTest'));
    expect(
      workflow,
      matches(
        RegExp(r'reactivecircus/android-emulator-runner@[0-9a-f]{40} # v2'),
      ),
    );
    expect(workflow, contains('api-level: [29, 34, 36]'));
    expect(workflow, contains(r'api-level: ${{ matrix.api-level }}'));
  });

  test(
    'nightly runs every supported API level without claiming device proof',
    () {
      final workflow = File(
        '.github/workflows/nightly-android.yml',
      ).readAsStringSync();

      expect(workflow, contains('api-level: [29, 30, 31, 32, 33, 34, 35, 36]'));
      expect(workflow, contains('app:connectedPlayDebugAndroidTest'));
      expect(workflow, contains('phase3_emulator_reboot_probe.sh'));
      expect(workflow, contains('PHASE3_CONFIRM_EPHEMERAL_AVD=1'));
      expect(workflow, contains('PHASE3_EVIDENCE_OUTPUT='));
      expect(
        workflow,
        matches(RegExp(r'actions/upload-artifact@[0-9a-f]{40} # v4')),
      );
      expect(workflow, isNot(contains('PHYSICAL_DEVICE_PASS')));
    },
  );

  test('release verification compiles device tests', () {
    final script = File('scripts/verify_release.sh').readAsStringSync();

    expect(script, contains('app:testPlayDebugUnitTest'));
    expect(script, contains('app:assemblePlayDebugAndroidTest'));
    expect(
      RegExp(r'\( cd android && \./gradlew').allMatches(script).length,
      greaterThanOrEqualTo(2),
      reason:
          'smoke lint and playDebug tests must run in separate Gradle '
          'processes to avoid Flutter native-assets variant races',
    );
    expect(
      script,
      isNot(contains(r'app:assemble${CAP_FLAVOR}DebugAndroidTest')),
    );
  });

  test('tagged release isolates lint from playDebug native-assets work', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    expect(workflow, contains('name: Android release lint'));
    expect(
      workflow,
      contains('run: ./gradlew app:lintPlayRelease --console=plain'),
    );
    expect(
      workflow,
      contains(
        'run: ./gradlew app:testPlayDebugUnitTest '
        'app:assemblePlayDebugAndroidTest --console=plain',
      ),
    );
    expect(
      RegExp(r'run: \./gradlew').allMatches(workflow).length,
      greaterThanOrEqualTo(2),
      reason: 'lint and playDebug tests must use separate Gradle processes',
    );
  });
}
