import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('emergency_readiness_behavior_test');

  Map<String, Object?> readyState() => <String, Object?>{
    'supportedOs': true,
    'telephonyCalling': true,
    'telecomAvailable': true,
    'dialHandlerAvailable': true,
    'batteryOptimizationsIgnored': true,
    'canScheduleExactAlarms': true,
    'callPermissionGranted': true,
    'notificationsEnabled': true,
    'alertChannelHigh': true,
  };

  late EmergencyPlatformService platform;
  late EmergencyReadinessService readiness;

  setUp(() {
    platform = EmergencyPlatformService.forTesting(
      methodChannel: channel,
      defaultTimeout: const Duration(milliseconds: 20),
    );
    readiness = EmergencyReadinessService.forTesting(
      platformService: platform,
      timeout: const Duration(milliseconds: 40),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'typed platform readiness accepts only a complete native snapshot',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getDeviceState');
            return readyState();
          });

      final state = await platform.getPlatformReadiness();

      expect(state.isKnown, isTrue);
      expect(state.backgroundAlertReady, isTrue);
      expect(state.automaticCallReady, isTrue);
      expect(state.criticalSafetyReady, isTrue);
      expect(state.batteryOptimizationWhitelisted, isTrue);
    },
  );

  test('every critical capability independently blocks ready state', () async {
    for (final capability in <String>[
      'supportedOs',
      'telephonyCalling',
      'telecomAvailable',
      'dialHandlerAvailable',
      'canScheduleExactAlarms',
      'callPermissionGranted',
      'notificationsEnabled',
      'alertChannelHigh',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return readyState()..[capability] = false;
          });

      final state = await readiness.checkReadiness();

      expect(
        state.criticalSafetyReady,
        isFalse,
        reason: '$capability=false must never be reported ready',
      );
    }
  });

  test(
    'battery optimization remains a degraded-mode signal, not an arm gate',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                readyState()..['batteryOptimizationsIgnored'] = false,
          );

      final state = await readiness.checkReadiness();

      expect(state.batteryOptimizationWhitelisted, isFalse);
      expect(state.criticalSafetyReady, isTrue);
    },
  );

  test('missing, malformed and timed-out state fail closed', () async {
    for (final response in <Object?>[
      <String, Object?>{},
      readyState()..remove('alertChannelHigh'),
      readyState()..['telecomAvailable'] = 'yes',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => response);

      final state = await readiness.checkReadiness();

      expect(state.isKnown, isFalse);
      expect(state.criticalSafetyReady, isFalse);
    }

    final never = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => never.future);

    final timedOut = await readiness.checkReadiness();
    expect(timedOut.isKnown, isFalse);
    expect(timedOut.criticalSafetyReady, isFalse);
  });

  test('an older readiness probe cannot overwrite a newer result', () async {
    final firstResponse = Completer<Object?>();
    var invocation = 0;
    var notifications = 0;
    readiness.addListener(() => notifications++);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          invocation++;
          if (invocation == 1) return firstResponse.future;
          return readyState()..['telecomAvailable'] = false;
        });

    final olderProbe = readiness.checkReadiness();
    await Future<void>.delayed(Duration.zero);
    final newerState = await readiness.checkReadiness();
    expect(newerState.criticalSafetyReady, isFalse);

    firstResponse.complete(readyState());
    await olderProbe;

    expect(readiness.lastState?.criticalSafetyReady, isFalse);
    expect(notifications, 1);
  });
}
