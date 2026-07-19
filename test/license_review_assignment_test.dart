import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unreviewed license work is split evenly without inferring licenses', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-license-assignments-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final queue = File('${directory.path}/queue.json');
    final output = File('${directory.path}/assignments.json');
    queue.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'componentCount': 8,
        'reviewedCount': 0,
        'unreviewedCount': 8,
        'status': 'HUMAN_REVIEW_REQUIRED',
        'entries': <Object?>[
          for (var index = 0; index < 8; index++)
            <String, Object?>{
              'purl': 'pkg:pub/example_$index@1.0.$index',
              'name': 'example_$index',
              'version': '1.0.$index',
              'ecosystem': 'Pub',
              'registryReference':
                  'https://pub.dev/packages/example_$index/versions/1.0.$index',
              'status': 'HUMAN_REVIEW_REQUIRED',
            },
        ],
      }),
    );

    final result = await Process.run('python3', <String>[
      'scripts/prepare_license_review_assignments.py',
      '--queue',
      queue.path,
      '--output',
      output.path,
      for (final reviewer in <String>['reviewer-a', 'reviewer-b', 'reviewer-c', 'reviewer-d']) ...<String>[
        '--reviewer',
        reviewer,
      ],
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('LICENSE_REVIEW_ASSIGNMENTS_READY'));
    final payload =
        jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    final assignments = (payload['assignments'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(payload['schemaVersion'], 1);
    expect(payload['assignedCount'], 8);
    expect(payload['reviewedCount'], 0);
    expect(payload['status'], 'HUMAN_REVIEW_REQUIRED');
    expect(assignments, hasLength(4));
    expect(
      assignments.map((entry) => entry['assignmentCount']),
      everyElement(2),
    );
    final workItems = assignments
        .expand((entry) => (entry['items'] as List<dynamic>))
        .cast<Map<String, dynamic>>()
        .toList();
    expect(workItems, hasLength(8));
    expect(workItems.map((entry) => entry['purl']).toSet(), hasLength(8));
    expect(
      workItems.every(
        (entry) => entry['status'] == 'HUMAN_REVIEW_REQUIRED',
      ),
      isTrue,
    );
    expect(workItems.every((entry) => !entry.containsKey('spdxId')), isTrue);
    expect(
      workItems.every((entry) => !entry.containsKey('primarySourceUrl')),
      isTrue,
    );
  });

  test('review assignment rejects duplicate accountable reviewers', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-license-duplicate-reviewer-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final queue = File('${directory.path}/queue.json')
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'componentCount': 1,
          'reviewedCount': 0,
          'unreviewedCount': 1,
          'status': 'HUMAN_REVIEW_REQUIRED',
          'entries': <Object?>[
            <String, Object?>{
              'purl': 'pkg:pub/example@1.0.0',
              'status': 'HUMAN_REVIEW_REQUIRED',
            },
          ],
        }),
      );

    final result = await Process.run('python3', <String>[
      'scripts/prepare_license_review_assignments.py',
      '--queue',
      queue.path,
      '--output',
      '${directory.path}/assignments.json',
      for (var index = 0; index < 4; index++) ...<String>[
        '--reviewer',
        'same-reviewer',
      ],
    ]);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('reviewers must be unique'));
  });
}
