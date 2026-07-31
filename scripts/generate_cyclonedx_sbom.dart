import 'dart:convert';
import 'dart:io';

/// Generates a deterministic CycloneDX inventory from the two lockfiles that
/// define the shipped Flutter and Android runtime dependency graphs.
///
/// This is an inventory/provenance artifact, not a vulnerability or licence
/// verdict. OSV and licence-policy gates remain separate and fail closed.
void main(List<String> arguments) {
  final outputPath = _outputPath(arguments);
  final licenseEvidencePath = _optionalValue(arguments, '--license-evidence');
  final pubComponents = _readPubComponents(File('pubspec.lock'));
  final mavenComponents = _readMavenComponents(
    File('android/app/gradle.lockfile'),
  );
  final components = [...pubComponents, ...mavenComponents]
    ..sort(
      (left, right) =>
          (left['bom-ref'] as String).compareTo(right['bom-ref'] as String),
    );

  final refs = components.map((item) => item['bom-ref']).toSet();
  if (components.isEmpty || refs.length != components.length) {
    stderr.writeln('SBOM generation failed: empty or duplicate components.');
    exitCode = 1;
    return;
  }

  final licenseEvidence = licenseEvidencePath == null
      ? const <String, _LicenseEvidence>{}
      : _readLicenseEvidence(File(licenseEvidencePath));
  final staleEvidence = licenseEvidence.keys
      .where((purl) => !refs.contains(purl))
      .toList(growable: false);
  if (staleEvidence.isNotEmpty) {
    stderr.writeln(
      'SBOM generation failed: stale license evidence for '
      '${staleEvidence.join(', ')}.',
    );
    exitCode = 1;
    return;
  }
  for (final component in components) {
    final purl = component['purl'] as String;
    final evidence = licenseEvidence[purl];
    if (evidence == null) continue;
    component['licenses'] = <Object?>[
      <String, Object?>{
        'license': <String, Object?>{'id': evidence.spdxId},
      },
    ];
    // Component properties are built as List<Map<String, String>>; adding
    // Map<String, Object?> entries throws at runtime once evidence is present.
    final properties = (component['properties'] as List<Map<String, String>>);
    properties.addAll(<Map<String, String>>[
      {'name': 'korubeni:licenseEvidenceUrl', 'value': evidence.sourceUrl},
      {'name': 'korubeni:licenseEvidenceSha256', 'value': evidence.sha256},
      {'name': 'korubeni:licenseReviewedBy', 'value': evidence.reviewedBy},
      {'name': 'korubeni:licenseReviewedAt', 'value': evidence.reviewedAt},
    ]);
  }
  final licensesComplete = licenseEvidence.length == components.length;

  final bom = <String, Object?>{
    'bomFormat': 'CycloneDX',
    'specVersion': '1.6',
    'version': 1,
    'metadata': {
      'tools': [
        {
          'vendor': 'KoruBeni',
          'name': 'generate_cyclonedx_sbom.dart',
          'version': '1',
        },
      ],
      'component': {
        'type': 'application',
        'name': 'KoruBeni Android Play',
        'bom-ref': 'pkg:generic/korubeni-android-play',
      },
      'properties': [
        {
          'name': 'korubeni:licenseEvidenceStatus',
          'value': licensesComplete ? 'VERIFIED' : 'UNVERIFIED',
        },
        {
          'name': 'korubeni:sourceOfTruth',
          'value': 'pubspec.lock+android/app/gradle.lockfile',
        },
      ],
    },
    'components': components,
  };

  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(bom)}\n',
  );
  stdout.writeln(
    'CycloneDX SBOM: ${components.length} components -> ${output.path}',
  );
}

String _outputPath(List<String> arguments) {
  final index = arguments.indexOf('--output');
  if (index == -1 || index + 1 >= arguments.length) {
    stderr.writeln(
      'Usage: dart run scripts/generate_cyclonedx_sbom.dart '
      '--output <path>',
    );
    exit(64);
  }
  return arguments[index + 1];
}

String? _optionalValue(List<String> arguments, String flag) {
  final index = arguments.indexOf(flag);
  if (index == -1) return null;
  if (index + 1 >= arguments.length) {
    stderr.writeln('Missing value for $flag');
    exit(64);
  }
  return arguments[index + 1];
}

Map<String, _LicenseEvidence> _readLicenseEvidence(File file) {
  if (!file.existsSync()) {
    throw StateError('Missing ${file.path}');
  }
  final root = jsonDecode(file.readAsStringSync());
  if (root is! Map<String, dynamic> || root['schemaVersion'] != 1) {
    throw FormatException('Invalid license evidence schema: ${file.path}');
  }
  final rawEntries = root['entries'];
  if (rawEntries is! Map<String, dynamic>) {
    throw const FormatException('License evidence entries must be a map.');
  }
  final result = <String, _LicenseEvidence>{};
  final sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  for (final entry in rawEntries.entries) {
    final purl = entry.key;
    final value = entry.value;
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid license evidence entry: $purl');
    }
    final evidence = _LicenseEvidence(
      spdxId: value['spdxId']?.toString() ?? '',
      sourceUrl: value['sourceUrl']?.toString() ?? '',
      sha256: value['sha256']?.toString().toLowerCase() ?? '',
      reviewedBy: value['reviewedBy']?.toString() ?? '',
      reviewedAt: value['reviewedAt']?.toString() ?? '',
    );
    if (!purl.startsWith('pkg:') ||
        evidence.spdxId.isEmpty ||
        !evidence.sourceUrl.startsWith('https://') ||
        !sha256Pattern.hasMatch(evidence.sha256) ||
        evidence.reviewedBy.isEmpty ||
        !datePattern.hasMatch(evidence.reviewedAt)) {
      throw FormatException('Incomplete license evidence entry: $purl');
    }
    result[purl] = evidence;
  }
  return result;
}

List<Map<String, Object?>> _readPubComponents(File lockfile) {
  if (!lockfile.existsSync()) {
    throw StateError('Missing ${lockfile.path}');
  }
  final result = <Map<String, Object?>>[];
  var inPackages = false;
  String? name;
  String? version;
  String? source;
  String? sha256;

  void flush() {
    if (name == null || version == null || source == null) return;
    final purl = 'pkg:pub/$name@$version';
    result.add({
      'type': 'library',
      'name': name,
      'version': version,
      'bom-ref': purl,
      'purl': purl,
      if (sha256 != null)
        'hashes': [
          {'alg': 'SHA-256', 'content': sha256},
        ],
      'properties': [
        {'name': 'korubeni:ecosystem', 'value': 'Pub'},
        {'name': 'korubeni:lockSource', 'value': source},
      ],
    });
  }

  for (final line in lockfile.readAsLinesSync()) {
    if (line == 'packages:') {
      inPackages = true;
      continue;
    }
    if (inPackages && line.isNotEmpty && !line.startsWith(' ')) {
      flush();
      break;
    }
    if (!inPackages) continue;

    final packageMatch = RegExp(r'^  ([^ :]+):$').firstMatch(line);
    if (packageMatch != null) {
      flush();
      name = packageMatch.group(1);
      version = null;
      source = null;
      sha256 = null;
      continue;
    }
    version =
        RegExp(r'^    version: "([^"]+)"$').firstMatch(line)?.group(1) ??
        version;
    source =
        RegExp(r'^    source: (\S+)$').firstMatch(line)?.group(1) ?? source;
    sha256 =
        RegExp(
          r'^      sha256: "([0-9a-fA-F]{64})"$',
        ).firstMatch(line)?.group(1) ??
        sha256;
  }
  return result;
}

List<Map<String, Object?>> _readMavenComponents(File lockfile) {
  if (!lockfile.existsSync()) {
    throw StateError('Missing ${lockfile.path}');
  }
  final result = <Map<String, Object?>>[];
  final seen = <String>{};
  final coordinate = RegExp(r'^([^:#]+):([^:]+):([^=]+)=(.+)$');
  for (final line in lockfile.readAsLinesSync()) {
    final match = coordinate.firstMatch(line.trim());
    if (match == null) continue;
    final group = match.group(1)!;
    final artifact = match.group(2)!;
    final version = match.group(3)!;
    final purl = 'pkg:maven/$group/$artifact@$version';
    if (!seen.add(purl)) continue;
    result.add({
      'type': 'library',
      'group': group,
      'name': artifact,
      'version': version,
      'bom-ref': purl,
      'purl': purl,
      'properties': [
        {'name': 'korubeni:ecosystem', 'value': 'Maven'},
      ],
    });
  }
  return result;
}

class _LicenseEvidence {
  const _LicenseEvidence({
    required this.spdxId,
    required this.sourceUrl,
    required this.sha256,
    required this.reviewedBy,
    required this.reviewedAt,
  });

  final String spdxId;
  final String sourceUrl;
  final String sha256;
  final String reviewedBy;
  final String reviewedAt;
}
