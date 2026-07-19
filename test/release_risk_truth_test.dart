import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release risk document matches the locked Android support envelope', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final risks = File('docs/release_risks.md').readAsStringSync();

    for (final setting in <String>[
      'minSdk = 29',
      'compileSdk = 36',
      'targetSdk = 36',
    ]) {
      expect(gradle, contains(setting));
      expect(risks, contains('`$setting`'));
    }

    expect(risks, isNot(contains('minSdk = flutter.minSdkVersion')));
    expect(risks, isNot(contains('flutter_jailbreak_detection')));
    expect(risks, isNot(contains('optimize_battery')));
  });

  test('16 KB claims distinguish local smoke evidence from Play proof', () {
    final risks = File('docs/release_risks.md').readAsStringSync();

    expect(risks, contains('1 November 2025'));
    expect(risks, contains('AGP 8.5.1'));
    expect(risks, contains('NDK r28'));
    expect(risks, contains('10/10'));
    expect(risks, contains('NON_RELEASE_SMOKE'));
    expect(risks, matches(RegExp(r'not production-candidate\s+evidence')));
  });

  test('OSM local controls do not overclaim external release proof', () {
    final risks = File('docs/release_risks.md').readAsStringSync();

    expect(risks, contains('OSM_TILE_LOCAL_CONTROLS_PASS'));
    expect(risks, contains('NETWORK_CAPTURE_AND_COUNSEL_UNVERIFIED'));
    expect(risks, contains('128 MiB'));
    expect(risks, isNot(contains('OSM_TILE_GATE_OPEN')));
    expect(risks, isNot(contains('Before a larger production launch')));
  });
}
