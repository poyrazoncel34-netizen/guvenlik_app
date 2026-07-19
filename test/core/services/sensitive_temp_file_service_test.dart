import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/sensitive_temp_file_service.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('korubeni-export-test-');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('purge deletes only KoruBeni PII export files', () async {
    final legacy = File(
      '${sandbox.path}/${SensitiveTempFileService.legacyExportName}',
    );
    final timestamped = File(
      '${sandbox.path}/${SensitiveTempFileService.exportPrefix}123.json',
    );
    final wrongExtension = File(
      '${sandbox.path}/${SensitiveTempFileService.exportPrefix}123.txt',
    );
    final unrelated = File('${sandbox.path}/unrelated.json');
    await Future.wait(<Future<File>>[
      legacy.writeAsString('phone=+905551112233'),
      timestamped.writeAsString('phone=+905551112233'),
      wrongExtension.writeAsString('keep'),
      unrelated.writeAsString('keep'),
    ]);

    await SensitiveTempFileService.purgeStaleExportsInDirectory(sandbox);

    expect(await legacy.exists(), isFalse);
    expect(await timestamped.exists(), isFalse);
    expect(await wrongExtension.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  test('purge never follows a matching-name symlink', () async {
    if (Platform.isWindows) return;
    final outside = File('${sandbox.parent.path}/korubeni-export-target.txt');
    await outside.writeAsString('must survive');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });
    final link = Link(
      '${sandbox.path}/${SensitiveTempFileService.exportPrefix}linked.json',
    );
    await link.create(outside.path);

    await SensitiveTempFileService.purgeStaleExportsInDirectory(sandbox);

    expect(await link.exists(), isTrue);
    expect(await outside.readAsString(), 'must survive');
  });

  test('purge and direct delete are idempotent', () async {
    final export = File(
      '${sandbox.path}/${SensitiveTempFileService.exportPrefix}456.json',
    );
    await export.writeAsString('sensitive');

    await SensitiveTempFileService.delete(export);
    await SensitiveTempFileService.delete(export);
    await SensitiveTempFileService.delete(null);
    await SensitiveTempFileService.purgeStaleExportsInDirectory(sandbox);
    await SensitiveTempFileService.purgeStaleExportsInDirectory(sandbox);

    expect(await export.exists(), isFalse);
  });

  test('startup and both export surfaces retain cleanup hooks', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(
      mainSource,
      contains('SensitiveTempFileService.purgeStaleExports()'),
    );

    for (final path in <String>[
      'lib/screens/settings_detail_page.dart',
      'lib/screens/settings_legal/data_export_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('finally {'), reason: path);
      expect(
        source,
        contains('SensitiveTempFileService.delete(exportFile)'),
        reason: path,
      );
    }
  });
}
