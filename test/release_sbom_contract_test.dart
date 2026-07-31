import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../scripts/generate_cyclonedx_sbom.dart' as sbom;

void main() {
  test(
    'release workflow generates and uploads deterministic CycloneDX SBOM',
    () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      final generator = File(
        'scripts/generate_cyclonedx_sbom.dart',
      ).readAsStringSync();

      expect(workflow, contains('generate_cyclonedx_sbom.dart'));
      expect(workflow, contains('verify_sbom_license_policy.dart'));
      expect(workflow, contains('dependency_license_evidence.json'));
      expect(workflow, contains('dependency_license_policy.json'));
      expect(workflow, contains('sbom.cdx.json'));
      expect(workflow, contains('r8-mapping.txt'));
      expect(workflow, contains('native-debug-symbols.index'));
      expect(workflow, contains('BUNDLE-METADATA'));
      expect(workflow, contains('libflutter\\.so\\.dbg'));
      expect(workflow, contains('merged-AndroidManifest.xml'));
      expect(workflow, contains('lint-results-playRelease.xml'));
      expect(workflow, contains('android-app-gradle.lockfile'));
      expect(workflow, contains('android/gradle/verification-metadata.xml'));
      expect(workflow, contains('gradle-verification-metadata.xml'));
      expect(generator, contains("'bomFormat': 'CycloneDX'"));
      expect(generator, contains("'specVersion': '1.6'"));
      expect(generator, contains('pubspec.lock'));
      expect(generator, contains('android/app/gradle.lockfile'));
      expect(generator, contains("'value': licensesComplete ? 'VERIFIED'"));
    },
  );

  test('generated SBOM is valid JSON and contains both ecosystems', () async {
    final temp = await Directory.systemTemp.createTemp('korubeni-sbom-test.');
    addTearDown(() => temp.delete(recursive: true));
    final output = File('${temp.path}/sbom.cdx.json');
    sbom.main(['--output', output.path]);

    expect(output.existsSync(), isTrue);
    final json = jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    expect(json['bomFormat'], 'CycloneDX');
    expect(json['specVersion'], '1.6');
    final metadata = json['metadata'] as Map<String, dynamic>;
    final properties = (metadata['properties'] as List).cast<Map>();
    expect(
      properties.singleWhere(
        (property) => property['name'] == 'korubeni:licenseEvidenceStatus',
      )['value'],
      'UNVERIFIED',
    );
    final components = (json['components'] as List)
        .cast<Map<String, dynamic>>();
    expect(components.length, greaterThan(300));
    expect(
      components.any((item) => '${item['purl']}'.startsWith('pkg:pub/')),
      isTrue,
    );
    expect(
      components.any((item) => '${item['purl']}'.startsWith('pkg:maven/')),
      isTrue,
    );
  });

  test('SBOM built with real evidence marks every component reviewed', () async {
    // The generator only touches the evidence branch when --license-evidence is
    // passed, so the no-evidence test above cannot catch a fault in it.
    final temp = await Directory.systemTemp.createTemp('korubeni-sbom-evidence.');
    addTearDown(() => temp.delete(recursive: true));
    final output = File('${temp.path}/sbom.cdx.json');
    sbom.main([
      '--output',
      output.path,
      '--license-evidence',
      'config/dependency_license_evidence.json',
    ]);

    final json = jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    final metadata = json['metadata'] as Map<String, dynamic>;
    final metadataProperties = (metadata['properties'] as List).cast<Map>();
    expect(
      metadataProperties.singleWhere(
        (property) => property['name'] == 'korubeni:licenseEvidenceStatus',
      )['value'],
      'VERIFIED',
    );

    final components = (json['components'] as List)
        .cast<Map<String, dynamic>>();
    for (final component in components) {
      final licenses = component['licenses'] as List;
      final license = (licenses.single as Map)['license'] as Map;
      expect(
        '${license['id']}'.isNotEmpty,
        isTrue,
        reason: 'missing SPDX id for ${component['purl']}',
      );
      final names = (component['properties'] as List)
          .cast<Map>()
          .map((property) => property['name'])
          .toSet();
      expect(
        names,
        containsAll(<String>[
          'korubeni:licenseEvidenceUrl',
          'korubeni:licenseEvidenceSha256',
          'korubeni:licenseReviewedBy',
          'korubeni:licenseReviewedAt',
        ]),
        reason: 'missing evidence properties for ${component['purl']}',
      );
    }
  });

  test(
    'Gradle dependency verification metadata is non-empty and checksummed',
    () {
      final metadata = File('android/gradle/verification-metadata.xml');

      expect(metadata.existsSync(), isTrue);
      final xml = metadata.readAsStringSync();
      expect(xml, contains('<verification-metadata '));
      expect(xml, contains('<component '));
      expect(xml, contains('<artifact '));
      expect(xml, contains('<sha256 value="'));
    },
  );
}
