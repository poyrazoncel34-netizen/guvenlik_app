// Cloud (Claude Code on the web) sessions start from a fresh VM with no Flutter
// SDK and no ssh-keygen. Before scripts/cloud_session_setup.sh existed no such
// session could run `flutter analyze` or `flutter test`, and the tag-trust
// fixture behind release_hardening_contract_test.dart failed for want of
// ssh-keygen. The script is pasted into the cloud environment's Setup script;
// it is deliberately not a .claude/ hook, because
// config/release_change_classification.json keeps .claude/ out of release
// source.
//
// The script is only worth having if it installs the toolchain CI certifies and
// refuses anything else: a session that is green on a different Flutter, or on
// a corrupted download, proves nothing about CI. The pins are checked as data;
// the fail-closed and already-installed paths are checked by running the
// script offline against scratch directories.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _scriptPath = 'scripts/cloud_session_setup.sh';

String _pinnedFlutterVersion() {
  final RegExpMatch? pin = RegExp(
    r'^FLUTTER_VERSION="([^"]+)"$',
    multiLine: true,
  ).firstMatch(File(_scriptPath).readAsStringSync());
  expect(pin, isNotNull, reason: '$_scriptPath pins no Flutter version');
  return pin!.group(1)!;
}

ProcessResult _runSetup(
  Directory scratch, {
  required String archiveUrl,
  String? path,
}) {
  return Process.runSync(
    'bash',
    <String>[_scriptPath],
    environment: <String, String>{
      'FLUTTER_HOME': '${scratch.path}/flutter',
      'BIN_DIR': '${scratch.path}/bin',
      'FLUTTER_ARCHIVE_URL': archiveUrl,
      'PATH': ?path,
    },
  );
}

void _writeExecutable(String path, String body) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync('#!/bin/bash\n$body\n');
  expect(Process.runSync('chmod', <String>['+x', path]).exitCode, 0);
}

void main() {
  test('the setup script installs exactly the Flutter version every '
      'workflow pins', () {
    final String version = _pinnedFlutterVersion();

    final Map<String, String> workflowPins = <String, String>{};
    for (final File workflow in Directory(
      '.github/workflows',
    ).listSync().whereType<File>()) {
      final RegExpMatch? pin = RegExp(
        r'^\s*FLUTTER_VERSION:\s*"([^"]+)"',
        multiLine: true,
      ).firstMatch(workflow.readAsStringSync());
      if (pin != null) {
        workflowPins[workflow.path] = pin.group(1)!;
      }
    }

    expect(workflowPins, isNotEmpty, reason: 'no workflow pins Flutter');
    workflowPins.forEach((String path, String pinned) {
      expect(
        version,
        pinned,
        reason: '$_scriptPath and $path must install the same Flutter',
      );
    });
    expect(
      RegExp(
        r'^FLUTTER_SHA256="[0-9a-f]{64}"$',
        multiLine: true,
      ).hasMatch(File(_scriptPath).readAsStringSync()),
      isTrue,
      reason: 'the SDK archive must be pinned by its published SHA-256',
    );
  });

  test('a download that does not match the pinned checksum is not '
      'installed', () {
    final Directory scratch = Directory.systemTemp.createTempSync('setup-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final File impostor = File('${scratch.path}/impostor.tar.xz')
      ..writeAsStringSync('not the Flutter release archive');

    final ProcessResult result = _runSetup(
      scratch,
      archiveUrl: impostor.uri.toString(),
    );

    expect(result.exitCode, isNot(0), reason: '${result.stderr}');
    expect('${result.stderr}', contains('FAILED'));
    expect(
      scratch.listSync().map((FileSystemEntity entity) => entity.path),
      <String>[impostor.path],
      reason:
          'a rejected download must leave no SDK, no PATH link and no '
          'staging directory behind',
    );
  });

  test('an already-installed pinned SDK is reused and put on PATH', () {
    final Directory scratch = Directory.systemTemp.createTempSync('setup-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final String sdk = '${scratch.path}/flutter';
    final String calls = '${scratch.path}/calls.log';
    _writeExecutable('$sdk/bin/flutter', 'echo "flutter \$*" >> "$calls"');
    _writeExecutable('$sdk/bin/dart', 'echo "dart \$*" >> "$calls"');
    File('$sdk/bin/cache/flutter.version.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{\n  "frameworkVersion": "${_pinnedFlutterVersion()}"\n}\n',
      );
    // Present, so the script never reaches for apt-get from a test run.
    _writeExecutable('${scratch.path}/stubs/ssh-keygen', 'exit 0');

    final ProcessResult result = _runSetup(
      scratch,
      // Any download attempt fails loudly instead of fetching 1.4 GB.
      archiveUrl: 'file://${scratch.path}/no-such-archive.tar.xz',
      path: '${scratch.path}/stubs:${Platform.environment['PATH']}',
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      Link('${scratch.path}/bin/flutter').targetSync(),
      '$sdk/bin/flutter',
    );
    expect(Link('${scratch.path}/bin/dart').targetSync(), '$sdk/bin/dart');
    expect(
      File(calls).readAsLinesSync(),
      containsAll(<String>[
        'flutter config --no-analytics',
        'dart --disable-analytics',
      ]),
    );
  });

  test('the setup script provides the ssh-keygen the tag-trust fixture '
      'shells out to', () {
    expect(
      File('scripts/test_release_tag_trust.py').readAsStringSync(),
      contains("'ssh-keygen'"),
    );
    expect(File(_scriptPath).readAsStringSync(), contains('openssh-client'));
  });
}
