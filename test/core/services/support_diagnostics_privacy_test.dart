import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/local_logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual diagnostic file contains codes but no supplied personal data',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'korubeni-synthetic-logs-',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await dir.delete(recursive: true);
      });
      final logger = LocalLoggerService.instance;
      await logger.initialize();
      await logger.clearLogs();
      const sensitive = [
        'Sentetik Kisi',
        '+905551234567',
        'sentetik@example.invalid',
        'PIN=4827',
        '41.12345, 29.54321',
      ];
      // Free-form informational diagnostics are debug-only. Even when a caller
      // supplies personal values, the persistent support boundary accepts codes.
      logger.info('synthetic', sensitive.join(' '));
      await logger.errorCode(LocalErrorCode.platformDispatcherUnhandled);
      await logger.warningCode(LocalWarningCode.safetyAlertNotDelivered);
      final actual = await logger.readLogs();
      expect(actual, contains('platform_dispatcher_unhandled'));
      expect(actual, contains('safety_alert_not_delivered'));
      for (final value in sensitive) {
        expect(actual, isNot(contains(value)));
      }
      expect(
        await File('${dir.path}/korubeni_errors.log').readAsString(),
        actual,
      );
    },
  );
}
