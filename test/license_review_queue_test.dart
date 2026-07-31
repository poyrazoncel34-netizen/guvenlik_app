import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queue still reports the unreviewed path on a partial fixture', () async {
    // The live-data test above only exercises the fully-reviewed branch. Keep a
    // synthetic fixture on the HUMAN_REVIEW_REQUIRED branch so that path stays
    // covered no matter what state the real evidence file is in -- an untested
    // branch is exactly how the SBOM generator's evidence path stayed broken.
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-license-review-partial-',
    );
    addTearDown(() => directory.delete(recursive: true));
    const reviewedPurl = 'pkg:pub/alpha@1.0.0';
    const unreviewedPurl = 'pkg:maven/com.example/beta@2.0.0';

    File('${directory.path}/sbom.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'bomFormat': 'CycloneDX',
        'components': <Object?>[
          <String, Object?>{
            'type': 'library',
            'name': 'alpha',
            'version': '1.0.0',
            'purl': reviewedPurl,
            'properties': <Object?>[
              <String, Object?>{'name': 'korubeni:ecosystem', 'value': 'Pub'},
            ],
          },
          <String, Object?>{
            'type': 'library',
            'group': 'com.example',
            'name': 'beta',
            'version': '2.0.0',
            'purl': unreviewedPurl,
            'properties': <Object?>[
              <String, Object?>{'name': 'korubeni:ecosystem', 'value': 'Maven'},
            ],
          },
        ],
      }),
    );
    File('${directory.path}/evidence.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'entries': <String, Object?>{
          reviewedPurl: <String, Object?>{
            'spdxId': 'MIT',
            'sourceUrl': 'https://example.invalid/LICENSE',
            'sha256': 'a' * 64,
            'reviewedBy': 'fixture-reviewer',
            'reviewedAt': '2026-07-31',
          },
        },
      }),
    );

    final result = await Process.run('python3', <String>[
      'scripts/prepare_license_review_queue.py',
      '--sbom',
      '${directory.path}/sbom.json',
      '--evidence',
      '${directory.path}/evidence.json',
      '--output',
      '${directory.path}/queue.json',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final payload =
        jsonDecode(
              File('${directory.path}/queue.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(payload['componentCount'], 2);
    expect(payload['reviewedCount'], 1);
    expect(payload['unreviewedCount'], 1);
    expect(payload['status'], 'HUMAN_REVIEW_REQUIRED');

    final entries = (payload['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final unreviewed = entries.singleWhere(
      (entry) => entry['purl'] == unreviewedPurl,
    );
    expect(unreviewed['status'], 'HUMAN_REVIEW_REQUIRED');
    expect(unreviewed['spdxId'], isNull);
    expect(unreviewed['primarySourceUrl'], isNull);
    expect(unreviewed['reviewedBytesSha256'], isNull);
    expect(unreviewed['reviewedBy'], isNull);
    expect(unreviewed['reviewedAt'], isNull);
  });

  test('exact 400-purl review queue mirrors the accountable evidence', () async {
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
    expect(payload['reviewedCount'], 400);
    expect(payload['unreviewedCount'], 0);
    expect(entries, hasLength(400));
    expect(entries.map((entry) => entry['purl']).toSet(), hasLength(400));
    expect(entries.every((entry) => entry['status'] == 'REVIEWED'), isTrue);

    // The queue tool must only carry evidence forward, never invent it: every
    // field it reports has to be byte-identical to the accountable evidence
    // file. Before the review landed this was asserted as "all fields null";
    // the same contract now reads as "all fields equal to the evidence".
    final evidence =
        (jsonDecode(
                  File(
                    'config/dependency_license_evidence.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['entries']
            as Map<String, dynamic>;
    expect(evidence, hasLength(400));
    for (final entry in entries) {
      final purl = entry['purl'] as String;
      final reviewed = evidence[purl] as Map<String, dynamic>;
      expect(entry['spdxId'], reviewed['spdxId'], reason: purl);
      expect(entry['primarySourceUrl'], reviewed['sourceUrl'], reason: purl);
      expect(entry['reviewedBytesSha256'], reviewed['sha256'], reason: purl);
      expect(entry['reviewedBy'], reviewed['reviewedBy'], reason: purl);
      expect(entry['reviewedAt'], reviewed['reviewedAt'], reason: purl);
    }
    expect(
      entries.map((entry) => entry['purl'] as String).toList(),
      orderedEquals(
        entries.map((entry) => entry['purl'] as String).toList()..sort(),
      ),
    );
  });
}
