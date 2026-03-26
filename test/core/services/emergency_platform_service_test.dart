import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';

/// Tests for emergency platform service timeout behavior (C3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.poyrazoncel.korubeni/emergency_platform');

  group('EmergencyPlatformService timeouts', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('scheduleCheckIn completes gracefully when native side hangs', () async {
      // Simulate a hanging native call that never returns
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'scheduleCheckIn') {
          await Future.delayed(const Duration(seconds: 30));
          return null;
        }
        return null;
      });

      final service = EmergencyPlatformService.instance;
      final stopwatch = Stopwatch()..start();

      // Must complete within 6 seconds (not hang for 30) and not throw
      await service.scheduleCheckIn(
        phase: 'main',
        deadline: DateTime.now().add(const Duration(minutes: 10)),
      );

      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(6));
      stopwatch.stop();
    });
    test('cancelCheckIn completes gracefully when native side hangs', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'cancelCheckIn') {
          await Future.delayed(const Duration(seconds: 30));
          return null;
        }
        return null;
      });

      final service = EmergencyPlatformService.instance;
      final stopwatch = Stopwatch()..start();

      await service.cancelCheckIn();

      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(6));
      stopwatch.stop();
    });
    test('sendSms returns empty map when native side hangs', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sendSms') {
          await Future.delayed(const Duration(seconds: 30));
          return null;
        }
        return null;
      });

      final service = EmergencyPlatformService.instance;
      final stopwatch = Stopwatch()..start();

      final result = await service.sendSms(
        recipients: ['5551234567'],
        message: 'test emergency',
      );

      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(6));
      expect(result, isA<Map<String, dynamic>>());
      stopwatch.stop();
    });
    test('triggerEmergency returns empty map when native side hangs', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'triggerEmergency') {
          await Future.delayed(const Duration(seconds: 30));
          return null;
        }
        return null;
      });

      final service = EmergencyPlatformService.instance;
      final stopwatch = Stopwatch()..start();

      final result = await service.triggerEmergency(
        recipients: ['5551234567'],
        message: 'test emergency',
        primaryNumber: '5551234567',
      );

      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(6));
      expect(result, isA<Map<String, dynamic>>());
      stopwatch.stop();
    });
  });
}
