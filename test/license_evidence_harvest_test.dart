import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract for `scripts/harvest_license_evidence.py`.
///
/// The harvester exists to remove the mechanical half of the dependency licence
/// review (locating and hashing the exact resolved bytes). These tests pin the
/// accountable half it must never perform: no SPDX decision, no reviewer
/// identity, and no write into the human evidence file.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('korubeni-license-harvest-');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  String path(String relative) => '${temp.path}/$relative';

  /// Writes a pub cache whose licence text deliberately uses CRLF, so a
  /// regression to text-mode I/O (universal-newline translation) breaks the
  /// hash-for-bytes contract loudly instead of silently.
  void writePubCache({
    required String licenseText,
    List<String> packages = const <String>['alpha-1.0.0'],
  }) {
    for (final package in packages) {
      final dir = Directory(path('pub-cache/hosted/pub.dev/$package'))
        ..createSync(recursive: true);
      File('${dir.path}/LICENSE').writeAsBytesSync(utf8.encode(licenseText));
    }
  }

  void writeSbom({
    String bomFormat = 'CycloneDX',
    String second = 'beta',
    String secondVersion = '2.0.0',
  }) {
    File(path('sbom.json')).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'bomFormat': bomFormat,
        'components': <Object?>[
          <String, Object?>{
            'name': 'alpha',
            'version': '1.0.0',
            'purl': 'pkg:pub/alpha@1.0.0',
          },
          <String, Object?>{
            'name': second,
            'version': secondVersion,
            'purl': 'pkg:pub/$second@$secondVersion',
          },
        ],
      }),
    );
  }

  void writeEvidence(Map<String, Object?> entries) {
    File(path('evidence.json')).writeAsStringSync(
      jsonEncode(<String, Object?>{'schemaVersion': 1, 'entries': entries}),
    );
  }

  Future<ProcessResult> runHarvester({
    String? output,
    bool requireComplete = false,
    Map<String, String>? environment,
  }) => Process.run('python3', <String>[
    'scripts/harvest_license_evidence.py',
    '--sbom',
    path('sbom.json'),
    '--evidence',
    path('evidence.json'),
    '--output',
    output ?? path('proposal.json'),
    '--text-output-dir',
    path('texts'),
    '--pub-cache',
    path('pub-cache'),
    '--gradle-cache',
    path('gradle-cache'),
    '--flutter-root',
    path('flutter-root'),
    if (requireComplete) '--require-complete',
  ], environment: environment, includeParentEnvironment: true);

  /// Digest via python3 (already required to run the harvester) so the test
  /// needs no extra package dependency just to verify a hash.
  Future<String> sha256Of(String file) async {
    final result = await Process.run('python3', <String>[
      '-c',
      'import hashlib,sys;'
          "print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())",
      file,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return (result.stdout as String).trim();
  }

  Map<String, Object?> readProposal() =>
      jsonDecode(File(path('proposal.json')).readAsStringSync())
          as Map<String, Object?>;

  test('never writes the accountable human evidence file', () async {
    writePubCache(licenseText: 'MIT sample\n');
    writeSbom();
    writeEvidence(<String, Object?>{});

    final result = await runHarvester(
      output: 'config/dependency_license_evidence.json',
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('LICENSE_HARVEST_FAIL'));
    expect(
      File('config/dependency_license_evidence.json').readAsStringSync(),
      isNot(contains('candidates')),
      reason: 'The tracked evidence file must remain untouched.',
    );
  });

  test('proposal carries no SPDX decision, reviewer or review date', () async {
    writePubCache(licenseText: 'MIT sample\n');
    writeSbom();
    writeEvidence(<String, Object?>{});

    final result = await runHarvester();
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final raw = File(path('proposal.json')).readAsStringSync();
    expect(raw, isNot(contains('"spdxId"')));
    expect(raw, isNot(contains('"reviewedBy"')));
    expect(raw, isNot(contains('"reviewedAt"')));

    final proposal = readProposal();
    expect(proposal['documentKind'], 'unreviewed-license-harvest');
    expect(
      proposal['candidates'],
      isNot(contains('entries')),
      reason: 'A `candidates` root cannot be renamed into evidence position.',
    );

    final candidates = proposal['candidates']! as Map<String, Object?>;
    final alpha = candidates['pkg:pub/alpha@1.0.0']! as Map<String, Object?>;
    expect(alpha['status'], 'HUMAN_REVIEW_REQUIRED');
  });

  test('recorded hash matches the harvested bytes exactly', () async {
    // CRLF plus a trailing lone CR: any newline translation changes the digest.
    const licenseText = 'Line one\r\nLine two\r\n\rEnd\n';
    writePubCache(licenseText: licenseText);
    writeSbom();
    writeEvidence(<String, Object?>{});

    final result = await runHarvester();
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final candidates = readProposal()['candidates']! as Map<String, Object?>;
    final alpha = candidates['pkg:pub/alpha@1.0.0']! as Map<String, Object?>;
    final digest = alpha['sha256']! as String;

    final harvested = File(path('texts/$digest.txt')).readAsBytesSync();
    expect(await sha256Of(path('texts/$digest.txt')), digest);
    expect(harvested, utf8.encode(licenseText));
    expect(alpha['licenseTextFile'], '$digest.txt');
    expect(alpha['harvestKind'], 'pub-artifact-license-file');
  });

  test('already reviewed components are carried forward, not re-harvested', () async {
    writePubCache(licenseText: 'MIT sample\n');
    writeSbom();
    writeEvidence(<String, Object?>{
      'pkg:pub/alpha@1.0.0': <String, Object?>{
        'spdxId': 'MIT',
        'sourceUrl': 'https://example.invalid/alpha/LICENSE',
        'sha256': 'a' * 64,
        'reviewedBy': 'Independent Reviewer',
        'reviewedAt': '2026-07-18',
      },
    });

    final result = await runHarvester();
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final proposal = readProposal();
    final summary = proposal['summary']! as Map<String, Object?>;
    expect(summary['alreadyReviewed'], 1);

    final candidates = proposal['candidates']! as Map<String, Object?>;
    final alpha = candidates['pkg:pub/alpha@1.0.0']! as Map<String, Object?>;
    expect(alpha['status'], 'ALREADY_REVIEWED');
    expect(alpha.containsKey('sha256'), isFalse);
  });

  test('unresolved components are reported, never invented', () async {
    writePubCache(licenseText: 'MIT sample\n');
    writeSbom();
    writeEvidence(<String, Object?>{});

    final result = await runHarvester();
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final candidates = readProposal()['candidates']! as Map<String, Object?>;
    final beta = candidates['pkg:pub/beta@2.0.0']! as Map<String, Object?>;
    expect(beta['status'], 'UNRESOLVED');
    expect(beta.containsKey('sha256'), isFalse);
    expect(beta['registryReference'], contains('pub.dev/packages/beta'));
  });

  test('--require-complete fails closed while components stay unresolved', () async {
    writePubCache(licenseText: 'MIT sample\n');
    writeSbom();
    writeEvidence(<String, Object?>{});

    final result = await runHarvester(requireComplete: true);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('LICENSE_HARVEST_FAIL'));
  });

  test('re-writing shared licence bytes stays byte-exact', () async {
    // Two components with identical CRLF licence text hash to one file, so the
    // second component takes the "already on disk" comparison branch. Text-mode
    // I/O there translates CRLF and reports a false hash collision.
    const licenseText = 'Shared\r\nlicence\r\ntext\r\n';
    writePubCache(
      licenseText: licenseText,
      packages: <String>['alpha-1.0.0', 'gamma-3.0.0'],
    );
    writeSbom(second: 'gamma', secondVersion: '3.0.0');
    writeEvidence(<String, Object?>{});

    final result = await runHarvester();
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final candidates = readProposal()['candidates']! as Map<String, Object?>;
    final alpha = candidates['pkg:pub/alpha@1.0.0']! as Map<String, Object?>;
    final gamma = candidates['pkg:pub/gamma@3.0.0']! as Map<String, Object?>;
    expect(gamma['sha256'], alpha['sha256']);

    final digest = alpha['sha256']! as String;
    expect(
      File(path('texts/$digest.txt')).readAsBytesSync(),
      utf8.encode(licenseText),
    );
  });

  test('skips a licence file larger than the size cap (DoS guard)', () async {
    // A malicious/typosquatted cached artifact could ship a giant LICENSE to
    // exhaust memory. With a 16-byte cap the oversized text must be skipped and
    // reported UNRESOLVED, never read into a hash.
    writePubCache(licenseText: 'this text is well over sixteen bytes long\n');
    writeSbom();
    writeEvidence(<String, Object?>{});

    final result = await runHarvester(
      environment: <String, String>{'KORUBENI_MAX_LICENSE_BYTES': '16'},
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final candidates = readProposal()['candidates']! as Map<String, Object?>;
    final alpha = candidates['pkg:pub/alpha@1.0.0']! as Map<String, Object?>;
    expect(alpha['status'], 'UNRESOLVED');
    expect(alpha.containsKey('sha256'), isFalse);
    expect(Directory(path('texts')).listSync(), isEmpty);
  });

  test('rejects a non-CycloneDX inventory', () async {
    writePubCache(licenseText: 'MIT sample\n');
    writeSbom(bomFormat: 'SPDX');
    writeEvidence(<String, Object?>{});

    final result = await runHarvester();

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('SBOM is not CycloneDX'));
  });
}
