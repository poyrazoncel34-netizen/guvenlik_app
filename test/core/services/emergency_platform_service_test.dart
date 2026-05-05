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

    test(
      'scheduleCheckIn completes gracefully when native side hangs',
      () async {
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
      },
    );
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
    test(
      'executeEmergencyNative returns failed result when native side hangs',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'executeEmergencyNative') {
                await Future.delayed(const Duration(seconds: 30));
                return null;
              }
              return null;
            });

        final service = EmergencyPlatformService.instance;
        final stopwatch = Stopwatch()..start();

        final result = await service.executeEmergencyNative(
          primaryNumber: '5551234567',
        );

        expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(6));
        expect(result.isFailed, isTrue);
        stopwatch.stop();
      },
    );
    test(
      'scheduleCountdownAlarm returns false when native side hangs',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'scheduleCountdownAlarm') {
                await Future.delayed(const Duration(seconds: 30));
                return null;
              }
              return null;
            });

        final service = EmergencyPlatformService.instance;
        final stopwatch = Stopwatch()..start();

        final result = await service.scheduleCountdownAlarm(
          deadline: DateTime.now().add(const Duration(seconds: 10)),
          primaryNumber: '5551234567',
          dispatchId: 'test-dispatch',
        );

        expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(6));
        expect(result, isFalse);
        stopwatch.stop();
      },
    );

    test(
      'map invocations fail closed on unexpected native exceptions',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              throw MissingPluginException('${call.method} not implemented');
            });

        final missingPluginResult = await EmergencyPlatformService.instance
            .executeEmergencyNative(primaryNumber: '5551234567');
        expect(missingPluginResult.isFailed, isTrue);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              throw Exception('${call.method} failed');
            });

        final genericResult = await EmergencyPlatformService.instance
            .scheduleCheckIn(
              phase: 'main',
              deadline: DateTime.now().add(const Duration(minutes: 10)),
            );
        expect(genericResult, isFalse);
      },
    );

    test(
      'bool invocations fail closed on unexpected native exceptions',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              throw MissingPluginException('${call.method} not implemented');
            });

        final missingPluginResult = await EmergencyPlatformService.instance
            .canScheduleExactAlarms();
        expect(missingPluginResult, isFalse);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              throw Exception('${call.method} failed');
            });

        final genericResult = await EmergencyPlatformService.instance
            .didCountdownAlarmFire(dispatchId: 'test-dispatch');
        expect(genericResult, isFalse);
      },
    );
  });
}
