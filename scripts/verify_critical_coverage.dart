import 'dart:convert';
import 'dart:io';

const int _minimumPercent = 90;
const List<String> _criticalFiles = <String>[
  'lib/core/services/emergency_session_contract.dart',
  'lib/core/services/emergency_platform_service.dart',
  'lib/core/services/pin_verification_service.dart',
  'lib/core/services/check_in_service.dart',
  'lib/core/services/contact_service.dart',
];

Never _fail(String message) {
  stderr.writeln('CRITICAL_COVERAGE_FAIL: $message');
  exit(1);
}

void main(List<String> arguments) {
  var lcovPath = 'coverage/lcov.info';
  String? reportPath;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--lcov' && index + 1 < arguments.length) {
      lcovPath = arguments[++index];
    } else if (argument == '--report' && index + 1 < arguments.length) {
      reportPath = arguments[++index];
    } else {
      _fail('unknown or incomplete argument: $argument');
    }
  }

  final lcov = File(lcovPath);
  if (!lcov.existsSync() || lcov.lengthSync() == 0) {
    _fail('missing or empty LCOV file: $lcovPath');
  }

  final records = <String, _CoverageRecord>{};
  String? sourceFile;
  int? linesFound;
  int? linesHit;

  void finishRecord() {
    final source = sourceFile;
    if (source == null) return;
    final normalized = source.replaceAll('\\', '/');
    final criticalMatches = _criticalFiles
        .where(
          (critical) =>
              normalized == critical || normalized.endsWith('/$critical'),
        )
        .toList(growable: false);
    if (criticalMatches.length > 1) {
      _fail('ambiguous critical source path: $source');
    }
    if (criticalMatches.isNotEmpty) {
      final critical = criticalMatches.single;
      if (records.containsKey(critical)) {
        _fail('duplicate LCOV record for $critical');
      }
      if (linesFound == null || linesHit == null) {
        _fail('LF/LH totals missing for $critical');
      }
      if (linesFound! <= 0 || linesHit! < 0 || linesHit! > linesFound!) {
        _fail(
          'invalid LF/LH totals for $critical: LH=$linesHit LF=$linesFound',
        );
      }
      records[critical] = _CoverageRecord(
        path: critical,
        linesFound: linesFound!,
        linesHit: linesHit!,
      );
    }
    sourceFile = null;
    linesFound = null;
    linesHit = null;
  }

  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      finishRecord();
      sourceFile = line.substring(3);
    } else if (line.startsWith('LF:')) {
      linesFound = int.tryParse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit = int.tryParse(line.substring(3));
    } else if (line == 'end_of_record') {
      finishRecord();
    }
  }
  finishRecord();

  final missing = _criticalFiles
      .where((critical) => !records.containsKey(critical))
      .toList(growable: false);
  if (missing.isNotEmpty) {
    _fail('critical source records missing: ${missing.join(', ')}');
  }

  var failed = false;
  final ordered = _criticalFiles
      .map((critical) => records[critical]!)
      .toList(growable: false);
  for (final record in ordered) {
    final passes = record.linesHit * 100 >= record.linesFound * _minimumPercent;
    stdout.writeln(
      '${passes ? 'PASS' : 'FAIL'} '
      '${record.path}: ${record.percent.toStringAsFixed(2)}% '
      '(LH=${record.linesHit}, LF=${record.linesFound}, min=$_minimumPercent%)',
    );
    failed |= !passes;
  }

  if (reportPath != null) {
    final report = File(reportPath);
    report.parent.createSync(recursive: true);
    report.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{'schemaVersion': 1, 'minimumLineCoveragePercent': _minimumPercent, 'result': failed ? 'FAIL' : 'PASS', 'files': ordered.map((record) => record.toJson()).toList()})}\n',
      flush: true,
    );
  }

  if (failed) {
    _fail('one or more critical safety modules are below $_minimumPercent%');
  }
  stdout.writeln('CRITICAL_COVERAGE_PASS');
}

class _CoverageRecord {
  const _CoverageRecord({
    required this.path,
    required this.linesFound,
    required this.linesHit,
  });

  final String path;
  final int linesFound;
  final int linesHit;

  double get percent => linesHit * 100 / linesFound;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'linesFound': linesFound,
    'linesHit': linesHit,
    'lineCoveragePercent': double.parse(percent.toStringAsFixed(2)),
  };
}
