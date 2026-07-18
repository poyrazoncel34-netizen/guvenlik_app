import 'dart:convert';
import 'dart:io';

Never _fail(String message) {
  stderr.writeln('LICENSE_POLICY_FAIL: $message');
  exit(1);
}

void main(List<String> arguments) {
  final sbomPath = _requiredValue(arguments, '--sbom');
  final policyPath = _requiredValue(arguments, '--policy');
  final sbom = _readJsonMap(File(sbomPath));
  final policy = _readJsonMap(File(policyPath));

  if (policy['schemaVersion'] != 1) {
    _fail('unsupported policy schema');
  }
  final allowed = _stringSet(policy['allowedSpdxIds'], 'allowedSpdxIds');
  final blocked = _stringSet(policy['blockedSpdxIds'], 'blockedSpdxIds');
  if (allowed.isEmpty || allowed.intersection(blocked).isNotEmpty) {
    _fail('invalid or overlapping SPDX policy sets');
  }

  final status = _metadataProperty(sbom, 'korubeni:licenseEvidenceStatus');
  if (status != 'VERIFIED') {
    _fail('SBOM license evidence status is ${status ?? 'missing'}');
  }

  final components = sbom['components'];
  if (components is! List || components.isEmpty) {
    _fail('SBOM components are missing');
  }
  final waivers = _readWaivers(policy['waivers']);
  final seen = <String>{};
  final failures = <String>[];
  for (final rawComponent in components) {
    if (rawComponent is! Map<String, dynamic>) {
      _fail('malformed SBOM component');
    }
    final purl = rawComponent['purl']?.toString() ?? '';
    if (!purl.startsWith('pkg:') || !seen.add(purl)) {
      _fail('missing or duplicate component purl: $purl');
    }
    final licenseId = _singleLicenseId(rawComponent);
    final evidenceComplete =
        _componentProperty(
              rawComponent,
              'korubeni:licenseEvidenceUrl',
            )?.startsWith('https://') ==
            true &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(
          _componentProperty(rawComponent, 'korubeni:licenseEvidenceSha256') ??
              '',
        ) &&
        (_componentProperty(rawComponent, 'korubeni:licenseReviewedBy') ?? '')
            .isNotEmpty &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(
          _componentProperty(rawComponent, 'korubeni:licenseReviewedAt') ?? '',
        );
    if (licenseId == null || !evidenceComplete) {
      failures.add('$purl: missing reviewed license evidence');
      continue;
    }
    if (blocked.contains(licenseId)) {
      failures.add('$purl: blocked license $licenseId');
      continue;
    }
    if (!allowed.contains(licenseId)) {
      final waiver = waivers[purl];
      if (waiver == null || waiver.spdxId != licenseId || waiver.isExpired) {
        failures.add(
          '$purl: $licenseId is not allowed and has no valid waiver',
        );
      }
    }
  }

  final staleWaivers = waivers.keys
      .where((purl) => !seen.contains(purl))
      .toList();
  if (staleWaivers.isNotEmpty) {
    failures.add('stale waivers: ${staleWaivers.join(', ')}');
  }
  if (failures.isNotEmpty) {
    for (final failure in failures.take(20)) {
      stderr.writeln('  $failure');
    }
    if (failures.length > 20) {
      stderr.writeln('  ... ${failures.length - 20} more failures');
    }
    _fail('${failures.length} component or waiver policy failures');
  }

  stdout.writeln(
    'LICENSE_POLICY_PASS: ${seen.length} components have reviewed evidence',
  );
}

String _requiredValue(List<String> arguments, String flag) {
  final index = arguments.indexOf(flag);
  if (index == -1 || index + 1 >= arguments.length) {
    _fail('usage requires $flag <path>');
  }
  return arguments[index + 1];
}

Map<String, dynamic> _readJsonMap(File file) {
  if (!file.existsSync() || file.lengthSync() == 0) {
    _fail('missing or empty file: ${file.path}');
  }
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<String, dynamic>) {
    _fail('JSON root is not an object: ${file.path}');
  }
  return value;
}

Set<String> _stringSet(Object? value, String field) {
  if (value is! List) _fail('$field must be a list');
  final result = value.map((item) => item.toString()).toSet();
  if (result.length != value.length || result.any((item) => item.isEmpty)) {
    _fail('$field contains duplicate or empty values');
  }
  return result;
}

String? _metadataProperty(Map<String, dynamic> sbom, String name) {
  final metadata = sbom['metadata'];
  if (metadata is! Map<String, dynamic>) return null;
  return _propertyValue(metadata['properties'], name);
}

String? _componentProperty(Map<String, dynamic> component, String name) =>
    _propertyValue(component['properties'], name);

String? _propertyValue(Object? rawProperties, String name) {
  if (rawProperties is! List) return null;
  final matches = rawProperties.whereType<Map>().where(
    (property) => property['name']?.toString() == name,
  );
  if (matches.length != 1) return null;
  return matches.single['value']?.toString();
}

String? _singleLicenseId(Map<String, dynamic> component) {
  final licenses = component['licenses'];
  if (licenses is! List || licenses.length != 1) return null;
  final wrapper = licenses.single;
  if (wrapper is! Map) return null;
  final license = wrapper['license'];
  if (license is! Map) return null;
  final id = license['id']?.toString();
  return id == null || id.isEmpty ? null : id;
}

Map<String, _Waiver> _readWaivers(Object? rawWaivers) {
  if (rawWaivers is! List) _fail('waivers must be a list');
  final result = <String, _Waiver>{};
  for (final raw in rawWaivers) {
    if (raw is! Map<String, dynamic>) _fail('malformed waiver');
    final waiver = _Waiver(
      purl: raw['purl']?.toString() ?? '',
      spdxId: raw['spdxId']?.toString() ?? '',
      expiresOn: DateTime.tryParse(raw['expiresOn']?.toString() ?? ''),
      approvedBy: raw['approvedBy']?.toString() ?? '',
      rationale: raw['rationale']?.toString() ?? '',
    );
    if (!waiver.purl.startsWith('pkg:') ||
        waiver.spdxId.isEmpty ||
        waiver.expiresOn == null ||
        waiver.approvedBy.isEmpty ||
        waiver.rationale.isEmpty ||
        result.containsKey(waiver.purl)) {
      _fail('incomplete or duplicate waiver: ${waiver.purl}');
    }
    result[waiver.purl] = waiver;
  }
  return result;
}

class _Waiver {
  const _Waiver({
    required this.purl,
    required this.spdxId,
    required this.expiresOn,
    required this.approvedBy,
    required this.rationale,
  });

  final String purl;
  final String spdxId;
  final DateTime? expiresOn;
  final String approvedBy;
  final String rationale;

  bool get isExpired {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final expiryDate = DateTime.utc(
      expiresOn!.year,
      expiresOn!.month,
      expiresOn!.day,
    );
    return expiryDate.isBefore(today);
  }
}
