import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _commitA = '1111111111111111111111111111111111111111';
const _commitB = '2222222222222222222222222222222222222222';
const _tree = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _appHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _testHash =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Map<String, Object?> _evidence({
  required int apiLevel,
  required int pageSizeBytes,
  String commit = _commitA,
  bool restored = true,
  int? exactRevocationTestsPassed,
}) {
  final exactRevocationExpected = apiLevel >= 31;
  return <String, Object?>{
    'schemaVersion': 1,
    'evidenceType': 'android_direct_boot_reboot_probe',
    'status': 'PASS_EMULATOR_ONLY',
    'candidateBound': false,
    'source': <String, Object?>{
      'gitCommit': commit,
      'gitTree': _tree,
      'clean': true,
    },
    'build': <String, Object?>{
      'variant': 'playDebug',
      'appApkSha256': _appHash,
      'testApkSha256': _testHash,
    },
    'device': <String, Object?>{
      'serial': 'emulator-5554',
      'avdName': 'fixture-api$apiLevel-$pageSizeBytes',
      'apiLevel': apiLevel,
      'androidRelease': '$apiLevel',
      'abi': 'arm64-v8a',
      'manufacturer': 'Google',
      'model': 'sdk_gphone64_arm64',
      'buildFingerprint': 'fixture/api$apiLevel/release-keys',
      'pageSizeBytes': pageSizeBytes,
      'isEmulator': true,
    },
    'execution': <String, Object?>{
      'startedAtUtc': '2026-07-20T09:00:00Z',
      'finishedAtUtc': '2026-07-20T09:03:00Z',
      'armInstrumentationTestsPassed': 1,
      'verifyInstrumentationTestsPassed': 1,
      'realReboot': true,
      'bootCompletedObserved': true,
      'typedSessionRestored': restored,
      'exactPermissionRevocationRebootTested': exactRevocationExpected,
      'exactPermissionRevocationInstrumentationTestsPassed':
          exactRevocationTestsPassed ?? (exactRevocationExpected ? 3 : 0),
      'packagesRemoved': true,
    },
    'limitations': <String>[
      'NOT_PHYSICAL_DEVICE_EVIDENCE',
      'NOT_PRODUCTION_AAB_EVIDENCE',
      'NOT_TELEPHONY_CONNECTION_EVIDENCE',
      'NOT_OEM_BATTERY_POLICY_EVIDENCE',
      if (pageSizeBytes == 16384)
        'EMULATOR_16KB_KERNEL_ONLY'
      else
        'NOT_16KB_KERNEL_EVIDENCE',
    ],
  };
}

Future<File> _writeEvidence(
  Directory directory,
  String name,
  Map<String, Object?> payload,
) async {
  final file = File('${directory.path}/$name.json');
  await file.writeAsString('${jsonEncode(payload)}\n', flush: true);
  return file;
}

Future<ProcessResult> _runVerifier({
  required File output,
  required List<File> evidence,
}) {
  return Process.run('python3', <String>[
    'scripts/verify_phase3_emulator_matrix.py',
    '--output',
    output.path,
    '--expected-git-commit',
    _commitA,
    '--expected-git-tree',
    _tree,
    for (final item in evidence) ...<String>['--evidence', item.path],
  ]);
}

void main() {
  test('accepts only the complete API29/34/36 plus 16 KB matrix', () async {
    final temp = await Directory.systemTemp.createTemp('phase3-matrix-pass-');
    addTearDown(() => temp.delete(recursive: true));
    final inputs = <File>[
      await _writeEvidence(
        temp,
        'api29',
        _evidence(apiLevel: 29, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api34',
        _evidence(apiLevel: 34, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36',
        _evidence(apiLevel: 36, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36-16kb',
        _evidence(apiLevel: 36, pageSizeBytes: 16384),
      ),
    ];
    final output = File('${temp.path}/matrix.json');

    final result = await _runVerifier(output: output, evidence: inputs);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('PHASE3_EMULATOR_MATRIX_PASS'));
    final payload = jsonDecode(await output.readAsString()) as Map;
    expect(payload['status'], 'PASS_EMULATOR_MATRIX_ONLY');
    expect(payload['candidateBound'], isFalse);
    expect((payload['source'] as Map)['gitCommit'], _commitA);
    expect((payload['build'] as Map)['appApkSha256'], _appHash);
    expect((payload['coverage'] as Map)['profiles'], <String>[
      'api29-4kb',
      'api34-4kb',
      'api36-4kb',
      'api36-16kb',
    ]);
    expect((payload['inputs'] as List), hasLength(4));
    expect(
      (payload['coverage']
          as Map)['exactPermissionRevocationRebootTestedOnApi31Plus'],
      isTrue,
    );
  });

  test('missing 16 KB proof fails closed and deletes stale PASS', () async {
    final temp = await Directory.systemTemp.createTemp(
      'phase3-matrix-missing-',
    );
    addTearDown(() => temp.delete(recursive: true));
    final inputs = <File>[
      await _writeEvidence(
        temp,
        'api29',
        _evidence(apiLevel: 29, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api34',
        _evidence(apiLevel: 34, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36',
        _evidence(apiLevel: 36, pageSizeBytes: 4096),
      ),
    ];
    final output = File('${temp.path}/matrix.json');
    await output.writeAsString('{"status":"STALE_PASS"}\n');

    final result = await _runVerifier(output: output, evidence: inputs);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('missing required profiles'));
    expect(output.existsSync(), isFalse);
  });

  test('mixed source commits cannot be aggregated', () async {
    final temp = await Directory.systemTemp.createTemp('phase3-matrix-source-');
    addTearDown(() => temp.delete(recursive: true));
    final inputs = <File>[
      await _writeEvidence(
        temp,
        'api29',
        _evidence(apiLevel: 29, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api34',
        _evidence(apiLevel: 34, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36',
        _evidence(apiLevel: 36, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36-16kb',
        _evidence(apiLevel: 36, pageSizeBytes: 16384, commit: _commitB),
      ),
    ];

    final result = await _runVerifier(
      output: File('${temp.path}/matrix.json'),
      evidence: inputs,
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('git commit mismatch'));
  });

  test('forged execution flags cannot produce matrix PASS', () async {
    final temp = await Directory.systemTemp.createTemp('phase3-matrix-forged-');
    addTearDown(() => temp.delete(recursive: true));
    final inputs = <File>[
      await _writeEvidence(
        temp,
        'api29',
        _evidence(apiLevel: 29, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api34',
        _evidence(apiLevel: 34, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36',
        _evidence(apiLevel: 36, pageSizeBytes: 4096, restored: false),
      ),
      await _writeEvidence(
        temp,
        'api36-16kb',
        _evidence(apiLevel: 36, pageSizeBytes: 16384),
      ),
    ];

    final result = await _runVerifier(
      output: File('${temp.path}/matrix.json'),
      evidence: inputs,
    );

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('typedSessionRestored must be true'));
  });

  test('missing API31+ exact-revocation proof fails closed', () async {
    final temp = await Directory.systemTemp.createTemp('phase3-matrix-exact-');
    addTearDown(() => temp.delete(recursive: true));
    final inputs = <File>[
      await _writeEvidence(
        temp,
        'api29',
        _evidence(apiLevel: 29, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api34',
        _evidence(
          apiLevel: 34,
          pageSizeBytes: 4096,
          exactRevocationTestsPassed: 0,
        ),
      ),
      await _writeEvidence(
        temp,
        'api36',
        _evidence(apiLevel: 36, pageSizeBytes: 4096),
      ),
      await _writeEvidence(
        temp,
        'api36-16kb',
        _evidence(apiLevel: 36, pageSizeBytes: 16384),
      ),
    ];

    final result = await _runVerifier(
      output: File('${temp.path}/matrix.json'),
      evidence: inputs,
    );

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains('exactPermissionRevocationInstrumentationTestsPassed'),
    );
  });
}
