import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _emptySha256 =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

const _requiredEvidenceKinds = <String, Set<String>>{
  'G0': {'safetyCaseReview'},
  'G1': {'nativeKernelReport', 'mutationReport'},
  'G2': {'flutterSessionReport'},
  'G3': {'androidPlatformMatrix'},
  'G4': {'masvsAssessment', 'licensePolicyReport', 'privacyCounselDecision'},
  'G5': {'qualityMatrix'},
  'G6': {'artifactChainReport'},
  'G7': {'physicalDeviceMatrix'},
  'G8': {'billingPlayMatrix', 'playPolicyDisposition'},
  'G9': {'closedSoakReport'},
  'G10': {'hotfixDrillReport', 'releaseBoardDecision'},
};

const _requiredGateOwners = <String, Set<String>>{
  'G0': {'product', 'safety'},
  'G1': {'android_safety'},
  'G2': {'flutter_safety'},
  'G3': {'android_platform'},
  'G4': {'security', 'privacy_legal'},
  'G5': {'qa'},
  'G6': {'release'},
  'G7': {'qa', 'independent_witness'},
  'G8': {'billing_play'},
  'G9': {'release_owner'},
  'G10': {'release_board'},
};

const _approvalRoles = <String>{
  'product',
  'safety',
  'qa',
  'security',
  'privacy_legal',
  'billing_play',
  'release',
};

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
    for (final gate in gates) {
      expect(
        (gate['requiredEvidenceKinds'] as List<dynamic>).toSet(),
        _requiredEvidenceKinds[gate['id']],
      );
    }
    final evidenceTemplate =
        jsonDecode(
              File(
                'release-evidence/gate-evidence.template.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(evidenceTemplate['status'], 'UNVERIFIED');
    expect(evidenceTemplate['artifacts'], isEmpty);
    expect(evidenceTemplate['metrics'], isEmpty);
    expect(
      (evidenceTemplate['review']
          as Map<String, dynamic>)['independentFromImplementation'],
      isFalse,
    );
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
        'osvAudit',
        'thirdPartyNotices',
      ])
        name: File('${directory.path}/$name.txt')
          ..writeAsStringSync('evidence:$name'),
    };
    artifacts['mutationReport']!.writeAsStringSync(
      jsonEncode(_rawMutationReport(commit: 'b' * 40)),
    );
    artifacts['criticalCoverage']!.writeAsStringSync(
      jsonEncode(_rawCriticalCoverage()),
    );
    artifacts['androidReleaseSurface']!.writeAsStringSync(
      jsonEncode(_rawAndroidReleaseSurface()),
    );
    artifacts['sbom']!.writeAsStringSync(jsonEncode(_rawVerifiedSbom()));
    artifacts['secretScan']!.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'status': 'PASS',
        'scannedAt': '2026-07-14T10:00:00Z',
        'mode': 'tracked-candidate',
        'source': <String, Object?>{
          'gitCommit': 'b' * 40,
          'gitTree': 'c' * 40,
          'sourceWasDirty': false,
          'sourceStatusSha256': _emptySha256,
        },
        'scanner': <String, Object?>{
          'name': 'scan_release_secrets.py',
          'sha256': '1' * 64,
        },
        'pathSetSha256': '2' * 64,
        'contentSetSha256': '3' * 64,
        'inputPathCount': 10,
        'scannedTextFileCount': 8,
        'skippedBinaryFileCount': 2,
        'rules': <String>['private-key'],
        'findingCount': 0,
      }),
    );
    artifacts['osvAudit']!.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'status': 'PASS',
        'scannedAt': '2026-07-14T10:05:00Z',
        'endpoint': 'https://api.osv.dev/v1/querybatch',
        'interpretation': 'noKnownFindingsAtScanTime',
        'source': <String, Object?>{
          'gitCommit': 'b' * 40,
          'gitTree': 'c' * 40,
          'sourceWasDirty': false,
          'sourceStatusSha256': _emptySha256,
        },
        'inputs': <String, Object?>{
          'pubspecLockSha256': _sha256(artifacts['dependencyLockPub']!),
          'gradleLockSha256': _sha256(artifacts['dependencyLockGradle']!),
          'runnerSha256': '4' * 64,
          'generatorSha256': '5' * 64,
        },
        'ecosystems': <String, Object?>{
          'Pub': <String, Object?>{
            'queryCount': 1,
            'querySha256': '6' * 64,
            'responseSha256': '7' * 64,
            'findingCount': 0,
          },
          'Maven': <String, Object?>{
            'queryCount': 1,
            'querySha256': '8' * 64,
            'responseSha256': '9' * 64,
            'findingCount': 0,
          },
        },
        'findingCount': 0,
        'findings': <Object?>[],
      }),
    );
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
    final masvsAssessment = File('${directory.path}/masvs-assessment.json')
      ..writeAsStringSync(
        jsonEncode(
          _masvsAssessment(aabHash: aabHash, witnessHash: witnessHash),
        ),
      );
    final masvsHash = _sha256(masvsAssessment);
    final typedEvidence = <String, List<Map<String, dynamic>>>{};
    for (final gateEntry in _requiredEvidenceKinds.entries) {
      final items = <Map<String, dynamic>>[];
      for (final kind in gateEntry.value) {
        if (kind == 'masvsAssessment') {
          items.add(<String, dynamic>{
            'kind': kind,
            'path': 'masvs-assessment.json',
            'sha256': masvsHash,
            'candidateBound': true,
          });
          continue;
        }
        final rawArtifact = File('${directory.path}/$kind.raw.json')
          ..writeAsStringSync(
            jsonEncode(<String, Object?>{
              'candidateAabSha256': aabHash,
              'kind': kind,
              'result': 'PASS',
            }),
          );
        final evidenceFile = File('${directory.path}/$kind.json')
          ..writeAsStringSync(
            jsonEncode(
              _gateEvidence(
                gateId: gateEntry.key,
                kind: kind,
                aabHash: aabHash,
                artifactPath: '$kind.raw.json',
                artifactSha256: _sha256(rawArtifact),
              ),
            ),
          );
        items.add(<String, dynamic>{
          'kind': kind,
          'path': '$kind.json',
          'sha256': _sha256(evidenceFile),
          'candidateBound': true,
        });
      }
      typedEvidence[gateEntry.key] = items;
    }
    final approvalEvidence = <String, File>{
      for (final role in _approvalRoles)
        role: File('${directory.path}/approval-$role.json')
          ..writeAsStringSync(
            jsonEncode(<String, Object?>{
              'role': role,
              'decision': 'APPROVE',
              'signer': '$role-reviewer',
              'signedAt': '2026-07-18T12:00:00Z',
              'candidateAabSha256': aabHash,
              'versionCode': 10003,
            }),
          ),
    };
    final manifest = File('${directory.path}/gates.json');
    Map<String, dynamic> completeManifest({
      bool typed = false,
      bool approvalsBound = true,
    }) => <String, dynamic>{
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
            'owners': _requiredGateOwners['G$index']!.toList(),
            'requiredEvidenceKinds': _requiredEvidenceKinds['G$index']!
                .toList(),
            'evidence': typed
                ? typedEvidence['G$index']!
                : index == 4
                ? <Map<String, dynamic>>[
                    <String, dynamic>{
                      'kind': 'masvsAssessment',
                      'path': 'masvs-assessment.json',
                      'sha256': masvsHash,
                      'candidateBound': true,
                    },
                  ]
                : <Map<String, dynamic>>[
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
      'hotfixDrill': <String, dynamic>{
        'status': 'PASS',
        'durationMinutes': 90,
        'reservedVersionCode': 10004,
        'aabSha256': aabHash,
      },
      'approvals': <Map<String, dynamic>>[
        for (final role in _approvalRoles)
          <String, dynamic>{
            'role': role,
            'decision': 'APPROVE',
            'signer': '$role-reviewer',
            'signedAt': '2026-07-18T12:00:00Z',
            'candidateAabSha256': aabHash,
            'versionCode': 10003,
            if (approvalsBound) ...<String, dynamic>{
              'evidencePath': 'approval-$role.json',
              'evidenceSha256': _sha256(approvalEvidence[role]!),
              'evidenceCandidateBound': true,
            },
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
    expect(passed.exitCode, 1);
    expect(passed.stderr, contains('G0 evidence kind set mismatch'));

    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final typedPassed = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(
      typedPassed.exitCode,
      0,
      reason: '${typedPassed.stdout}\n${typedPassed.stderr}',
    );
    expect(typedPassed.stdout, contains('MASTER_GO_NO_GO_PASS'));

    final secretScanFile = artifacts['secretScan']!;
    final secretScanOriginal = secretScanFile.readAsStringSync();
    final replayedSecretScan =
        jsonDecode(secretScanOriginal) as Map<String, dynamic>;
    (replayedSecretScan['source'] as Map<String, dynamic>)['gitCommit'] =
        'f' * 40;
    secretScanFile.writeAsStringSync(jsonEncode(replayedSecretScan));
    final replayedSecretProvenance = await Process.run(
      'python3',
      generatorArguments,
    );
    expect(replayedSecretProvenance.exitCode, 0);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final replayedSecretResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(replayedSecretResult.exitCode, 1);
    expect(
      replayedSecretResult.stderr,
      contains('secretScan gitCommit mismatch'),
    );
    secretScanFile.writeAsStringSync(secretScanOriginal);

    final osvAuditFile = artifacts['osvAudit']!;
    final osvAuditOriginal = osvAuditFile.readAsStringSync();
    final forgedOsvAudit = jsonDecode(osvAuditOriginal) as Map<String, dynamic>;
    (forgedOsvAudit['inputs'] as Map<String, dynamic>)['pubspecLockSha256'] =
        '0' * 64;
    osvAuditFile.writeAsStringSync(jsonEncode(forgedOsvAudit));
    final forgedOsvProvenance = await Process.run(
      'python3',
      generatorArguments,
    );
    expect(forgedOsvProvenance.exitCode, 0);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final forgedOsvResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(forgedOsvResult.exitCode, 1);
    expect(
      forgedOsvResult.stderr,
      contains('osvAudit pubspec lock hash mismatch'),
    );
    osvAuditFile.writeAsStringSync(osvAuditOriginal);

    final restoredProvenance = await Process.run('python3', generatorArguments);
    expect(restoredProvenance.exitCode, 0);

    final rawMutationFile = artifacts['mutationReport']!;
    final rawMutationOriginal = rawMutationFile.readAsStringSync();
    final replayedMutation =
        jsonDecode(rawMutationOriginal) as Map<String, dynamic>;
    replayedMutation['sourceHead'] = 'f' * 40;
    rawMutationFile.writeAsStringSync(jsonEncode(replayedMutation));
    expect((await Process.run('python3', generatorArguments)).exitCode, 0);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final replayedMutationResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(replayedMutationResult.exitCode, 1);
    expect(
      replayedMutationResult.stderr,
      contains('mutationReport sourceHead mismatch'),
    );
    rawMutationFile.writeAsStringSync(rawMutationOriginal);

    final rawCoverageFile = artifacts['criticalCoverage']!;
    final rawCoverageOriginal = rawCoverageFile.readAsStringSync();
    final forgedCoverage =
        jsonDecode(rawCoverageOriginal) as Map<String, dynamic>;
    final forgedCoverageRecord =
        (forgedCoverage['files'] as List<dynamic>).first
            as Map<String, dynamic>;
    forgedCoverageRecord['linesHit'] = 89;
    forgedCoverageRecord['linesFound'] = 100;
    forgedCoverageRecord['lineCoveragePercent'] = 89.0;
    rawCoverageFile.writeAsStringSync(jsonEncode(forgedCoverage));
    expect((await Process.run('python3', generatorArguments)).exitCode, 0);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final forgedCoverageResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(forgedCoverageResult.exitCode, 1);
    expect(
      forgedCoverageResult.stderr,
      contains('criticalCoverage file is below 90%'),
    );
    rawCoverageFile.writeAsStringSync(rawCoverageOriginal);

    final surfaceFile = artifacts['androidReleaseSurface']!;
    final surfaceOriginal = surfaceFile.readAsStringSync();
    final forgedSurface = jsonDecode(surfaceOriginal) as Map<String, dynamic>;
    (forgedSurface['components'] as List<dynamic>).removeLast();
    forgedSurface['componentCount'] =
        (forgedSurface['components'] as List<dynamic>).length;
    surfaceFile.writeAsStringSync(jsonEncode(forgedSurface));
    expect((await Process.run('python3', generatorArguments)).exitCode, 0);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final forgedSurfaceResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(forgedSurfaceResult.exitCode, 1);
    expect(
      forgedSurfaceResult.stderr,
      contains('androidReleaseSurface safety component set mismatch'),
    );
    surfaceFile.writeAsStringSync(surfaceOriginal);

    final verifiedSbomFile = artifacts['sbom']!;
    final verifiedSbomOriginal = verifiedSbomFile.readAsStringSync();
    final unverifiedSbom =
        jsonDecode(verifiedSbomOriginal) as Map<String, dynamic>;
    final sbomMetadata = unverifiedSbom['metadata'] as Map<String, dynamic>;
    final sbomProperties = sbomMetadata['properties'] as List<dynamic>;
    (sbomProperties.first as Map<String, dynamic>)['value'] = 'UNVERIFIED';
    verifiedSbomFile.writeAsStringSync(jsonEncode(unverifiedSbom));
    expect((await Process.run('python3', generatorArguments)).exitCode, 0);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final unverifiedSbomResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(unverifiedSbomResult.exitCode, 1);
    expect(
      unverifiedSbomResult.stderr,
      contains('sbom license evidence status is not VERIFIED'),
    );
    verifiedSbomFile.writeAsStringSync(verifiedSbomOriginal);

    expect((await Process.run('python3', generatorArguments)).exitCode, 0);

    final sbomFile = artifacts['sbom']!;
    final sbomOriginal = sbomFile.readAsStringSync();
    sbomFile.writeAsStringSync('$sbomOriginal\ntampered-after-provenance');
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final provenanceArtifactDriftResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(provenanceArtifactDriftResult.exitCode, 1);
    expect(
      provenanceArtifactDriftResult.stderr,
      contains('provenance artifact sbom hash mismatch'),
    );
    sbomFile.writeAsStringSync(sbomOriginal);

    manifest.writeAsStringSync(
      jsonEncode(completeManifest(typed: true, approvalsBound: false)),
    );
    final unboundApprovalsResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(unboundApprovalsResult.exitCode, 1);
    expect(
      unboundApprovalsResult.stderr,
      contains('approval evidencePath is required'),
    );

    final productApprovalFile = approvalEvidence['product']!;
    final productApprovalOriginal = productApprovalFile.readAsStringSync();
    final earlyApprovalPayload =
        jsonDecode(productApprovalOriginal) as Map<String, dynamic>;
    earlyApprovalPayload['signedAt'] = '2026-07-14T12:00:00Z';
    productApprovalFile.writeAsStringSync(jsonEncode(earlyApprovalPayload));
    final earlyApprovalManifest = completeManifest(typed: true);
    ((earlyApprovalManifest['approvals'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .singleWhere(
              (approval) => approval['role'] == 'product',
            ))['signedAt'] =
        '2026-07-14T12:00:00Z';
    manifest.writeAsStringSync(jsonEncode(earlyApprovalManifest));
    final earlyApprovalResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(earlyApprovalResult.exitCode, 1);
    expect(
      earlyApprovalResult.stderr,
      contains('product approval predates closed soak completion'),
    );
    productApprovalFile.writeAsStringSync(productApprovalOriginal);

    final kernelRawFile = File('${directory.path}/nativeKernelReport.raw.json');
    final kernelRawOriginal = kernelRawFile.readAsStringSync();
    kernelRawFile.writeAsStringSync('$kernelRawOriginal\ntampered');
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final rawArtifactDriftResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(rawArtifactDriftResult.exitCode, 1);
    expect(
      rawArtifactDriftResult.stderr,
      contains('artifact nativeKernelReport.raw.json hash mismatch'),
    );
    kernelRawFile.writeAsStringSync(kernelRawOriginal);

    final approvalDrift = completeManifest(typed: true);
    ((approvalDrift['approvals'] as List<dynamic>).first
            as Map<String, dynamic>)['candidateAabSha256'] =
        'f' * 64;
    manifest.writeAsStringSync(jsonEncode(approvalDrift));
    final approvalDriftResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(approvalDriftResult.exitCode, 1);
    expect(
      approvalDriftResult.stderr,
      contains('approval used a different AAB'),
    );

    final slowHotfix = completeManifest(typed: true);
    (slowHotfix['hotfixDrill'] as Map<String, dynamic>)['durationMinutes'] =
        121;
    manifest.writeAsStringSync(jsonEncode(slowHotfix));
    final slowHotfixResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(slowHotfixResult.exitCode, 1);
    expect(
      slowHotfixResult.stderr,
      contains('hotfix drill duration must be 1..120 minutes'),
    );

    final hotfixReportDrift = completeManifest(typed: true);
    (hotfixReportDrift['hotfixDrill']
            as Map<String, dynamic>)['durationMinutes'] =
        60;
    manifest.writeAsStringSync(jsonEncode(hotfixReportDrift));
    final hotfixReportDriftResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(hotfixReportDriftResult.exitCode, 1);
    expect(
      hotfixReportDriftResult.stderr,
      contains('hotfix drill duration does not match typed report'),
    );

    final soakSummaryDrift = completeManifest(typed: true);
    (soakSummaryDrift['closedSoak'] as Map<String, dynamic>)['testers'] = 13;
    manifest.writeAsStringSync(jsonEncode(soakSummaryDrift));
    final soakSummaryDriftResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(soakSummaryDriftResult.exitCode, 1);
    expect(
      soakSummaryDriftResult.stderr,
      contains('closed soak testers do not match typed report'),
    );

    final ownerDrift = completeManifest(typed: true);
    ((ownerDrift['gates'] as List<dynamic>).first
        as Map<String, dynamic>)['owners'] = <String>[
      'self-approved',
    ];
    manifest.writeAsStringSync(jsonEncode(ownerDrift));
    final ownerDriftResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(ownerDriftResult.exitCode, 1);
    expect(ownerDriftResult.stderr, contains('G0 owner set mismatch'));

    final malformedOwner = completeManifest(typed: true);
    ((malformedOwner['gates'] as List<dynamic>).first
        as Map<String, dynamic>)['owners'] = <Object?>[
      <String, Object?>{},
    ];
    manifest.writeAsStringSync(jsonEncode(malformedOwner));
    final malformedOwnerResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(malformedOwnerResult.exitCode, 1);
    expect(malformedOwnerResult.stderr, contains('G0 owner set mismatch'));
    expect(malformedOwnerResult.stderr, isNot(contains('Traceback')));

    void refreshEvidenceHash(String gateId, String kind, File file) {
      typedEvidence[gateId]!.singleWhere(
        (item) => item['kind'] == kind,
      )['sha256'] = _sha256(
        file,
      );
    }

    final mutationFile = File('${directory.path}/mutationReport.json');
    final mutationOriginal = mutationFile.readAsStringSync();
    final mutationPayload =
        jsonDecode(mutationOriginal) as Map<String, dynamic>;
    ((mutationPayload['metrics'] as Map<String, dynamic>)['cases']
            as Map<String, dynamic>)
        .remove('disposeCancelsNative');
    mutationFile.writeAsStringSync(jsonEncode(mutationPayload));
    refreshEvidenceHash('G1', 'mutationReport', mutationFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final mutationResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(mutationResult.exitCode, 1);
    expect(
      mutationResult.stderr,
      contains('mutationReport.cases key set mismatch'),
    );
    mutationFile.writeAsStringSync(mutationOriginal);
    refreshEvidenceHash('G1', 'mutationReport', mutationFile);

    final qualityFile = File('${directory.path}/qualityMatrix.json');
    final qualityOriginal = qualityFile.readAsStringSync();
    final qualityPayload = jsonDecode(qualityOriginal) as Map<String, dynamic>;
    ((((qualityPayload['metrics'] as Map<String, dynamic>)['featureChecks']
            as Map<String, dynamic>)))['panicHoldAccessibilityLifecycle'] =
        'NOT_RUN';
    qualityFile.writeAsStringSync(jsonEncode(qualityPayload));
    refreshEvidenceHash('G5', 'qualityMatrix', qualityFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final qualityResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(qualityResult.exitCode, 1);
    expect(
      qualityResult.stderr,
      contains(
        'qualityMatrix.featureChecks.panicHoldAccessibilityLifecycle is not PASS',
      ),
    );
    qualityFile.writeAsStringSync(qualityOriginal);
    refreshEvidenceHash('G5', 'qualityMatrix', qualityFile);

    final licenseFile = File('${directory.path}/licensePolicyReport.json');
    final licenseOriginal = licenseFile.readAsStringSync();
    final licensePayload = jsonDecode(licenseOriginal) as Map<String, dynamic>;
    (licensePayload['metrics'] as Map<String, dynamic>)['reviewed'] = 399;
    licenseFile.writeAsStringSync(jsonEncode(licensePayload));
    refreshEvidenceHash('G4', 'licensePolicyReport', licenseFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final licenseResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(licenseResult.exitCode, 1);
    expect(
      licenseResult.stderr,
      contains('licensePolicyReport.reviewed must equal components'),
    );
    licenseFile.writeAsStringSync(licenseOriginal);
    refreshEvidenceHash('G4', 'licensePolicyReport', licenseFile);

    final platformFile = File('${directory.path}/androidPlatformMatrix.json');
    final platformOriginal = platformFile.readAsStringSync();
    final platformPayload =
        jsonDecode(platformOriginal) as Map<String, dynamic>;
    (platformPayload['metrics'] as Map<String, dynamic>)['apiLevels'] =
        <Object?>[<String, Object?>{}];
    platformFile.writeAsStringSync(jsonEncode(platformPayload));
    refreshEvidenceHash('G3', 'androidPlatformMatrix', platformFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final platformResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(platformResult.exitCode, 1);
    expect(
      platformResult.stderr,
      contains('androidPlatformMatrix.apiLevels must cover API 29-36'),
    );
    expect(platformResult.stderr, isNot(contains('Traceback')));
    platformFile.writeAsStringSync(platformOriginal);
    refreshEvidenceHash('G3', 'androidPlatformMatrix', platformFile);

    final incompletePlatformPayload =
        jsonDecode(platformOriginal) as Map<String, dynamic>;
    ((incompletePlatformPayload['metrics']
                as Map<String, dynamic>)['emulatorResults']
            as Map<String, dynamic>)
        .remove('36');
    platformFile.writeAsStringSync(jsonEncode(incompletePlatformPayload));
    refreshEvidenceHash('G3', 'androidPlatformMatrix', platformFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final incompletePlatformResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(incompletePlatformResult.exitCode, 1);
    expect(
      incompletePlatformResult.stderr,
      contains('androidPlatformMatrix.emulatorResults key set mismatch'),
    );
    platformFile.writeAsStringSync(platformOriginal);
    refreshEvidenceHash('G3', 'androidPlatformMatrix', platformFile);

    final physicalFile = File('${directory.path}/physicalDeviceMatrix.json');
    final physicalOriginal = physicalFile.readAsStringSync();
    final physicalPayload =
        jsonDecode(physicalOriginal) as Map<String, dynamic>;
    ((((physicalPayload['metrics'] as Map<String, dynamic>)['deviceResults']
                    as List<dynamic>)
                .first)
            as Map<String, dynamic>)['fakeDeadlines'] =
        99;
    physicalFile.writeAsStringSync(jsonEncode(physicalPayload));
    refreshEvidenceHash('G7', 'physicalDeviceMatrix', physicalFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final physicalResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(physicalResult.exitCode, 1);
    expect(
      physicalResult.stderr,
      contains(
        'physicalDeviceMatrix.api29_boundary.fakeDeadlines is below 100',
      ),
    );
    physicalFile.writeAsStringSync(physicalOriginal);
    refreshEvidenceHash('G7', 'physicalDeviceMatrix', physicalFile);

    final latePhysicalPayload =
        jsonDecode(physicalOriginal) as Map<String, dynamic>;
    ((((latePhysicalPayload['metrics'] as Map<String, dynamic>)['deviceResults']
                    as List<dynamic>)
                .first)
            as Map<String, dynamic>)['panicBackupP99LateMs'] =
        5001;
    physicalFile.writeAsStringSync(jsonEncode(latePhysicalPayload));
    refreshEvidenceHash('G7', 'physicalDeviceMatrix', physicalFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final latePhysicalResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(latePhysicalResult.exitCode, 1);
    expect(
      latePhysicalResult.stderr,
      contains(
        'physicalDeviceMatrix.api29_boundary.panicBackupP99LateMs exceeds 5000',
      ),
    );
    physicalFile.writeAsStringSync(physicalOriginal);
    refreshEvidenceHash('G7', 'physicalDeviceMatrix', physicalFile);

    final soakFile = File('${directory.path}/closedSoakReport.json');
    final soakOriginal = soakFile.readAsStringSync();
    final soakPayload = jsonDecode(soakOriginal) as Map<String, dynamic>;
    (soakPayload['metrics'] as Map<String, dynamic>)['finishedAt'] =
        '2026-07-14T23:59:59Z';
    soakFile.writeAsStringSync(jsonEncode(soakPayload));
    refreshEvidenceHash('G9', 'closedSoakReport', soakFile);
    manifest.writeAsStringSync(jsonEncode(completeManifest(typed: true)));
    final soakResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(soakResult.exitCode, 1);
    expect(
      soakResult.stderr,
      contains('closedSoakReport duration is below 14 days'),
    );
    soakFile.writeAsStringSync(soakOriginal);
    refreshEvidenceHash('G9', 'closedSoakReport', soakFile);

    final missingMasvs = completeManifest(typed: true);
    final g4 = (missingMasvs['gates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((gate) => gate['id'] == 'G4');
    g4['evidence'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'path': 'witness.txt',
        'sha256': witnessHash,
        'candidateBound': true,
      },
    ];
    manifest.writeAsStringSync(jsonEncode(missingMasvs));
    final missingMasvsResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(missingMasvsResult.exitCode, 1);
    expect(
      missingMasvsResult.stderr,
      contains('G4 requires one candidate-bound MASVS assessment'),
    );

    final malformedVersion = completeManifest(typed: true);
    (malformedVersion['candidate'] as Map<String, dynamic>)['versionCode'] =
        null;
    manifest.writeAsStringSync(jsonEncode(malformedVersion));
    final malformedVersionResult = await Process.run('python3', <String>[
      'scripts/verify_external_release_gates.py',
      '--manifest',
      manifest.path,
      '--aab',
      aab.path,
    ]);
    expect(malformedVersionResult.exitCode, 1);
    expect(
      malformedVersionResult.stderr,
      contains('versionCode must be a positive integer'),
    );
    expect(malformedVersionResult.stderr, isNot(contains('Traceback')));

    final drifted = completeManifest(typed: true);
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

Map<String, Object?> _gateEvidence({
  required String gateId,
  required String kind,
  required String aabHash,
  required String artifactPath,
  required String artifactSha256,
}) => <String, Object?>{
  'schemaVersion': 1,
  'evidenceType': kind,
  'gateId': gateId,
  'status': 'PASS',
  'summary': 'Candidate-bound acceptance evidence completed successfully.',
  'candidate': <String, Object?>{
    'packageName': 'com.poyrazoncel.korubeni',
    'versionName': '1.0.3',
    'versionCode': 10003,
    'aabSha256': aabHash,
  },
  'review': <String, Object?>{
    'performedBy': 'accountable-$kind-operator',
    'performedAt': '2026-07-18T12:00:00Z',
    'independentFromImplementation': true,
  },
  'artifacts': <Object?>[
    <String, Object?>{
      'path': artifactPath,
      'sha256': artifactSha256,
      'candidateBound': true,
      'description': 'Redacted raw evidence for the exact candidate.',
    },
  ],
  'metrics': _gateMetrics(kind),
};

Map<String, Object?> _gateMetrics(String kind) => switch (kind) {
  'safetyCaseReview' => <String, Object?>{
    'openS4': 0,
    'uncontrolledS3': 0,
    'hazards': <Object?>[
      for (var index = 1; index <= 15; index++)
        <String, Object?>{
          'id': 'H${index.toString().padLeft(2, '0')}',
          'status': 'CONTROLLED',
          'controlEvidence': 'Candidate-bound control evidence verified.',
        },
    ],
  },
  'nativeKernelReport' => <String, Object?>{
    'nativeTests': 60,
    'modelOperations': 10000000,
    'modelSeeds': 20,
    'tracesPerSeed': 10000,
    'operationsPerTrace': 50,
    'raceFamilies': 5,
    'interleavingsPerFamily': 1000,
    'raceInterleavings': <String, int>{
      'cancelVsReceiver': 1000,
      'dartVsReceiver': 1000,
      'exactVsInexact': 1000,
      'resetVsExpiry': 1000,
      'oldVsNewGeneration': 1000,
    },
    'criticalSafetyViolations': 0,
  },
  'mutationReport' => <String, Object?>{
    'total': 6,
    'killed': 6,
    'baselinePassed': true,
    'cases': <String, String>{
      'cancelResultSwallowed': 'KILLED',
      'staleGenerationAccepted': 'KILLED',
      'pinLoadingTreatedAbsent': 'KILLED',
      'logBeforeDispatch': 'KILLED',
      'notificationOutcomeDiscarded': 'KILLED',
      'disposeCancelsNative': 'KILLED',
    },
  },
  'flutterSessionReport' => <String, Object?>{
    'dartTests': 688,
    'criticalCoverageFiles': 4,
    'minimumCriticalCoveragePercent': 90.57,
    'pinReadFailureProtected': true,
    'lifecycleCancelProtected': true,
    'falseCancelProtected': true,
    'scenarios': <String, String>{
      'cancelTimeoutReconciled': 'PASS',
      'pinLoadingBlocked': 'PASS',
      'pinReadFailureBlocked': 'PASS',
      'disposeCannotCancel': 'PASS',
      'fallbackBeforeBestEffortWork': 'PASS',
      'falseArmAcknowledgementBlocked': 'PASS',
      'staleRescheduleBlocked': 'PASS',
      'contactSnapshotImmutable': 'PASS',
      'armedSessionEntitlementIndependent': 'PASS',
    },
  },
  'androidPlatformMatrix' => <String, Object?>{
    'apiLevels': <int>[29, 30, 31, 32, 33, 34, 35, 36],
    'emulatorResults': <String, String>{
      for (var api = 29; api <= 36; api++) '$api': 'PASS',
    },
    'scenarios': <String, String>{
      'lockedBootCompleted': 'PASS',
      'bootCompleted': 'PASS',
      'packageReplaced': 'PASS',
      'userUnlocked': 'PASS',
      'doze': 'PASS',
      'processDeath': 'PASS',
      'permissionRevokeRegrant': 'PASS',
      'telecomSubmittedUnconfirmed': 'PASS',
      'notificationFailure': 'PASS',
      'exactAlarmFailure': 'PASS',
      'corruptSchemaFailClosed': 'PASS',
    },
    'directBootReboot': true,
    'doze': true,
    'permissionRevokeRegrant': true,
    'telecomRequest': true,
    'playDeliveredCandidate': true,
    'criticalSafetyViolations': 0,
  },
  'licensePolicyReport' => <String, Object?>{
    'components': 400,
    'reviewed': 400,
    'unverified': 0,
    'policyPassed': true,
    'noticesParity': true,
  },
  'privacyCounselDecision' => <String, Object?>{
    'decision': 'APPROVED',
    'fieldInventoryComplete': true,
    'transferMechanismsResolved': true,
    'deletionRunbookVerified': true,
  },
  'qualityMatrix' => <String, Object?>{
    'accessibility': <String, String>{
      'talkBack': 'PASS',
      'switchAccess': 'PASS',
      'accessibilityScanner': 'PASS',
      'font200Percent': 'PASS',
    },
    'featureMatrixPassed': true,
    'migrationMatrixPassed': true,
    'featureChecks': <String, String>{
      'pinSetupUnlockReset': 'PASS',
      'contactManagement': 'PASS',
      'mapPermissionOfflineConsentWithdrawal': 'PASS',
      'fakeCallImmediateScheduled': 'PASS',
      'sirenAudioFocusBackground': 'PASS',
      'panicHoldAccessibilityLifecycle': 'PASS',
      'checkInStartConfirmStopExpiry': 'PASS',
      'safeWalkStartStopExpiry': 'PASS',
      'timelineExportDelete': 'PASS',
      'freeProPaywall': 'PASS',
    },
    'migrationChecks': <String, String>{
      'preferences': 'PASS',
      'database': 'PASS',
      'contact': 'PASS',
      'pin': 'PASS',
      'activeSession': 'PASS',
      'corruptStateRecovery': 'PASS',
      'lowDiskRecovery': 'PASS',
    },
    'criticalCrashAnr': 0,
    'coldStartP95Ms': 4000,
    'armAckP95Ms': 500,
    'receiverFallbackP95Ms': 1000,
    'wakeLockMaxMs': 10000,
    'idleBatteryDeltaPercentagePoints': 2,
  },
  'artifactChainReport' => <String, Object?>{
    'bundletoolValid': true,
    'arm64Only': true,
    'page16kCompatible': true,
    'signatureValid': true,
    'attestationVerified': true,
    'provenanceVerified': true,
    'sbomVerified': true,
    'symbolsComplete': true,
    'productionRevenueCatKey': true,
    'buildCount': 1,
  },
  'physicalDeviceMatrix' => <String, Object?>{
    'deviceResults': <Object?>[
      for (final profile in <String>[
        'api29_boundary',
        'pixel_api36_16kb',
        'samsung_oneui',
        'xiaomi_hyperos',
      ])
        <String, Object?>{
          'profile': profile,
          'physical': true,
          'playInstalled': true,
          'fakeDeadlines': 100,
          'missedDeadlines': 0,
          'cancelRaces': 50,
          'confirmedCancelDispatches': 0,
          'lifecycleCycles': 20,
          'wrongTargets': 0,
          'pinBypasses': 0,
          'safetyCrashes': 0,
          'testDimensions': <String, String>{
            for (final dimension in <String>[
              'foreground',
              'background',
              'locked',
              'exactAlarmRevokeRegrant',
              'notificationRevokeRegrant',
              'callPermissionRevokeRegrant',
              'defaultSim',
              'askEveryTimeSim',
              'noSim',
              'airplaneMode',
              'noService',
              'ongoingCall',
              'doze',
              'processKill',
              'reboot',
            ])
              dimension: 'PASS',
          },
          'panicBackupP99LateMs': 5000,
          'panicBackupMaxLateMs': 10000,
          'checkInFinalP99LateMs': 10000,
          'checkInFinalMaxLateMs': 30000,
          'safeWalkFinalP99LateMs': 10000,
          'safeWalkFinalMaxLateMs': 30000,
          'apiLevel': switch (profile) {
            'api29_boundary' => 29,
            'pixel_api36_16kb' => 36,
            _ => 35,
          },
          'lowMemoryBoundary': profile == 'api29_boundary',
          'kernel16k': profile == 'pixel_api36_16kb',
          'compatModeOff': profile == 'pixel_api36_16kb',
          'oemSkinVerified':
              profile == 'samsung_oneui' || profile == 'xiaomi_hyperos',
        },
    ],
    'automaticRequestsObserved': 10,
    'manualDialObserved': 10,
    'dualSimDeviceCovered': true,
    'criticalCrashAnr': 0,
  },
  'billingPlayMatrix' => <String, Object?>{
    'cases': <String, String>{
      for (final name in <String>[
        'monthlyPurchase',
        'annualPurchase',
        'pending',
        'userCancel',
        'cancelledUntilExpiry',
        'restore',
        'reinstall',
        'renewal',
        'grace',
        'pauseResume',
        'accountHold',
        'refundRevoke',
        'expiryLapse',
        'multiGoogleAccount',
        'offlineCacheInside',
        'offlineCacheOutside',
        'noOffering',
        'networkFailure',
        'revenueCatOutage',
      ])
        name: 'PASS',
    },
    'finalConfigurationRestored': true,
    'smokePurchaseRestorePassed': true,
  },
  'playPolicyDisposition' => <String, Object?>{
    'forms': <String, String>{
      for (final name in <String>[
        'dataSafety',
        'healthApps',
        'targetAudience',
        'contentRating',
        'appAccess',
        'privacyUrl',
        'deletionUrl',
      ])
        name: 'PASS',
    },
    'bundleExplorer16kb': true,
    'permissionsMatchDeclarations': true,
    'noFgsFsiBackgroundLocation': true,
    'preLaunchOpenFindings': 0,
  },
  'closedSoakReport' => <String, Object?>{
    'startedAt': '2026-07-01T00:00:00Z',
    'finishedAt': '2026-07-15T00:00:00Z',
    'testers': 12,
    'manualProbeDays': 14,
    'safetyIncidents': 0,
    'openP0P1': 0,
    'criticalCrashAnr': 0,
    'purchaseRestoreFailures': 0,
    'aabChanged': false,
    'dashboardFrozen': true,
  },
  'hotfixDrillReport' => <String, Object?>{
    'durationMinutes': 90,
    'internalTrackReady': true,
    'nonUploadableArtifact': true,
    'regressionSelected': true,
    'reservedVersionCode': 10004,
  },
  'releaseBoardDecision' => <String, Object?>{
    'decision': 'GO',
    'approvedRoles': _approvalRoles.toList(),
    'openP0P1': 0,
    'safetyIncidents': 0,
  },
  _ => throw ArgumentError.value(kind, 'kind', 'unsupported evidence kind'),
};

Map<String, Object?> _rawMutationReport({required String commit}) {
  const ids = <String>[
    'M01_CANCEL_RESULT_SWALLOWED',
    'M02_STALE_GENERATION_ACCEPTED',
    'M03_PIN_READ_FAILURE_AS_ABSENT',
    'M04_LOG_BEFORE_DISPATCH',
    'M05_NOTIFICATION_RESULT_IGNORED',
    'M06_DISPOSE_NATIVE_CANCEL',
  ];
  return <String, Object?>{
    'schemaVersion': 1,
    'sourceHead': commit,
    'sourceStatusSha256': _emptySha256,
    'sourceWasDirty': false,
    'runnerSha256': 'a' * 64,
    'sourceFiles': <String, String>{
      'lib/core/services/emergency_platform_service.dart': 'b' * 64,
      'android/app/src/main/kotlin/example.kt': 'c' * 64,
    },
    'preparation': <String, Object?>{
      'exitCode': 0,
      'timedOut': false,
      'durationMs': 1,
      'outputSha256': 'd' * 64,
    },
    'baselines': <Object?>[
      for (final name in <String>['flutter', 'native'])
        <String, Object?>{
          'name': name,
          'exitCode': 0,
          'timedOut': false,
          'durationMs': 1,
          'outputSha256': 'e' * 64,
        },
    ],
    'mutations': <Object?>[
      for (final id in ids)
        <String, Object?>{
          'id': id,
          'description': 'Release-blocking safety mutation.',
          'target': 'lib/example.dart',
          'status': 'KILLED',
          'result': <String, Object?>{
            'exitCode': 1,
            'timedOut': false,
            'durationMs': 1,
            'outputSha256': 'f' * 64,
          },
        },
    ],
    'status': 'PASS',
  };
}

Map<String, Object?> _rawCriticalCoverage() {
  const paths = <String>[
    'lib/core/services/emergency_session_contract.dart',
    'lib/core/services/emergency_platform_service.dart',
    'lib/core/services/pin_verification_service.dart',
    'lib/core/services/check_in_service.dart',
  ];
  return <String, Object?>{
    'schemaVersion': 1,
    'minimumLineCoveragePercent': 90,
    'result': 'PASS',
    'files': <Object?>[
      for (final path in paths)
        <String, Object?>{
          'path': path,
          'linesFound': 100,
          'linesHit': 95,
          'lineCoveragePercent': 95.0,
        },
    ],
  };
}

Map<String, Object?> _rawAndroidReleaseSurface() {
  const safetyComponents = <String>[
    'com.poyrazoncel.korubeni.emergency.EmergencyFallbackDialActivity',
    'com.poyrazoncel.korubeni.emergency.CheckInAlarmReceiver',
    'com.poyrazoncel.korubeni.emergency.CountdownAlarmReceiver',
    'com.poyrazoncel.korubeni.emergency.BootCompletedReceiver',
    'com.poyrazoncel.korubeni.emergency.ExactAlarmPermissionReceiver',
    'com.poyrazoncel.korubeni.emergency.ClockChangeReceiver',
    'com.poyrazoncel.korubeni.emergency.EmergencyFallbackCleanupReceiver',
  ];
  const permissions = <String>[
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.CALL_PHONE',
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    'android.permission.SCHEDULE_EXACT_ALARM',
    'android.permission.VIBRATE',
    'android.permission.WAKE_LOCK',
    'com.android.vending.BILLING',
    'com.poyrazoncel.korubeni.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
  ];
  final components = <Object?>[
    <String, Object?>{
      'type': 'activity',
      'name': 'com.poyrazoncel.korubeni.MainActivity',
      'exported': true,
      'permission': null,
      'directBootAware': false,
    },
    <String, Object?>{
      'type': 'receiver',
      'name': 'androidx.profileinstaller.ProfileInstallReceiver',
      'exported': true,
      'permission': 'android.permission.DUMP',
      'directBootAware': false,
    },
    for (final name in safetyComponents)
      <String, Object?>{
        'type': name.endsWith('Activity') ? 'activity' : 'receiver',
        'name': name,
        'exported': false,
        'permission': null,
        'directBootAware': true,
      },
  ];
  return <String, Object?>{
    'schemaVersion': 1,
    'status': 'PASS',
    'candidateBound': false,
    'expectedPackage': 'com.poyrazoncel.korubeni',
    'manifestSha256': '1' * 64,
    'networkSecurityConfigSha256': '2' * 64,
    'dataExtractionRulesSha256': '3' * 64,
    'minSdk': 29,
    'targetSdk': 36,
    'permissionCount': permissions.length,
    'permissions': permissions,
    'componentCount': components.length,
    'components': components,
    'unprotectedExportedComponents': <Object?>[],
    'limitations': <String>[
      'MERGED_MANIFEST_AND_SOURCE_RESOURCE_AUDIT_ONLY',
      'NOT_RUNTIME_INTENT_FUZZING',
      'NOT_PRODUCTION_AAB_UNLESS_RUN_BY_TAGGED_WORKFLOW',
    ],
  };
}

Map<String, Object?> _rawVerifiedSbom() => <String, Object?>{
  'bomFormat': 'CycloneDX',
  'specVersion': '1.6',
  'version': 1,
  'metadata': <String, Object?>{
    'properties': <Object?>[
      <String, Object?>{
        'name': 'korubeni:licenseEvidenceStatus',
        'value': 'VERIFIED',
      },
      <String, Object?>{
        'name': 'korubeni:sourceOfTruth',
        'value': 'pubspec.lock+android/app/gradle.lockfile',
      },
    ],
  },
  'components': <Object?>[
    <String, Object?>{
      'type': 'library',
      'name': 'example',
      'version': '1.0.0',
      'purl': 'pkg:pub/example@1.0.0',
      'licenses': <Object?>[
        <String, Object?>{
          'license': <String, String>{'id': 'MIT'},
        },
      ],
      'properties': <Object?>[
        <String, String>{
          'name': 'korubeni:licenseEvidenceUrl',
          'value': 'https://example.test/license',
        },
        <String, String>{
          'name': 'korubeni:licenseEvidenceSha256',
          'value': '4' * 64,
        },
        <String, String>{
          'name': 'korubeni:licenseReviewedBy',
          'value': 'independent-license-reviewer',
        },
        <String, String>{
          'name': 'korubeni:licenseReviewedAt',
          'value': '2026-07-18',
        },
      ],
    },
    <String, Object?>{
      'type': 'library',
      'name': 'example-android',
      'version': '1.0.0',
      'purl': 'pkg:maven/com.example/example@1.0.0',
      'licenses': <Object?>[
        <String, Object?>{
          'license': <String, String>{'id': 'Apache-2.0'},
        },
      ],
      'properties': <Object?>[
        <String, String>{
          'name': 'korubeni:licenseEvidenceUrl',
          'value': 'https://example.test/android-license',
        },
        <String, String>{
          'name': 'korubeni:licenseEvidenceSha256',
          'value': '5' * 64,
        },
        <String, String>{
          'name': 'korubeni:licenseReviewedBy',
          'value': 'independent-license-reviewer',
        },
        <String, String>{
          'name': 'korubeni:licenseReviewedAt',
          'value': '2026-07-18',
        },
      ],
    },
  ],
};

Map<String, Object?> _masvsAssessment({
  required String aabHash,
  required String witnessHash,
}) {
  const controls = <String>[
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
  ];
  return <String, Object?>{
    'schemaVersion': 1,
    'framework': <String, Object?>{
      'name': 'OWASP MASVS',
      'sourceUrl': 'https://mas.owasp.org/MASVS/',
      'referenceRevision': '2026-07-19',
    },
    'candidate': <String, Object?>{
      'packageName': 'com.poyrazoncel.korubeni',
      'versionName': '1.0.3',
      'versionCode': 10003,
      'aabSha256': aabHash,
    },
    'review': <String, Object?>{
      'reviewedBy': 'independent-security-reviewer',
      'reviewedAt': '2026-07-19T12:00:00Z',
    },
    'controls': <Object?>[
      for (final id in controls)
        <String, Object?>{
          'id': id,
          'status': 'PASS',
          'rationale': 'Candidate-bound verification completed.',
          'evidence': <Object?>[
            <String, Object?>{
              'path': 'witness.txt',
              'sha256': witnessHash,
              'candidateBound': true,
            },
          ],
        },
    ],
  };
}

String _sha256(File file) {
  final result = Process.runSync('shasum', <String>['-a', '256', file.path]);
  if (result.exitCode != 0) throw StateError(result.stderr.toString());
  return result.stdout.toString().split(RegExp(r'\s+')).first;
}
