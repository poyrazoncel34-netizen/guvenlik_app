import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _controlIds = <String>{
  'MASVS-STORAGE-1',
  'MASVS-STORAGE-2',
  'MASVS-CRYPTO-1',
  'MASVS-CRYPTO-2',
  'MASVS-AUTH-1',
  'MASVS-AUTH-2',
  'MASVS-AUTH-3',
  'MASVS-NETWORK-1',
  'MASVS-NETWORK-2',
  'MASVS-PLATFORM-1',
  'MASVS-PLATFORM-2',
  'MASVS-PLATFORM-3',
  'MASVS-CODE-1',
  'MASVS-CODE-2',
  'MASVS-CODE-3',
  'MASVS-CODE-4',
  'MASVS-RESILIENCE-1',
  'MASVS-RESILIENCE-2',
  'MASVS-RESILIENCE-3',
  'MASVS-RESILIENCE-4',
  'MASVS-PRIVACY-1',
  'MASVS-PRIVACY-2',
  'MASVS-PRIVACY-3',
  'MASVS-PRIVACY-4',
};

void main() {
  test('MASVS assessment template is complete and fail-closed', () {
    final payload =
        jsonDecode(
              File(
                'release-evidence/masvs-assessment.template.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final controls = (payload['controls'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(payload['schemaVersion'], 1);
    expect(controls.map((entry) => entry['id']).toSet(), _controlIds);
    expect(controls.every((entry) => entry['status'] == 'UNVERIFIED'), isTrue);
    expect(controls.every((entry) => (entry['evidence'] as List).isEmpty), isTrue);
  });

  test('MASVS verifier binds all controls and evidence to one AAB', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-masvs-pass-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final aab = File('${directory.path}/candidate.aab')
      ..writeAsStringSync('immutable production candidate');
    final witness = File('${directory.path}/witness.txt')
      ..writeAsStringSync('redacted candidate-bound security evidence');
    final assessment = File('${directory.path}/masvs-assessment.json');
    assessment.writeAsStringSync(
      jsonEncode(
        _assessment(
          aabSha256: _sha256(aab),
          evidenceSha256: _sha256(witness),
        ),
      ),
    );

    final result = await _verify(assessment, aab);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('MASVS_ASSESSMENT_PASS'));
    expect(result.stdout, contains('controls=24'));
  });

  test('MASVS verifier fails on unverified control and AAB drift', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-masvs-fail-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final aab = File('${directory.path}/candidate.aab')
      ..writeAsStringSync('immutable production candidate');
    final witness = File('${directory.path}/witness.txt')
      ..writeAsStringSync('redacted candidate-bound security evidence');
    final payload = _assessment(
      aabSha256: 'f' * 64,
      evidenceSha256: _sha256(witness),
    );
    (payload['controls'] as List<dynamic>).first['status'] = 'UNVERIFIED';
    final assessment = File('${directory.path}/masvs-assessment.json')
      ..writeAsStringSync(jsonEncode(payload));

    final result = await _verify(assessment, aab);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('candidate AAB SHA-256 mismatch'));
    expect(result.stderr, contains('MASVS-STORAGE-1 is not PASS'));
  });

  test('MASVS verifier rejects an unedited framework revision placeholder', () async {
    final directory = await Directory.systemTemp.createTemp(
      'korubeni-masvs-placeholder-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final aab = File('${directory.path}/candidate.aab')
      ..writeAsStringSync('immutable production candidate');
    final witness = File('${directory.path}/witness.txt')
      ..writeAsStringSync('redacted candidate-bound security evidence');
    final payload = _assessment(
      aabSha256: _sha256(aab),
      evidenceSha256: _sha256(witness),
    );
    (payload['framework'] as Map<String, dynamic>)['referenceRevision'] =
        'REPLACE_WITH_CHECKLIST_VERSION_OR_COMMIT';
    final assessment = File('${directory.path}/masvs-assessment.json')
      ..writeAsStringSync(jsonEncode(payload));

    final result = await _verify(assessment, aab);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('framework referenceRevision is required'));
  });

  test('release runbooks expose the fail-closed operator workflow', () {
    final masvsRunbook = File(
      'docs/release/masvs_assessment.md',
    ).readAsStringSync();
    final licenseRunbook = File(
      'docs/release/dependency_license_review.md',
    ).readAsStringSync();
    final evidenceReadme = File('release-evidence/README.md').readAsStringSync();

    expect(masvsRunbook, contains('verify_masvs_assessment.py'));
    expect(masvsRunbook, contains('sertifika değildir'));
    expect(masvsRunbook, contains('candidateBound'));
    expect(
      licenseRunbook,
      contains('prepare_license_review_assignments.py'),
    );
    expect(licenseRunbook, contains('dört gerçek ve hesap verebilir'));
    expect(evidenceReadme, contains('kind: masvsAssessment'));
    expect(evidenceReadme, contains('masvs-assessment.template.json'));
  });
}

Map<String, dynamic> _assessment({
  required String aabSha256,
  required String evidenceSha256,
}) => <String, dynamic>{
  'schemaVersion': 1,
  'framework': <String, dynamic>{
    'name': 'OWASP MASVS',
    'sourceUrl': 'https://mas.owasp.org/MASVS/',
    'referenceRevision': '2026-07-19',
  },
  'candidate': <String, dynamic>{
    'packageName': 'com.poyrazoncel.korubeni',
    'versionName': '1.0.3',
    'versionCode': 10003,
    'aabSha256': aabSha256,
  },
  'review': <String, dynamic>{
    'reviewedBy': 'independent-security-reviewer',
    'reviewedAt': '2026-07-19T12:00:00Z',
  },
  'controls': <Map<String, dynamic>>[
    for (final controlId in _controlIds)
      <String, dynamic>{
        'id': controlId,
        'status': 'PASS',
        'rationale': 'Candidate-bound verification completed.',
        'evidence': <Map<String, dynamic>>[
          <String, dynamic>{
            'path': 'witness.txt',
            'sha256': evidenceSha256,
            'candidateBound': true,
          },
        ],
      },
  ],
};

Future<ProcessResult> _verify(File assessment, File aab) =>
    Process.run('python3', <String>[
      'scripts/verify_masvs_assessment.py',
      '--assessment',
      assessment.path,
      '--aab',
      aab.path,
      '--expected-package',
      'com.poyrazoncel.korubeni',
      '--expected-version-name',
      '1.0.3',
      '--expected-version-code',
      '10003',
    ]);

String _sha256(File file) {
  final result = Process.runSync('shasum', <String>['-a', '256', file.path]);
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
  return result.stdout.toString().split(RegExp(r'\s+')).first;
}
