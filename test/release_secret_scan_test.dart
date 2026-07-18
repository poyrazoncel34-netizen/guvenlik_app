import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('korubeni-secret-scan-');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  Future<ProcessResult> scan() => Process.run('python3', <String>[
    'scripts/scan_release_secrets.py',
    '--repo',
    temp.path,
    '--classification',
    '${temp.path}/classification.json',
    '--output',
    '${temp.path}/secret-scan.json',
  ]);

  void writeClassification(String path) {
    File('${temp.path}/classification.json').writeAsStringSync(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'statusSha256': 'a' * 64,
        'entries': <Object?>[
          <String, Object?>{
            'path': path,
            'status': '??',
            'category': 'release',
            'commitGroup': '04-ci-evidence-security',
          },
        ],
      }),
    );
  }

  test('fails without printing the matched credential value', () async {
    const path = 'candidate.txt';
    final credential = 'AKIA${'A' * 16}';
    File('${temp.path}/$path').writeAsStringSync('value=$credential\n');
    writeClassification(path);

    final result = await scan();

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('candidate.txt:1: aws-access-key'));
    expect(result.stderr, isNot(contains(credential)));
  });

  test(
    'allows secret-manager expressions without treating them as values',
    () async {
      const path = 'workflow.yml';
      File('${temp.path}/$path').writeAsStringSync(
        'API_KEY: "\${{ secrets.REVENUECAT_ANDROID_API_KEY }}"\n',
      );
      writeClassification(path);

      final result = await scan();

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report =
          jsonDecode(File('${temp.path}/secret-scan.json').readAsStringSync())
              as Map<String, dynamic>;
    expect(report['status'], 'PASS');
    expect(report['scannedTextFileCount'], 1);
    expect(report['findingCount'], 0);
    expect(
      report['contentSetSha256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    },
  );

  test('release workflow runs the scan before building the AAB', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final scanIndex = workflow.indexOf('scan_release_secrets.py');
    final buildIndex = workflow.indexOf('      - name: Build signed Play AAB');

    expect(scanIndex, greaterThanOrEqualTo(0));
    expect(buildIndex, greaterThan(scanIndex));
    expect(
      workflow,
      contains('secretScan=build/release-evidence/secret-scan.json'),
    );
  });
}
