// Process artifacts are EVIDENCE for ~20 audit rows, so they need the same
// treatment as code: a test that fails when the cited content disappears.
//
// Without this, "MP-79-003 is closed by the runbook" is a claim about a file
// nobody checks, and the file can be deleted or gutted in a later cleanup with
// twenty audit rows silently pointing at nothing. Each assertion below names
// the row it carries.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void _requires(String path, Map<String, String> fragmentsByRequirement) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  final String source = file.readAsStringSync();
  fragmentsByRequirement.forEach((String requirement, String fragment) {
    expect(
      source.contains(fragment),
      isTrue,
      reason:
          '$path no longer contains the content $requirement cites: "$fragment"',
    );
  });
}

void main() {
  test('the incident runbook still carries what its rows cite', () {
    _requires('docs/release/incident_runbook.md', <String, String>{
      'MP-45-011 (severity model)': '## 1. Siddet modeli',
      'MP-50-019 (halt thresholds)': 'Crash-free session rate',
      'MP-50-019 (ANR threshold)': '> %0.47',
      'MP-50-020 (halt procedure)': '## 3. Yayilimi durdurma proseduru',
      'MP-67-009 (payment disable)': '## 4. Odemeyi devre disi birakma',
      'MP-65-015 (escalation)': '## 5. Guvenlik ve kotuye kullanim bildirim kanali',
      'MP-77-021 (support process)': '## 6. Destek sureci',
      'MP-79-001..005 (postmortem)': '## 7. Postmortem sablonu',
      'MP-77-022 / MP-80-017 (unrehearsed, honestly)': 'PROVA EDILMEDI',
      'MP-68-011 (Play cannot roll back)': 'Geri alma (rollback) Play\'de YOKTUR',
      'MP-78-014 (no telemetry consequence)': 'Telemetri yoktur',
    });
  });

  test('SECURITY.md still publishes a disclosure channel and its scope', () {
    _requires('SECURITY.md', <String, String>{
      'MP-32-049 (dedicated address)': 'korubeni.security@gmail.com',
      'MP-65-016 (scope table)': '## Kapsam',
      'MP-65-016 (design decisions are not bugs)': 'Biyometrik kilit acma YOKTUR',
    });
  });

  test('CHANGELOG.md exists and is bound to the store text', () {
    _requires('CHANGELOG.md', <String, String>{
      'MP-50-006 (single source for Play copy)': 'Yenilikler',
    });
  });

  test('the definition of done names the three things that were missing', () {
    _requires('.claude/rules/common/development-workflow.md', <String, String>{
      'MP-80-003 (accessibility)': '**Accessibility** named, not assumed',
      'MP-80-009 (schema/migration)': '**Error handling and schema**',
      'MP-80-016 (rollout)': '**Rollout**',
      'MP-80-017 (rollback reality)': 'Play cannot roll back',
    });
  });

  test('the resource-measurement pass records what it could NOT measure', () {
    // A measurement document that only lists successes is the more dangerous
    // kind. MP-41-005/007/022 are BLOCKED on exactly these gaps.
    _requires('docs/audit/device-verification-2026-08-14-perf-resources.md',
        <String, String>{
      'MP-41-005 (battery)': 'Computed drain: 0, actual drain: 0',
      'MP-41-007 (GPU)': 'Graphics: 0 kB',
      'MP-41-022 (thermal)': 'Thermal Status: 0',
      'honest limits section': '0. Bu kosumun DURUSTCE olcemedigi seyler',
    });
  });

  test('NEGATIVE CONTROL: the checker fails on a missing fragment', () {
    // Without this, every assertion above could be checking a file that happens
    // to contain everything, and the helper could be a no-op.
    bool failed = false;
    try {
      _requires('SECURITY.md', <String, String>{
        'synthetic': 'this string is deliberately not in the file',
      });
    } on TestFailure {
      failed = true;
    }
    expect(failed, isTrue, reason: 'the fragment checker cannot fail');
  });
}
