import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _criticalFiles = <String>[
  'lib/core/services/emergency_session_contract.dart',
  'lib/core/services/emergency_platform_service.dart',
  'lib/core/services/pin_verification_service.dart',
  'lib/core/services/check_in_service.dart',
];

Future<ProcessResult> _runGate(
  Directory temporaryDirectory,
  String lcov, {
  bool writeReport = false,
}) async {
  final lcovFile = File('${temporaryDirectory.path}/lcov.info')
    ..writeAsStringSync(lcov);
  // Under `flutter test`, Platform.resolvedExecutable is flutter_tester, not
  // the Dart CLI. Invoke the SDK command from PATH just like CI/release does.
  return Process.run('dart', <String>[
    'scripts/verify_critical_coverage.dart',
    '--lcov',
    lcovFile.path,
    if (writeReport) ...<String>[
      '--report',
      '${temporaryDirectory.path}/report.json',
    ],
  ]);
}

String _record(String path, {required int found, required int hit}) =>
    'SF:$path\nLF:$found\nLH:$hit\nend_of_record\n';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'korubeni-critical-coverage-',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('passes only when every critical file reaches 90 percent', () async {
    final lcov = _criticalFiles
        .map((path) => _record(path, found: 100, hit: 90))
        .join();

    final result = await _runGate(temporaryDirectory, lcov, writeReport: true);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('CRITICAL_COVERAGE_PASS'));
    final report =
        jsonDecode(
              File('${temporaryDirectory.path}/report.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(report['result'], 'PASS');
    expect(report['files'], hasLength(4));
  });

  test('fails when a critical file is below the threshold', () async {
    final lcov = _criticalFiles
        .map(
          (path) => _record(
            path,
            found: 100,
            hit: path.endsWith('check_in_service.dart') ? 89 : 100,
          ),
        )
        .join();

    final result = await _runGate(temporaryDirectory, lcov);

    expect(result.exitCode, isNot(0));
    expect(
      result.stdout,
      contains('FAIL lib/core/services/check_in_service.dart'),
    );
    expect(result.stderr, contains('CRITICAL_COVERAGE_FAIL'));
  });

  test('fails closed for missing or duplicate critical records', () async {
    final missing = _criticalFiles
        .take(3)
        .map((path) => _record(path, found: 10, hit: 10))
        .join();
    final missingResult = await _runGate(temporaryDirectory, missing);
    expect(missingResult.exitCode, isNot(0));
    expect(missingResult.stderr, contains('records missing'));

    final duplicate =
        _criticalFiles.map((path) => _record(path, found: 10, hit: 10)).join() +
        _record(_criticalFiles.first, found: 10, hit: 10);
    final duplicateResult = await _runGate(temporaryDirectory, duplicate);
    expect(duplicateResult.exitCode, isNot(0));
    expect(duplicateResult.stderr, contains('duplicate LCOV record'));
  });
}
