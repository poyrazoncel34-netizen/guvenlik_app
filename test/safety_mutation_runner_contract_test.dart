import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release mutation runner owns all seven mandatory regressions', () {
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
      'M07_LOCKOUT_WRITE_FAILURE_IGNORED',
    ]) {
      expect(source, contains(mutation));
    }
    expect(source, contains('BASELINE_FAILED'));
    expect(source, contains('MUTATION_NOT_KILLED'));
    expect(source, contains('SAFETY_MUTATION_PASS'));
    expect(source, contains('shutil.rmtree(workspace'));
  });

  // M07 sat red for weeks with "anchor occurrence 1 was not found": three
  // comment lines landed between its anchor lines, the mutant was never
  // injected, and the gate failed as SURVIVED_OR_INVALID. A green "7/7" is
  // only meaningful if every mutant can actually be applied, so the anchors
  // are checked against the live source on every test run.
  test('every mutation anchor exists in the current source', () {
    final listing = Process.runSync('python3', <String>[
      '-c',
      'import importlib.util, json, sys\n'
          'spec = importlib.util.spec_from_file_location('
          '"m", "scripts/run_safety_mutations.py")\n'
          'm = importlib.util.module_from_spec(spec)\n'
          'sys.modules["m"] = m\n'
          'spec.loader.exec_module(m)\n'
          'print(json.dumps([[x.mutation_id, x.path, x.old, x.occurrence] '
          'for x in m.MUTATIONS]))',
    ]);
    expect(listing.exitCode, 0, reason: '${listing.stderr}');
    final mutations = jsonDecode(listing.stdout as String) as List<dynamic>;
    expect(mutations, hasLength(7));
    for (final entry in mutations.cast<List<dynamic>>()) {
      final id = entry[0] as String;
      final source = File(entry[1] as String).readAsStringSync();
      final anchor = entry[2] as String;
      final occurrence = entry[3] as int;
      expect(
        anchor.allMatches(source).length,
        greaterThanOrEqualTo(occurrence),
        reason: '$id cannot be injected: its anchor drifted from ${entry[1]}',
      );
    }
  });
}
