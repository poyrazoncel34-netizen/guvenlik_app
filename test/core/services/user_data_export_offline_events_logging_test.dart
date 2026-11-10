import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/local_logger_service.dart';
import 'package:guvenlik_app/core/services/user_data_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A corrupt entry in the offline event queue used to vanish from the export
/// through an empty `catch (_) {}`: the user received a copy that was silently
/// shorter than their record, and nothing anywhere said why.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  // LocalLoggerService is a process singleton that binds its file once, so
  // the directory lives for the whole file and each test only clears it.
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('korubeni-export-log-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    await LocalLoggerService.instance.initialize();
  });

  setUp(() => LocalLoggerService.instance.clearLogs());

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await dir.delete(recursive: true);
  });

  test(
    'a corrupt offline queue entry is skipped AND recorded locally',
    () async {
      SharedPreferences.setMockInitialValues({
        'offline_event_queue': <String>[
          '{"type":"check_in","timestamp":1}',
          '{not json',
        ],
      });
      final prefs = await SharedPreferences.getInstance();

      final events = await UserDataExportService.offlineEventsForExport(prefs);

      expect(events, hasLength(1));
      expect(events.single['type'], 'check_in');
      final logs = await LocalLoggerService.instance.readLogs();
      expect(logs, contains('export_offline_event_unreadable'));
      // The record carries the fact only, never the raw entry.
      expect(logs, isNot(contains('{not json')));
    },
  );

  test('a clean queue writes no warning', () async {
    SharedPreferences.setMockInitialValues({
      'offline_event_queue': <String>['{"type":"check_in","timestamp":1}'],
    });
    final prefs = await SharedPreferences.getInstance();

    final events = await UserDataExportService.offlineEventsForExport(prefs);

    expect(events, hasLength(1));
    expect(
      await LocalLoggerService.instance.readLogs(),
      isNot(contains('export_offline_event_unreadable')),
    );
  });
}
