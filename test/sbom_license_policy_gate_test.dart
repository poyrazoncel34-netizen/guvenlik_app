import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _sbom({
  String status = 'VERIFIED',
  String license = 'MIT',
}) => <String, Object?>{
  'metadata': <String, Object?>{
    'properties': <Object?>[
      <String, Object?>{
        'name': 'korubeni:licenseEvidenceStatus',
        'value': status,
      },
    ],
  },
  'components': <Object?>[
    <String, Object?>{
      'purl': 'pkg:pub/example@1.0.0',
      'licenses': <Object?>[
        <String, Object?>{
          'license': <String, Object?>{'id': license},
        },
      ],
      'properties': <Object?>[
        <String, Object?>{
          'name': 'korubeni:licenseEvidenceUrl',
          'value': 'https://example.invalid/LICENSE',
        },
        <String, Object?>{
          'name': 'korubeni:licenseEvidenceSha256',
          'value': 'a' * 64,
        },
        <String, Object?>{
          'name': 'korubeni:licenseReviewedBy',
          'value': 'independent-reviewer',
        },
        <String, Object?>{
          'name': 'korubeni:licenseReviewedAt',
          'value': '2026-07-18',
        },
      ],
    },
  ],
};

Map<String, Object?> _policy({List<Object?> waivers = const <Object?>[]}) =>
    <String, Object?>{
      'schemaVersion': 1,
      'allowedSpdxIds': <String>['MIT', 'Apache-2.0'],
      'blockedSpdxIds': <String>['GPL-3.0-only'],
      'waivers': waivers,
    };

Map<String, Object?> _waiver(String expiresOn) => <String, Object?>{
  'purl': 'pkg:pub/example@1.0.0',
  'spdxId': 'BSD-4-Clause',
  'expiresOn': expiresOn,
  'approvedBy': 'release-owner',
  'rationale': 'Time-bounded test waiver',
};

String _utcDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Future<ProcessResult> _verify(
  Directory directory,
  Map<String, Object?> sbom,
  Map<String, Object?> policy,
) async {
  final sbomFile = File('${directory.path}/sbom.json')
    ..writeAsStringSync(jsonEncode(sbom));
  final policyFile = File('${directory.path}/policy.json')
    ..writeAsStringSync(jsonEncode(policy));
  return Process.run('dart', <String>[
    'scripts/verify_sbom_license_policy.dart',
    '--sbom',
    sbomFile.path,
    '--policy',
    policyFile.path,
  ]);
}

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('korubeni-license-policy-');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test('passes reviewed evidence for an allowed SPDX license', () async {
    final result = await _verify(directory, _sbom(), _policy());

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('LICENSE_POLICY_PASS: 1 components'));
  });

  test('fails closed while SBOM evidence is unverified', () async {
    final result = await _verify(
      directory,
      _sbom(status: 'UNVERIFIED'),
      _policy(),
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('license evidence status is UNVERIFIED'));
  });

  test('blocks forbidden licenses even when evidence exists', () async {
    final result = await _verify(
      directory,
      _sbom(license: 'GPL-3.0-only'),
      _policy(),
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('blocked license GPL-3.0-only'));
  });

  test(
    'accepts a non-allowlisted license only with a current waiver',
    () async {
      final today = DateTime.now().toUtc();
      final result = await _verify(
        directory,
        _sbom(license: 'BSD-4-Clause'),
        _policy(waivers: <Object?>[_waiver(_utcDate(today))]),
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test('expires a waiver before the current UTC calendar date', () async {
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final result = await _verify(
      directory,
      _sbom(license: 'BSD-4-Clause'),
      _policy(waivers: <Object?>[_waiver(_utcDate(yesterday))]),
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('has no valid waiver'));
  });
}
