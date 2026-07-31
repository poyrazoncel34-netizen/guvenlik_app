import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  const licenseText = 'MIT sample license text\n';
  const licenseHash =
      'c8223ed24a2cd8e90627895c45fbe029a25c489915927ad92173043db1535fd7';

  setUp(() {
    temp = Directory.systemTemp.createTempSync('korubeni-notices-');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  Future<ProcessResult> runGenerator() => Process.run('python3', <String>[
    'scripts/generate_third_party_notices.py',
    '--sbom',
    '${temp.path}/sbom.json',
    '--evidence',
    '${temp.path}/evidence.json',
    '--license-text-dir',
    '${temp.path}/texts',
    '--output',
    '${temp.path}/THIRD_PARTY_NOTICES.txt',
  ]);

  void writeFixture({required bool complete, bool corruptText = false}) {
    Directory('${temp.path}/texts').createSync();
    File(
      '${temp.path}/texts/$licenseHash.txt',
    ).writeAsStringSync(corruptText ? 'different bytes\n' : licenseText);
    File('${temp.path}/sbom.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'bomFormat': 'CycloneDX',
        'components': <Object?>[
          <String, Object?>{
            'name': 'alpha',
            'version': '1.0.0',
            'purl': 'pkg:pub/alpha@1.0.0',
          },
        ],
      }),
    );
    File('${temp.path}/evidence.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'entries': complete
            ? <String, Object?>{
                'pkg:pub/alpha@1.0.0': <String, Object?>{
                  'spdxId': 'MIT',
                  'sourceUrl': 'https://example.invalid/alpha/LICENSE',
                  'sha256': licenseHash,
                  'reviewedBy': 'Independent Reviewer',
                  'reviewedAt': '2026-07-18',
                },
              }
            : <String, Object?>{},
      }),
    );
  }

  test(
    'fails closed when one SBOM component lacks reviewed evidence',
    () async {
      writeFixture(complete: false);

      final result = await runGenerator();

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('1 SBOM components lack'));
    },
  );

  test('fails when local reviewed bytes do not match evidence hash', () async {
    writeFixture(complete: true, corruptText: true);

    final result = await runGenerator();

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('hash mismatch'));
  });

  test('generates deterministic candidate-bound notices', () async {
    writeFixture(complete: true);

    final first = await runGenerator();
    final output = File('${temp.path}/THIRD_PARTY_NOTICES.txt');
    final firstBytes = output.readAsBytesSync();
    final second = await runGenerator();

    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
    expect(output.readAsBytesSync(), firstBytes);
    final notices = utf8.decode(firstBytes);
    expect(notices, contains('Components: 1'));
    expect(notices, contains('pkg:pub/alpha@1.0.0'));
    expect(notices, contains('SPDX decision: MIT'));
    expect(notices, contains(licenseText.trim()));
  });

  test('tracked asset is the candidate-bound generated notice document', () {
    final notices = File(
      'assets/legal/THIRD_PARTY_NOTICES.txt',
    ).readAsStringSync();

    // Until the dependency review completed this asset was a placeholder that
    // kept the tagged release closed. It is now the generated document, so the
    // invariant flips: the placeholder must be gone and the candidate binding
    // (SBOM hash + per-notice SPDX decision and reviewed-bytes hash) present.
    // Byte-for-byte parity with a fresh generator run is enforced separately by
    // scripts/verify_release.sh and .github/workflows/release.yml.
    expect(notices, isNot(contains('NOT A PRODUCTION CANDIDATE')));
    expect(notices, startsWith('KoruBeni THIRD-PARTY SOFTWARE NOTICES'));
    expect(
      notices,
      contains('generated only from accountable human-reviewed licence bytes'),
    );
    expect(notices, matches(RegExp(r'Candidate SBOM SHA-256: [0-9a-f]{64}')));
    expect(notices, matches(RegExp(r'\nComponents: [1-9]\d*\n')));
    expect(notices, contains('SPDX decision: '));
    expect(notices, matches(RegExp(r'Reviewed bytes SHA-256: [0-9a-f]{64}')));
  });
}
