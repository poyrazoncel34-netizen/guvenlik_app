// ============================================================================
// LEGAL LOG SERVICE — Bozuk dosya recovery regresyon testi
// ============================================================================
// legal_logs.json bir kez bozulduğunda (yarım yazma, manuel düzenleme, şema
// kayması) jsonDecode/cast throw atıyordu; dıştaki try-catch sessizce yutuyor
// ama dosyayı düzeltmiyordu. Sonuçta her açılışta tekrar fail oluyor, KVKK
// audit log kalıcı olarak çalışmaz hale geliyordu (TBK Md. 50 ispat
// kaydı dahil).
//
// _loadLogs artık FormatException/TypeError yakalayıp dosyayı boş geçerli
// container ile yeniden yazıyor; sonraki logEvent çağrıları normal devam
// etmeli.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/legal_log_service.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
  @override
  Future<String?> getApplicationSupportPath() async => documentsPath;
  @override
  Future<String?> getTemporaryPath() async => documentsPath;
  @override
  Future<String?> getApplicationCachePath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File logFile;

  // package_info_plus channel mock — logEvent appVersion için PackageInfo
  // okuyor; native plugin olmadığı için stub'lıyoruz.
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('korubeni_legal_log_test_');
    final fake = _FakePathProvider(tempDir.path);
    // Bypass PluginInterface verification — okay for test-only fakes.
    PathProviderPlatform.instance = fake;
    logFile = File('${tempDir.path}/legal_logs.json');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (
          MethodCall call,
        ) async {
          if (call.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'KoruBeni',
              'packageName': 'com.poyrazoncel.korubeni',
              'version': '1.0.0',
              'buildNumber': '1',
              'buildSignature': '',
              'installerStore': null,
            };
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getLogs returns empty list when file does not exist', () async {
    expect(logFile.existsSync(), isFalse);
    final logs = await LegalLogService.instance.getLogs();
    expect(logs, isEmpty);
  });

  test(
    'getLogs recovers from invalid JSON by rewriting an empty container',
    () async {
      // Half-written file: truncated mid-object.
      await logFile.writeAsString('{"legal_logs": [{"event": "boom"');

      final logs = await LegalLogService.instance.getLogs();

      // First read returns empty because the file was unrecoverable.
      expect(logs, isEmpty);

      // Recovery rewrote the file to a valid empty container — not deleted.
      expect(logFile.existsSync(), isTrue);
      final restored = jsonDecode(await logFile.readAsString());
      expect(restored, isA<Map>());
      expect(
        (restored as Map)['legal_logs'],
        isA<List>(),
        reason:
            'After recovery the file must contain a valid empty legal_logs '
            'array so subsequent writes succeed.',
      );
      expect(restored['legal_logs'], isEmpty);
    },
  );

  test(
    'getLogs recovers when the JSON is valid but the shape is wrong',
    () async {
      // Valid JSON, but legal_logs key is a string instead of a list — would
      // throw TypeError on the old `as List` cast.
      await logFile.writeAsString('{"legal_logs": "not-a-list"}');

      final logs = await LegalLogService.instance.getLogs();
      expect(logs, isEmpty);
      final restored = jsonDecode(await logFile.readAsString());
      expect((restored as Map)['legal_logs'], isA<List>());
    },
  );

  test(
    'logEvent works again after recovery — audit log is not permanently dead',
    () async {
      // Corrupt the file first.
      await logFile.writeAsString('{garbage');

      // First call triggers recovery via _loadLogs (called from logEvent).
      await LegalLogService.instance.logEvent(
        'test_event',
        feature: 'recovery_check',
        result: 'success',
      );

      final logs = await LegalLogService.instance.getLogs();
      expect(
        logs,
        hasLength(1),
        reason:
            'Once the corrupted file is recovered, logEvent must be able to '
            'append normally — otherwise we lose ALL future KVKK records.',
      );
      expect(logs.first['event'], equals('test_event'));
      expect(logs.first['feature'], equals('recovery_check'));
      expect(logs.first['result'], equals('success'));
    },
  );

  test('getLogs preserves well-formed entries', () async {
    // Pre-seed a valid file with one entry.
    final seeded = {
      'legal_logs': [
        {
          'event': 'seeded',
          'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
          'app_version': '1.0.0',
        },
      ],
    };
    await logFile.writeAsString(jsonEncode(seeded));

    final logs = await LegalLogService.instance.getLogs();
    expect(logs, hasLength(1));
    expect(logs.first['event'], equals('seeded'));
  });
}
