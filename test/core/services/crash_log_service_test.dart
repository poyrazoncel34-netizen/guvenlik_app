import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/services/crash_log_service.dart';
import 'package:guvenlik_app/core/services/local_logger_service.dart';

void main() {
  group('CrashLogService', () {
    setUp(() async {
      await GetIt.instance.reset();
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    test('instance returns singleton', () {
      final a = CrashLogService.instance;
      final b = CrashLogService.instance;
      expect(identical(a, b), isTrue);
    });

    test('record silently swallows errors when database unavailable', () async {
      // No LocalDatabaseService registered — simulates database failure.
      // record() must not throw; it swallows to protect emergency flow.
      final service = CrashLogService.instance;
      await service.record(LocalErrorCode.flutterFrameworkUnhandled);
      // If we reach here without exception, the test passes.
    });

    test('record accepts allowlisted platform code without error', () async {
      final service = CrashLogService.instance;
      await service.record(LocalErrorCode.platformDispatcherUnhandled);
    });
  });
}
