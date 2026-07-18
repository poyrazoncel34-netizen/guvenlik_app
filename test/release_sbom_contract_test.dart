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
