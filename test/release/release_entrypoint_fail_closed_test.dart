import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release entrypoints fail closed', () {
    test('Fastlane cannot build or upload a Play artifact', () {
      final fastfile = File('android/fastlane/Fastfile').readAsStringSync();

      expect(fastfile, contains('UI.user_error!'));
      expect(fastfile, contains('canonical tagged GitHub release workflow'));
      expect(fastfile, isNot(contains('flutter build appbundle')));
      expect(fastfile, isNot(contains('upload_to_play_store(')));
      expect(fastfile, isNot(contains('supply(')));
    });

    test('every owned AAB signature check uses jarsigner strict mode', () {
      final sources = <String, String>{
        for (final path in [
          'scripts/build_production.sh',
          'scripts/verify_release.sh',
          '.github/workflows/release.yml',
        ])
          path: File(path).readAsStringSync(),
      };

      for (final entry in sources.entries) {
        final allVerifications = RegExp(
          r'jarsigner\s+-verify(?:\s|$)',
        ).allMatches(entry.value).length;
        final strictVerifications = RegExp(
          r'jarsigner\s+-verify\s+-strict(?:\s|$)',
        ).allMatches(entry.value).length;

        expect(
          allVerifications,
          greaterThan(0),
          reason: '${entry.key} must verify its AAB signature.',
        );
        expect(
          strictVerifications,
          allVerifications,
          reason: '${entry.key} has a non-strict jarsigner verification.',
        );
        expect(
          entry.value,
          allOf(
            contains(r'"$SIGNATURE_STATUS" -ne 0'),
            contains(r'"$SIGNATURE_STATUS" -ne 4'),
          ),
          reason:
              '${entry.key} must reject every strict bit except self-signed chain bit 4.',
        );
      }
    });

    test(
      'shell entrypoints capture allowed jarsigner status inside a condition',
      () {
        for (final path in <String>[
          'scripts/build_production.sh',
          'scripts/verify_release.sh',
        ]) {
          final source = File(path).readAsStringSync();
          expect(
            source,
            contains('if LC_ALL=C jarsigner -verify -strict'),
            reason:
                '$path must place jarsigner in an if-condition so errexit/ERR '
                'traps cannot abort before strict status 4 is inspected.',
          );
          expect(
            source,
            isNot(contains('set +e\nLC_ALL=C jarsigner -verify -strict')),
            reason:
                '$path must not globally suspend errexit for signature checks.',
          );
        }
      },
    );

    test('signature checks accept both successful jarsigner message forms', () {
      for (final path in <String>[
        'scripts/build_production.sh',
        'scripts/verify_release.sh',
        '.github/workflows/release.yml',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains("grep -Eq '^jar verified([,.]|\$)'"),
          reason:
              '$path must accept both `jar verified.` and the strict bit-4 '
              '`jar verified, with signer errors.` result.',
        );
      }
    });

    test(
      'strict jarsigner detects an unsigned entry appended after signing',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'korubeni-strict-signature-',
        );
        addTearDown(() => directory.delete(recursive: true));
        const fixtureCredential = 'korubeni-test-only-password';
        final payload = File('${directory.path}/payload.txt')
          ..writeAsStringSync('signed');
        final unsigned = File('${directory.path}/unsigned.txt')
          ..writeAsStringSync('appended');
        final keyStore = File('${directory.path}/test-upload.jks');
        final archive = File('${directory.path}/candidate.jar');

        await _runChecked('keytool', <String>[
          '-genkeypair',
          '-alias',
          'upload',
          '-keyalg',
          'RSA',
          '-keysize',
          '2048',
          '-validity',
          '3650',
          '-dname',
          'CN=KoruBeni Strict Test',
          '-keystore',
          keyStore.path,
          '-storepass',
          fixtureCredential,
          '-keypass',
          fixtureCredential,
          '-noprompt',
        ]);
        await _runChecked('jar', <String>[
          '--create',
          '--file',
          archive.path,
          '-C',
          directory.path,
          payload.uri.pathSegments.last,
        ]);
        await _runChecked('jarsigner', <String>[
          '-keystore',
          keyStore.path,
          '-storepass',
          fixtureCredential,
          '-keypass',
          fixtureCredential,
          archive.path,
          'upload',
        ]);
        await _runChecked('jar', <String>[
          '--update',
          '--file',
          archive.path,
          '-C',
          directory.path,
          unsigned.uri.pathSegments.last,
        ]);

        final verification = await Process.run('jarsigner', <String>[
          '-verify',
          '-strict',
          archive.path,
        ]);

        expect(verification.exitCode & 16, 16);
      },
    );
  });
}

Future<void> _runChecked(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw StateError('$executable failed: ${result.stdout}\n${result.stderr}');
  }
}
