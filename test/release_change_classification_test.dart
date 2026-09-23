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

      expect(payload['entryCount'], entries.length);
      expect(payload['unclassifiedCount'], 0);
      expect(payload['forbiddenStagedCount'], 0);
      expect(payload['gitHead'], matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(payload['statusSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        entries.every(
          (entry) =>
              (entry['category'] as String?)?.isNotEmpty == true &&
              (entry['commitGroup'] as String?)?.isNotEmpty == true &&
              (entry['reason'] as String?)?.isNotEmpty == true,
        ),
        isTrue,
      );
    },
  );

  test('untracked local agent files are classified as tooling', () async {
    final repository = await Directory.systemTemp.createTemp(
      'korubeni-classification-tooling-',
    );
    addTearDown(() => repository.delete(recursive: true));
    File(
      '${repository.path}/AGENTS.md',
    ).writeAsStringSync('local instructions');

    expect(
      (await Process.run('git', [
        'init',
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
    expect(payload['unclassifiedCount'], 0);
    expect(entry['path'], 'AGENTS.md');
    expect(entry['staged'], isFalse);
    expect(entry['category'], 'tooling');
    expect(entry['commitGroup'], 'EXCLUDE');
  });

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

  // A-033: the dirty-only gate classifies ZERO paths on a clean tree, so its
  // PASS there proved nothing. 35 tracked files -- VolumeButtonDetector.kt and
  // the play manifest among them -- matched no rule and stayed invisible until
  // someone edited one, at which point the whole suite went red for a reason
  // unrelated to the edit. These tests hold the gate to the whole index.
  group('--all-tracked', () {
    Future<ProcessResult> classify(
      String repo,
      String output, {
      required bool allTracked,
    }) => Process.run('python3', [
      File('scripts/verify_release_change_classification.py').absolute.path,
      '--repo',
      repo,
      '--config',
      File('config/release_change_classification.json').absolute.path,
      '--output',
      output,
      if (allTracked) '--all-tracked',
    ]);

    Future<Directory> committedFixture(String relativePath) async {
      final repository = await Directory.systemTemp.createTemp(
        'korubeni-classification-tracked-',
      );
      final file = File('${repository.path}/$relativePath');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('fixture');
      for (final arguments in <List<String>>[
        ['init'],
        ['add', relativePath],
        [
          '-c',
          'user.name=KoruBeni Test',
          '-c',
          'user.email=test@localhost',
          'commit',
          '-m',
          'fixture',
        ],
      ]) {
        final result = await Process.run(
          'git',
          arguments,
          workingDirectory: repository.path,
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }
      return repository;
    }

    test('every tracked path in this repository is classified', () async {
      final outputDirectory = await Directory.systemTemp.createTemp(
        'korubeni-change-classification-all-',
      );
      addTearDown(() => outputDirectory.delete(recursive: true));
      final output = File('${outputDirectory.path}/classification.json');

      final result = await classify(
        Directory.current.path,
        output.path,
        allTracked: true,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final payload =
          jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
      final tracked = (await Process.run('git', [
        'ls-files',
        '-z',
      ])).stdout.toString().split('\u0000').where((p) => p.isNotEmpty);

      expect(payload['scope'], 'all-tracked');
      expect(
        payload['trackedCount'],
        tracked.length,
        reason: 'the gate must see the same index git does',
      );
      expect(
        (payload['entryCount'] as int) >= tracked.length,
        isTrue,
        reason: 'every tracked path must produce an entry, not just dirty ones',
      );
      expect(payload['unclassifiedCount'], 0);
      expect(payload['forbiddenTrackedCount'], 0);
    });

    test('a tracked path no rule covers passes the dirty gate but fails '
        'this one', () async {
      final repository = await committedFixture('unmatched/fixture.bin');
      addTearDown(() => repository.delete(recursive: true));
      // Outside the fixture repo, so the report is never itself a dirty path.
      final outputDirectory = await Directory.systemTemp.createTemp(
        'korubeni-classification-unmatched-out-',
      );
      addTearDown(() => outputDirectory.delete(recursive: true));
      final output = '${outputDirectory.path}/classification.json';

      // The blind spot, reproduced: a clean tree gives the dirty-only gate
      // nothing to classify, so it passes.
      final dirtyOnly = await classify(
        repository.path,
        output,
        allTracked: false,
      );
      expect(dirtyOnly.exitCode, 0, reason: '${dirtyOnly.stderr}');
      expect(dirtyOnly.stdout, contains('classified_paths=0'));

      final allTracked = await classify(
        repository.path,
        output,
        allTracked: true,
      );
      expect(allTracked.exitCode, 1);
      expect(
        allTracked.stderr,
        contains('UNCLASSIFIED_PATH unmatched/fixture.bin'),
      );
    });

    test(
      'committed local tooling is rejected, not just staged tooling',
      () async {
        final repository = await committedFixture('.agents/private.txt');
        addTearDown(() => repository.delete(recursive: true));
        // Outside the fixture repo, so the report is never itself a dirty path.
        final outputDirectory = await Directory.systemTemp.createTemp(
          'korubeni-classification-tooling-out-',
        );
        addTearDown(() => outputDirectory.delete(recursive: true));
        final output = '${outputDirectory.path}/classification.json';

        final result = await classify(
          repository.path,
          output,
          allTracked: true,
        );
        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains('FORBIDDEN_TRACKED_PATH .agents/private.txt'),
        );
      },
    );
  });
}
