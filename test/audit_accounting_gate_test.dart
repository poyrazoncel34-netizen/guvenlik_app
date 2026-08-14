import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The accounting invariant between `docs/MASTER_PRODUCTION_CHECKLIST.md` and
/// `PRODUCTION_AUDIT.md`, enforced mechanically instead of by hand-maintained
/// tables.
///
/// Round 1 of the independent review found five mutually contradictory summary
/// tables; round 2 confirmed the counts were correct but had to re-derive them
/// from scratch to know that. This gate makes the derivation reproducible, and
/// it fails on every class of drift the reviews found: a dropped requirement,
/// a duplicated canonical row, a requirement whose text no longer matches the
/// checklist, a status flipped without regenerating the summary, and the
/// section-77 launch matrix being parsed away.
void main() {
  group('audit accounting', () {
    test('checklist and audit reconcile exactly, with derived tables '
        'regenerated from the rows', () async {
      final directory = await Directory.systemTemp.createTemp(
        'korubeni-audit-accounting-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/accounting.json');

      final result = await Process.run('python3', [
        'scripts/verify_audit_accounting.py',
        '--checklist',
        'docs/MASTER_PRODUCTION_CHECKLIST.md',
        '--audit',
        'PRODUCTION_AUDIT.md',
        '--output',
        output.path,
      ]);

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );

      final payload =
          jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;

      // The canonical numbers. These are pinned deliberately: the checklist is
      // immutable, so a change here means the specification was edited and
      // that must be a conscious, separate decision.
      expect(payload['checklistRequirements'], 1738);
      expect(payload['auditRequirements'], 1738);
      expect(payload['checkboxRequirements'], 1714);
      expect(payload['launchMatrixRequirements'], 24);
      expect(payload['sections'], 80);
      expect(payload['missing'], 0);
      expect(payload['duplicated'], 0);
      expect(payload['unaccounted'], 0);
      expect(payload['textMismatches'], 0);
      expect(payload['problems'], isEmpty);

      final status = (payload['status'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      );
      expect(
        status.values.fold<int>(0, (a, b) => a + b),
        1738,
        reason: 'PASS + FAIL + PARTIAL + BLOCKED + N/A + UNVERIFIED must total '
            'the requirement count',
      );
    });

    test('the verifier detects a status flipped without regenerating the '
        'summary', () async {
      // Negative control. A gate that has never failed is not evidence.
      final directory = await Directory.systemTemp.createTemp(
        'korubeni-audit-accounting-neg-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final original = File('PRODUCTION_AUDIT.md').readAsStringSync();
      final firstPass = RegExp(
        r'^\| `MP-\d+-\d+` \|.*?\| \*\*PASS\*\* \| - \|.*$',
        multiLine: true,
      ).firstMatch(original);
      expect(
        firstPass,
        isNotNull,
        reason: 'harness precondition: the audit must contain a PASS row',
      );
      final mutated = File('${directory.path}/mutated.md')
        ..writeAsStringSync(
          original.replaceFirst(
            firstPass!.group(0)!,
            firstPass.group(0)!.replaceFirst('**PASS** | - |', '**FAIL** | P1 |'),
          ),
        );

      final result = await Process.run('python3', [
        'scripts/verify_audit_accounting.py',
        '--checklist',
        'docs/MASTER_PRODUCTION_CHECKLIST.md',
        '--audit',
        mutated.path,
      ]);

      expect(
        result.exitCode,
        isNot(0),
        reason: 'a hand-edited status that leaves the summary stale must fail',
      );
      expect(result.stdout.toString(), contains('SUMMARY_DRIFT'));
      expect(result.stdout.toString(), contains('SECTION_INDEX_DRIFT'));
    });

    test('the verifier detects two MEASURED rows answering with one sentence',
        () async {
      // Negative control for the IR-06 guard, and it exists because the gap it
      // covers was real: apply_evidence_matrix.py refuses to GENERATE duplicate
      // evidence, but three notification rows were written straight into the
      // audit with set_audit_row.py sharing one sentence, and every check
      // stayed green.
      final directory = await Directory.systemTemp.createTemp(
        'korubeni-audit-evidence-dup-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final original = File('PRODUCTION_AUDIT.md').readAsStringSync();
      final measured = original
          .split('\n')
          .where((line) => line.startsWith('| `MP-') &&
              line.split('|').length == 11 &&
              line.split('|')[6].trim().startsWith('MEASURED, not asserted'))
          .take(2)
          .toList();
      expect(measured, hasLength(2),
          reason: 'harness precondition: the audit must contain at least two '
              'rows claiming a measured result');

      // Give the second row the first row's evidence cell.
      final donor = measured[0].split('|')[6];
      final victim = measured[1];
      final mutated = File('${directory.path}/mutated.md')
        ..writeAsStringSync(
          original.replaceFirst(
            victim,
            victim.replaceFirst(victim.split('|')[6], donor),
          ),
        );

      final result = await Process.run('python3', <String>[
        'scripts/verify_audit_accounting.py',
        '--checklist',
        'docs/MASTER_PRODUCTION_CHECKLIST.md',
        '--audit',
        mutated.path,
      ]);

      expect(result.exitCode, isNot(0),
          reason: 'two measured rows sharing one sentence means at least one '
              'was never measured');
      expect(result.stdout.toString(), contains('EVIDENCE_DUPLICATED'));
    });

    test('rows that share a genuinely identical FACT are NOT flagged', () {
      // The other half of the decision, asserted so a future pass does not
      // "fix" it by rewording 662 true sentences. 76 N/A rows say "no AI/LLM
      // dependency exists"; that is one fact with one answer, and writing 76
      // variants of it is the IR-06 defect reproduced in different words.
      final audit = File('PRODUCTION_AUDIT.md').readAsStringSync();
      final shared = RegExp(
        r'SRC: no AI/LLM dependency exists',
      ).allMatches(audit).length;
      expect(shared, greaterThan(10),
          reason: 'these rows share a true fact on purpose');
    });

    test('the verifier detects a requirement dropped from the audit', () async {
      final directory = await Directory.systemTemp.createTemp(
        'korubeni-audit-accounting-drop-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final lines = File('PRODUCTION_AUDIT.md').readAsLinesSync();
      final kept = lines
          .where((line) => !line.startsWith('| `MP-08-023`'))
          .join('\n');
      expect(
        kept.split('\n').length,
        lessThan(lines.length),
        reason: 'harness precondition: a row must actually have been removed',
      );
      final mutated = File('${directory.path}/mutated.md')
        ..writeAsStringSync(kept);

      final result = await Process.run('python3', [
        'scripts/verify_audit_accounting.py',
        '--checklist',
        'docs/MASTER_PRODUCTION_CHECKLIST.md',
        '--audit',
        mutated.path,
      ]);

      expect(result.exitCode, isNot(0));
      expect(result.stdout.toString(), contains('MISSING_ROW MP-08-023'));
    });
  });
}
