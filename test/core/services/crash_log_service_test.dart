import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:guvenlik_app/core/services/crash_log_service.dart';

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
      await service.record(
        source: 'test',
        error: Exception('Test error'),
        stackTrace: StackTrace.current,
      );
      // If we reach here without exception, the test passes.
    });

    test('record accepts null stackTrace without error', () async {
      final service = CrashLogService.instance;
      await service.record(source: 'test', error: 'No stack');
    });

    test('record handles various error types silently', () async {
      final service = CrashLogService.instance;
      await service.record(source: 'test', error: 'string error');
      await service.record(source: 'test', error: Exception('exception'));
      await service.record(source: 'test', error: StateError('state error'));
      // All should be silently handled — no throw.
    });
  });
}
