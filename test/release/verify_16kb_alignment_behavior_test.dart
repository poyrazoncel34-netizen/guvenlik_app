import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('16 KB AAB alignment verifier', () {
    test(
      'checks native libraries in base and dynamic-feature modules',
      () async {
        final fixture = await _AabFixture.create();
        addTearDown(fixture.dispose);
        await fixture.addElf(
          'base/lib/arm64-v8a/libbase.so',
          alignment: 0x4000,
        );
        await fixture.addElf(
          'safetyfeature/lib/arm64-v8a/libfeature.so',
          alignment: 0x4000,
        );
        final aab = await fixture.pack();

        final result = await _verify(aab);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout, contains('ALIGNMENT_PASS checked=2 modules=all'));
      },
    );

    test('fails when a dynamic-feature library is only 4 KB aligned', () async {
      final fixture = await _AabFixture.create();
      addTearDown(fixture.dispose);
      await fixture.addElf('base/lib/arm64-v8a/libbase.so', alignment: 0x4000);
      await fixture.addElf(
        'feature/lib/arm64-v8a/libbad.so',
        alignment: 0x1000,
      );
      final aab = await fixture.pack();

      final result = await _verify(aab);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('feature/lib/arm64-v8a/libbad.so'));
      expect(result.stderr, contains('need >=0x4000'));
    });

    test('no native library is missing evidence, not a pass', () async {
      final fixture = await _AabFixture.create();
      addTearDown(fixture.dispose);
      await fixture.addText('base/manifest/AndroidManifest.xml', 'fixture');
      final aab = await fixture.pack();

      final result = await _verify(aab);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('no native libraries found'));
    });

    test('unexpected 32-bit ABI fails the production boundary', () async {
      final fixture = await _AabFixture.create();
      addTearDown(fixture.dispose);
      await fixture.addElf(
        'base/lib/armeabi-v7a/libunexpected.so',
        alignment: 0x4000,
      );
      final aab = await fixture.pack();

      final result = await _verify(aab);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('unexpected ABI armeabi-v7a'));
    });
  });
}

Future<ProcessResult> _verify(File aab) => Process.run('bash', <String>[
  'scripts/verify_16kb_alignment.sh',
  aab.path,
], workingDirectory: Directory.current.path);

class _AabFixture {
  _AabFixture._(this.root);

  final Directory root;
  Directory get payload => Directory('${root.path}/payload');

  static Future<_AabFixture> create() async {
    final root = await Directory.systemTemp.createTemp('korubeni-16kb-');
    await Directory('${root.path}/payload').create();
    return _AabFixture._(root);
  }

  Future<void> addText(String path, String value) async {
    final file = File('${payload.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(value);
  }

  Future<void> addElf(String path, {required int alignment}) async {
    final bytes = Uint8List(120);
    bytes.setRange(0, 6, <int>[0x7f, 0x45, 0x4c, 0x46, 2, 1]);
    final data = ByteData.sublistView(bytes);
    data.setUint64(32, 64, Endian.little);
    data.setUint16(54, 56, Endian.little);
    data.setUint16(56, 1, Endian.little);
    data.setUint32(64, 1, Endian.little);
    data.setUint64(112, alignment, Endian.little);
    final file = File('${payload.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  Future<File> pack() async {
    final archive = File('${root.path}/fixture.aab');
    final result = await Process.run('zip', <String>[
      '-q',
      '-r',
      archive.path,
      '.',
    ], workingDirectory: payload.path);
    if (result.exitCode != 0) {
      throw StateError('zip failed: ${result.stdout}\n${result.stderr}');
    }
    return archive;
  }

  Future<void> dispose() => root.delete(recursive: true);
}
