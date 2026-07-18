import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dirty release source is completely classified and fail-closed',
    () async {
      final outputDirectory = await Directory.systemTemp.createTemp(
        'korubeni-change-classification-',
      );
      addTearDown(() => outputDirectory.delete(recursive: true));
      final output = File('${outputDirectory.path}/classification.json');

      final result = await Process.run('python3', [
        'scripts/verify_release_change_classification.py',
        '--config',
        'config/release_change_classification.json',
        '--output',
        output.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final payload =
          jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
      final entries = (payload['entries'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(entries, isNotEmpty);
      expect(payload['unclassifiedCount'], 0);
      expect(payload['forbiddenStagedCount'], 0);
      expect(payload['gitHead'], matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(payload['statusSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));

      final byPath = {
        for (final entry in entries) entry['path'] as String: entry,
      };
      expect(byPath['AGENTS.md']?['category'], 'tooling');
      expect(
        entries
            .where((entry) => (entry['path'] as String).startsWith('.agents/'))
            .every((entry) => entry['category'] == 'tooling'),
        isTrue,
      );
      expect(
        entries
            .where((entry) => (entry['path'] as String).startsWith('.codex/'))
            .every((entry) => entry['category'] == 'tooling'),
        isTrue,
      );
    },
  );

  test(
    'staged tooling is rejected instead of silently entering release',
    () async {
      final repository = await Directory.systemTemp.createTemp(
        'korubeni-classification-repo-',
      );
      addTearDown(() => repository.delete(recursive: true));
      final tooling = File('${repository.path}/.agents/private.txt');
      tooling.parent.createSync(recursive: true);
      tooling.writeAsStringSync('local-only tooling');

      expect(
        (await Process.run('git', [
          'init',
        ], workingDirectory: repository.path)).exitCode,
        0,
      );
      expect(
        (await Process.run('git', [
          'add',
          '.agents/private.txt',
        ], workingDirectory: repository.path)).exitCode,
        0,
      );

      final result = await Process.run('python3', [
        File('scripts/verify_release_change_classification.py').absolute.path,
        '--repo',
        repository.path,
        '--config',
        File('config/release_change_classification.json').absolute.path,
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('FORBIDDEN_STAGED_PATH'));
      expect(result.stderr, contains('.agents/private.txt'));
    },
  );

  test('staged deletion removes legacy tooling from release source', () async {
    final repository = await Directory.systemTemp.createTemp(
      'korubeni-classification-delete-',
    );
    addTearDown(() => repository.delete(recursive: true));
    final tooling = File('${repository.path}/.codex/environment.toml');
    tooling.parent.createSync(recursive: true);
    tooling.writeAsStringSync('local-only tooling');

    expect(
      (await Process.run('git', [
        'init',
      ], workingDirectory: repository.path)).exitCode,
      0,
    );
    expect(
      (await Process.run('git', [
        'add',
        '.codex/environment.toml',
      ], workingDirectory: repository.path)).exitCode,
      0,
    );
    expect(
      (await Process.run('git', [
        '-c',
        'user.name=KoruBeni Test',
        '-c',
        'user.email=test@localhost',
        'commit',
        '-m',
        'fixture',
      ], workingDirectory: repository.path)).exitCode,
      0,
    );
    tooling.deleteSync();
    expect(
      (await Process.run('git', [
        'add',
        '-u',
      ], workingDirectory: repository.path)).exitCode,
      0,
    );

    final output = File('${repository.path}/classification.json');
    final result = await Process.run('python3', [
      File('scripts/verify_release_change_classification.py').absolute.path,
      '--repo',
      repository.path,
      '--config',
      File('config/release_change_classification.json').absolute.path,
      '--output',
      output.path,
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final payload =
        jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    final entry = (payload['entries'] as List<dynamic>).single;
    expect(payload['forbiddenStagedCount'], 0);
    expect(entry['path'], '.codex/environment.toml');
    expect(entry['status'], 'D ');
    expect(entry['staged'], isTrue);
    expect(entry['category'], 'tooling');
  });
}
