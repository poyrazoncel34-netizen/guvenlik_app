import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audit rows must not assert the absence of things this repository contains.
///
/// The accounting gate proves every requirement has a row. It never asked
/// whether a row's evidence is still TRUE, and the final independent review
/// found seven rows graded FAIL on one pasted sentence -- "no ticketing system,
/// ownership model, severity scale or response-time commitment exists in the
/// repository" -- against a tree whose own `docs/release/incident_runbook.md`
/// carries a severity ladder with per-level response targets. Two more rows
/// claimed no hardware-keyboard pass had been performed while the device record
/// of one was already cited as PASS by four other rows.
///
/// `scripts/verify_absence_claims.py` is deliberately registry-driven rather
/// than a natural-language parser: every absence claim names what would refute
/// it, and the check fails if that thing exists.
void main() {
  test('no audit row asserts an absence the repository refutes', () async {
    final result = await Process.run('python3', [
      'scripts/verify_absence_claims.py',
    ]);
    expect(
      result.exitCode,
      0,
      reason:
          'A row claims something is missing that is present, or a registered '
          'claim has drifted out of its row:\n'
          '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('ABSENCE_CLAIMS_PASS'));
  });

  test('the absence check can detect a refuted claim', () async {
    final result = await Process.run('python3', [
      'scripts/verify_absence_claims.py',
      '--negative-control',
    ]);
    expect(
      result.exitCode,
      0,
      reason:
          'The control registers a claim refuted by a file that certainly '
          'exists; if that does not fire, the check is decorative:\n'
          '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('REFUTED_ABSENCE_CLAIM'));
  });
}
