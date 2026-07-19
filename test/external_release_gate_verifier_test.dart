import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external gate template is fail-closed and complete', () {
    final payload =
        jsonDecode(
              File('release-evidence/gates.template.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final gates = (payload['gates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(payload['schemaVersion'], 2);
    expect(gates.map((gate) => gate['id']).toSet(), {
      for (var i = 0; i <= 10; i++) 'G$i',
    });
    expect(gates.every((gate) => gate['status'] == 'UNVERIFIED'), isTrue);
    expect(gates.every((gate) => (gate['evidence'] as List).isEmpty), isTrue);
    expect(
      File('scripts/verify_external_release_gates.py').readAsStringSync(),
      allOf(
        contains('MASTER_GO_NO_GO_PASS'),
        contains('closed soak is shorter than 14 days'),
        contains('closed soak has fewer than 12 testers'),
        contains('open P0/P1 finding blocks release'),
        contains('AAB SHA-256 does not match manifest'),
      ),
    );
  });

  test('master verifier binds all gates to provenance schema v2', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-external-gates-v2-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final aab = File('${directory.path}/candidate.aab')
      ..writeAsStringSync('immutable candidate');
    final artifacts = <String, File>{
      'aab': aab,
      for (final name in <String>[
        'androidReleaseSurface',
        'sbom',
        'mergedManifest',
        'r8Mapping',
        'dartSymbolsIndex',
        'nativeSymbolsIndex',
        'criticalCoverage',
        'mutationReport',
        'lintReport',
        'dependencyLockPub',
        'dependencyLockGradle',
        'gradleVerification',
        'sourceProvenance',
        'secretScan',
        'thirdPartyNotices',
      ])
        name: File('${directory.path}/$name.txt')
          ..writeAsStringSync('evidence:$name'),
    };
    final provenance = File('${directory.path}/provenance-v2.json');
    final generatorArguments = <String>[
      'scripts/generate_release_provenance.py',
      '--output',
      provenance.path,
      '--tag',
      'v1.0.3',
      '--tag-object',
      'a' * 40,
      '--commit',
      'b' * 40,
      '--tree',
      'c' * 40,
      '--version-name',
      '1.0.3',
      '--version-code',
      '10003',
      '--upload-cert',
      'd' * 64,
      '--play-app-signing-cert',
      'e' * 64,
      '--repository',
      'owner/korubeni',
      '--workflow-run-url',
      'https://github.com/owner/korubeni/actions/runs/123',
      for (final entry in artifacts.entries) ...<String>[
        '--artifact',
        '${entry.key}=${entry.value.path}',
      ],
    ];
    final generated = await Process.run('python3', generatorArguments);
    expect(
      generated.exitCode,
      0,
      reason: '${generated.stdout}\n${generated.stderr}',
    );

    final witness = File('${directory.path}/witness.txt')
      ..writeAsStringSync('candidate-bound witness');
    final aabHash = _sha256(aab);
    final witnessHash = _sha256(witness);
    final manifest = File('${directory.path}/gates.json');
    Map<String, dynamic> completeManifest() => <String, dynamic>{
      'schemaVersion': 2,
      'candidate': <String, dynamic>{
        'gitCommit': 'b' * 40,
        'gitTree': 'c' * 40,
        'tag': 'v1.0.3',
        'tagObjectSha': 'a' * 40,
        'versionName': '1.0.3',
        'versionCode': 10003,
        'aabSha256': aabHash,
        'uploadCertificateSha256': 'd' * 64,
        'playAppSigningCertificateSha256': 'e' * 64,
        'workflowRunUrl': 'https://github.com/owner/korubeni/actions/runs/123',
        'provenance': <String, dynamic>{
          'path': 'provenance-v2.json',
          'sha256': _sha256(provenance),
        },
      },
      'gates': <Map<String, dynamic>>[
        for (var index = 0; index <= 10; index++)
          <String, dynamic>{
            'id': 'G$index',
            'status': 'PASS',
            'owners': <String>['owner'],
            'evidence': <Map<String, dynamic>>[
              <String, dynamic>{
                'path': 'witness.txt',
                'sha256': witnessHash,
                'candidateBound': true,
              },
            ],
          },
      ],
      'openFindings': <Object>[],
      'closedSoak': <String, dynamic>{
        'status': 'PASS',
        'days': 14,
        'testers': 12,
        'safetyIncidents': 0,
        'aabSha256': aabHash,
      },
      'hotfixDrill': <String, dynamic>{'status': 'PASS'},
      'approvals': <Map<String, dynamic>>[
        for (final role in <String>[
          'product',
          'safety',
          'qa',
          'security',
          'privacy_legal',
          'billing_play',
          'release',
        ])
          <String, dynamic>{
            'role': role,
            'decision': 'APPROVE',
            'signer': '$role-reviewer',
            'signedAt': '2026-07-18T12:00:00Z',
          },
      ],
    };
    manifest.writeAsStringSync(jsonEncode(completeManifest()));

    final passed = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(passed.exitCode, 0, reason: '${passed.stdout}\n${passed.stderr}');
    expect(passed.stdout, contains('MASTER_GO_NO_GO_PASS'));

    final drifted = completeManifest();
    (drifted['candidate'] as Map<String, dynamic>)['gitTree'] = 'f' * 40;
    manifest.writeAsStringSync(jsonEncode(drifted));
    final failed = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(failed.exitCode, 1);
    expect(failed.stderr, contains('provenance gitTree mismatch'));
  });
}

String _sha256(File file) {
  final result = Process.runSync('shasum', <String>['-a', '256', file.path]);
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
  return result.stdout.toString().split(RegExp(r'\s+')).first;
}
