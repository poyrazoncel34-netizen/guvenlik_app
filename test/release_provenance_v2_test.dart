import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _artifactNames = <String>[
  'aab',
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
];

void main() {
  test(
    'schema v2 binds source signing workflow and every artifact hash',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'korubeni-provenance-v2-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/provenance.json');
      final arguments = <String>[
        'scripts/generate_release_provenance.py',
        '--output',
        output.path,
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
      ];
      for (final name in _artifactNames) {
        final artifact = File('${directory.path}/$name.bin')
          ..writeAsStringSync('artifact:$name');
        arguments.addAll(<String>['--artifact', '$name=${artifact.path}']);
      }

      final result = await Process.run('python3', arguments);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final payload =
          jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
      expect(payload['schemaVersion'], 2);
      expect(payload['source'], <String, dynamic>{
        'gitCommit': 'b' * 40,
        'gitTree': 'c' * 40,
        'signedTag': <String, dynamic>{'name': 'v1.0.3', 'objectSha': 'a' * 40},
      });
      expect(
        (payload['candidate'] as Map<String, dynamic>)['aabSha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
      expect(payload['signing'], <String, dynamic>{
        'uploadCertificateSha256': 'd' * 64,
        'playAppSigningCertificateSha256': 'e' * 64,
      });
      expect(
        (payload['artifacts'] as Map<String, dynamic>).keys.toSet(),
        _artifactNames.toSet(),
      );
    },
  );

  test(
    'missing required artifact fails closed without an output file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'korubeni-provenance-v2-fail-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/provenance.json');
      final artifact = File('${directory.path}/aab.bin')
        ..writeAsStringSync('aab');

      final result = await Process.run('python3', <String>[
        'scripts/generate_release_provenance.py',
        '--output',
        output.path,
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
        '--artifact',
        'aab=${artifact.path}',
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('missing required artifacts'));
      expect(output.existsSync(), isFalse);
    },
  );
}
