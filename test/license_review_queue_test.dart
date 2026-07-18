import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exact 400-purl review queue stays human-unverified', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-license-review-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final sbom = File('${directory.path}/sbom.json');
    final queue = File('${directory.path}/queue.json');

    final sbomResult = await Process.run('dart', <String>[
      'scripts/generate_cyclonedx_sbom.dart',
      '--output',
      sbom.path,
      '--license-evidence',
      'config/dependency_license_evidence.json',
    ]);
    expect(
      sbomResult.exitCode,
      0,
      reason: '${sbomResult.stdout}\n${sbomResult.stderr}',
    );
    final queueResult = await Process.run('python3', <String>[
      'scripts/prepare_license_review_queue.py',
      '--sbom',
      sbom.path,
      '--evidence',
      'config/dependency_license_evidence.json',
      '--output',
      queue.path,
    ]);
    expect(
      queueResult.exitCode,
      0,
      reason: '${queueResult.stdout}\n${queueResult.stderr}',
    );

    final payload =
        jsonDecode(queue.readAsStringSync()) as Map<String, dynamic>;
    final entries = (payload['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(payload['componentCount'], 400);
    expect(payload['reviewedCount'], 0);
    expect(payload['unreviewedCount'], 400);
    expect(entries, hasLength(400));
    expect(entries.map((entry) => entry['purl']).toSet(), hasLength(400));
    expect(
      entries.every((entry) => entry['status'] == 'HUMAN_REVIEW_REQUIRED'),
      isTrue,
    );
    expect(entries.every((entry) => entry['spdxId'] == null), isTrue);
    expect(entries.every((entry) => entry['primarySourceUrl'] == null), isTrue);
    expect(
      entries.map((entry) => entry['purl'] as String).toList(),
      orderedEquals(
        entries.map((entry) => entry['purl'] as String).toList()..sort(),
      ),
    );
  });
}
