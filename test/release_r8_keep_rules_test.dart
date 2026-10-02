// Every component the OS instantiates by name must survive R8 under its own name.
//
// Why this gate exists
// --------------------
// proguard-rules.pro used to carry `-keep class com.poyrazoncel.korubeni.** { *; }`.
// With that rule, `isMinifyEnabled = true` shrank the libraries and left this
// app's own code completely readable (audit F-05). Removing it obfuscates 74 of
// 88 app classes -- and makes the keep list load-bearing for the first time.
//
// The failure mode this guards is silent and has the worst consequence in this
// product. A PendingIntent bakes its target class name in at SCHEDULING time.
// R8's renaming is not stable across builds, so an alarm armed by one build and
// fired after an app update resolves the name recorded earlier. If that name was
// obfuscated away, nothing fails at build time, no test goes red, no crash is
// logged -- the alarm simply never arrives, which in this app means a Check-In or
// Safe Walk expiry that never dials.
//
// The expected set is DERIVED FROM THE MANIFEST rather than hardcoded, so adding
// a component without a keep rule fails here instead of shipping.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _proguardPath = 'android/app/proguard-rules.pro';
const _package = 'com.poyrazoncel.korubeni';

/// Components declared with a RELATIVE name (`android:name=".foo.Bar"`), which is
/// exactly the set this application owns. Third-party components appear with a
/// fully-qualified name and are not ours to keep -- several are in fact removed
/// with `tools:node="remove"`.
Set<String> _ownComponents(String manifest) {
  final matches = RegExp(r'android:name="\.([A-Za-z0-9_.]+)"').allMatches(manifest);
  return matches.map((match) => '$_package.${match.group(1)}').toSet();
}

void main() {
  late String manifest;
  late String proguard;

  setUpAll(() {
    manifest = File(_manifestPath).readAsStringSync();
    // Rules only, comments stripped. This file EXPLAINS the rule it no longer
    // carries, so a plain substring search finds the wildcard in the prose and
    // reports a regression that is not there -- which is exactly what happened
    // the first time this test ran.
    proguard = File(_proguardPath)
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n');
  });

  test('the manifest actually yields components to check', () {
    // Negative control for the parser itself. If the attribute spelling ever
    // changes, this gate would otherwise pass by checking an empty set -- the
    // quietest way for a safety gate to stop existing.
    expect(
      _ownComponents(manifest).length,
      greaterThanOrEqualTo(10),
      reason:
          'Parsed almost no components from the manifest, so the keep-rule '
          'check below would be vacuous.',
    );
  });

  test('every manifest-declared component has an explicit keep rule', () {
    final missing = <String>[];
    for (final component in _ownComponents(manifest)) {
      if (!proguard.contains('-keep class $component')) {
        missing.add(component);
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These components are declared in the manifest but have no explicit '
          '-keep rule. AGP emits a name-only rule for manifest components, but '
          'this file is where the PendingIntent-critical names are stated so a '
          'reader can check one list against the other:\n  '
          '${missing.join('\n  ')}',
    );
  });

  test('the blanket app-wide keep rule does not come back', () {
    // This is the F-05 regression itself. A wildcard here silently restores the
    // old behaviour: the build still says minified, and nothing is obfuscated.
    expect(
      proguard.contains('-keep class $_package.** '),
      isFalse,
      reason:
          'A blanket keep over the whole app package makes isMinifyEnabled '
          'cosmetic for this app\'s own code. If it is needed again, say which '
          'class needed it and keep that class instead.',
    );
    expect(
      proguard.contains('-keepclassmembers class $_package.**'),
      isFalse,
      reason:
          'Keeping every public member app-wide has the same effect on the '
          'members that matter.',
    );
  });

  test('the Flutter bridge is kept by interface, not by package wildcard', () {
    // These three survive obfuscation because they implement a Flutter
    // interface, not because of an app-package rule. If these rules go, the
    // platform channels break at runtime and not at build time.
    expect(
      proguard,
      contains('io.flutter.plugin.common.MethodChannel\$MethodCallHandler'),
    );
    expect(
      proguard,
      contains('io.flutter.plugin.common.EventChannel\$StreamHandler'),
    );
  });
}
