// Every SRC/TEST/CMD/DOC citation in the audit and release documents must name a
// file this repository contains.
//
// Why this gate exists
// --------------------
// The 2026-10-01 security audit found PRODUCTION_AUDIT.md asserting a security
// control -- "safe_device root detection" -- that A-017 had removed from the
// runtime path, and naming it as a mitigation for entitlement tampering that
// nothing in the app actually performs. Nothing caught it. The accounting gate
// proves every requirement has a row; the absence gate proves no row denies
// something the repository contains; neither asks whether a row's citation
// still points at a real file.
//
// What this gate does NOT prove
// ----------------------------
// It is mechanical. A citation that resolves is not a citation that is TRUE: a
// test can exist, pass, and assert something other than what the sentence
// claims. Semantic drift stays a human review duty, and the script says so in
// its own output. Pretending otherwise would be the same overclaim the gate was
// written to catch.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every document citation resolves to a real file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-doc-citations-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final output = File('${directory.path}/citations.json');

    final result = await Process.run('python3', <String>[
      'scripts/verify_doc_citations.py',
      '--output',
      output.path,
    ]);

    expect(
      result.exitCode,
      0,
      reason:
          'A document cites a file that does not exist:\n'
          '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('DOC_CITATION_PASS'));

    final report =
        jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    expect(report['status'], 'PASS');
    expect(report['unresolvedCount'], 0);
    expect(
      report['citationCount'],
      greaterThan(500),
      reason:
          'The scan found far fewer citations than this repository carries, '
          'which means the pattern stopped matching rather than that the '
          'documents got cleaner. A gate that silently scans nothing passes '
          'forever.',
    );
    expect(
      report['limitation'],
      contains('not that the cited file supports the claim'),
      reason:
          'The report must keep stating its own limit; a PASS here is not '
          'evidence that a claim is true.',
    );
  });

  test('the citation check can detect a broken citation', () async {
    // A gate never seen red is not evidence. The script injects one impossible
    // citation into its own document set, measures against a baseline taken
    // from THIS tree, and restores the file.
    final result = await Process.run('python3', <String>[
      'scripts/verify_doc_citations.py',
      '--negative-control',
    ]);

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('NEGATIVE_CONTROL_PASS'));
  });

  test('the negative control leaves the working tree clean', () async {
    // The control writes to a tracked document. If it ever fails to restore it,
    // a later gate would fail for a reason nobody could trace.
    await Process.run('python3', <String>[
      'scripts/verify_doc_citations.py',
      '--negative-control',
    ]);

    final status = await Process.run('git', <String>[
      'status',
      '--porcelain',
      'SECURITY.md',
    ]);

    expect(
      (status.stdout as String).trim(),
      isEmpty,
      reason: 'the negative control modified SECURITY.md and did not restore it',
    );
  });
}
