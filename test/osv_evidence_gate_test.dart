import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('korubeni-osv-evidence-');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  File writeJson(String name, Object value) =>
      File('${temp.path}/$name')..writeAsStringSync(jsonEncode(value));

  Future<ProcessResult> generate({
    required File pubQuery,
    required File pubResponse,
    required File mavenQuery,
    required File mavenResponse,
  }) {
    return Process.run('python3', <String>[
      'scripts/generate_osv_evidence.py',
      '--repo',
      Directory.current.path,
      '--pub-query',
      pubQuery.path,
      '--pub-response',
      pubResponse.path,
      '--maven-query',
      mavenQuery.path,
      '--maven-response',
      mavenResponse.path,
      '--output',
      '${temp.path}/osv-audit.json',
      '--scanned-at',
      '2026-07-20T10:30:00Z',
    ]);
  }

  test('binds a clean result to source and exact dependency inputs', () async {
    final pubQuery = writeJson('pub-query.json', <String, Object?>{
      'queries': <Object?>[
        <String, Object?>{
          'package': <String, Object?>{
            'ecosystem': 'Pub',
            'name': 'example_pub',
          },
          'version': '1.2.3',
        },
      ],
    });
    final mavenQuery = writeJson('maven-query.json', <String, Object?>{
      'queries': <Object?>[
        <String, Object?>{
          'package': <String, Object?>{
            'ecosystem': 'Maven',
            'name': 'com.example:example',
          },
          'version': '4.5.6',
        },
      ],
    });
    final pubResponse = writeJson('pub-response.json', <String, Object?>{
      'results': <Object?>[<String, Object?>{}],
    });
    final mavenResponse = writeJson('maven-response.json', <String, Object?>{
      'results': <Object?>[<String, Object?>{}],
    });

    final result = await generate(
      pubQuery: pubQuery,
      pubResponse: pubResponse,
      mavenQuery: mavenQuery,
      mavenResponse: mavenResponse,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final report =
        jsonDecode(File('${temp.path}/osv-audit.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(report['schemaVersion'], 1);
    expect(report['status'], 'PASS');
    expect(report['scannedAt'], '2026-07-20T10:30:00Z');
    expect(report['endpoint'], 'https://api.osv.dev/v1/querybatch');
    expect(report['findingCount'], 0);
    expect(
      (report['source'] as Map<String, dynamic>)['gitCommit'],
      matches(RegExp(r'^[0-9a-f]{40}$')),
    );
    expect(
      (report['source'] as Map<String, dynamic>)['gitTree'],
      matches(RegExp(r'^[0-9a-f]{40}$')),
    );
    final inputs = report['inputs'] as Map<String, dynamic>;
    expect(inputs['pubspecLockSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(inputs['gradleLockSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    final ecosystems = report['ecosystems'] as Map<String, dynamic>;
    expect((ecosystems['Pub'] as Map<String, dynamic>)['queryCount'], 1);
    expect((ecosystems['Maven'] as Map<String, dynamic>)['queryCount'], 1);
  });

  test('fails closed when OSV response count does not match queries', () async {
    final query = writeJson('query.json', <String, Object?>{
      'queries': <Object?>[
        <String, Object?>{
          'package': <String, Object?>{'ecosystem': 'Pub', 'name': 'example'},
          'version': '1.0.0',
        },
      ],
    });
    final emptyQuery = writeJson('empty-query.json', <String, Object?>{
      'queries': <Object?>[],
    });
    final invalidResponse = writeJson(
      'invalid-response.json',
      <String, Object?>{'results': <Object?>[]},
    );
    final emptyResponse = writeJson('empty-response.json', <String, Object?>{
      'results': <Object?>[],
    });

    final result = await generate(
      pubQuery: query,
      pubResponse: invalidResponse,
      mavenQuery: emptyQuery,
      mavenResponse: emptyResponse,
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('OSV response count mismatch'));
    expect(File('${temp.path}/osv-audit.json').existsSync(), isFalse);
  });

  test(
    'known vulnerability is a blocking FAIL with bounded identifiers',
    () async {
      final query = writeJson('query.json', <String, Object?>{
        'queries': <Object?>[
          <String, Object?>{
            'package': <String, Object?>{'ecosystem': 'Pub', 'name': 'example'},
            'version': '1.0.0',
          },
        ],
      });
      final emptyQuery = writeJson('empty-query.json', <String, Object?>{
        'queries': <Object?>[],
      });
      final response = writeJson('response.json', <String, Object?>{
        'results': <Object?>[
          <String, Object?>{
            'vulns': <Object?>[
              <String, Object?>{'id': 'OSV-TEST-1'},
            ],
          },
        ],
      });
      final emptyResponse = writeJson('empty-response.json', <String, Object?>{
        'results': <Object?>[],
      });

      final result = await generate(
        pubQuery: query,
        pubResponse: response,
        mavenQuery: emptyQuery,
        mavenResponse: emptyResponse,
      );

      expect(result.exitCode, 1);
      final report =
          jsonDecode(File('${temp.path}/osv-audit.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(report['status'], 'FAIL');
      expect(report['findingCount'], 1);
      expect((report['findings'] as List<dynamic>).single, <String, dynamic>{
        'coordinate': 'Pub:example@1.0.0',
        'ids': <dynamic>['OSV-TEST-1'],
      });
    },
  );

  test('tagged workflow preserves OSV evidence in provenance', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final provenance = File(
      'scripts/generate_release_provenance.py',
    ).readAsStringSync();

    expect(
      workflow,
      contains(
        './scripts/audit_dependencies_osv.sh --output '
        'build/release-evidence/osv-audit.json',
      ),
    );
    expect(
      workflow,
      contains('osvAudit=build/release-evidence/osv-audit.json'),
    );
    expect(provenance, contains('"osvAudit"'));
  });

  test('dirty OSV evidence requires an explicit local-only opt-in', () {
    final runner = File(
      'scripts/audit_dependencies_osv.sh',
    ).readAsStringSync();
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    expect(runner, contains('ALLOW_DIRTY_LOCAL=false'));
    expect(runner, contains('--allow-dirty-local'));
    expect(runner, contains('GENERATOR_ARGS+=(--require-clean)'));
    expect(workflow, isNot(contains('--allow-dirty-local')));
  });
}
