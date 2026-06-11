import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizePhoneNumber', () {
    test('removes dots from phone number', () {
      expect(normalizePhoneNumber('0536.449.90.39'), '05364499039');
    });
  });

  // Audit F5: every number crossing the platform channel passes through the
  // single shared normalizer, so the native side never persists/dials a raw
  // formatted number while the Dart call path dials a normalized one.
  group('platform-channel boundary normalization (audit F5)', () {
    const channel = MethodChannel(
      'com.poyrazoncel.korubeni/emergency_platform',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'source contract: the three channel methods normalize their number',
      () {
        final source = File(
          'lib/core/services/emergency_platform_service.dart',
        ).readAsStringSync();

        expect(
          source.contains('normalizePhoneNumber'),
          isTrue,
          reason:
              'EmergencyPlatformService must be the normalization '
              'chokepoint for numbers crossing the channel',
        );
        expect(
          source.contains("import 'android_intent_service.dart';"),
          isTrue,
          reason: 'normalizer comes from the shared AndroidIntentService',
        );
      },
    );

    test(
      'scheduleCheckIn sends the NORMALIZED primary number to native',
      () async {
        Object? captured;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'scheduleCheckIn') {
                captured = (call.arguments as Map)['primaryNumber'];
                return {'scheduled': true, 'exact': true};
              }
              return null;
            });

        await EmergencyPlatformService.instance.scheduleCheckIn(
          phase: 'main',
          deadline: DateTime.now().add(const Duration(minutes: 10)),
          primaryNumber: '(0555) 010-20-30',
        );

        expect(
          captured,
          '05550102030',
          reason:
              'Raw formatted input must be normalized BEFORE it is '
              'persisted into native prefs',
        );
      },
    );

    test('executeEmergencyNative dials the NORMALIZED number', () async {
      Object? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'executeEmergencyNative') {
              captured = (call.arguments as Map)['primaryNumber'];
              return {'status': 'dialerOpened', 'number': captured};
            }
            return null;
          });

      await EmergencyPlatformService.instance.executeEmergencyNative(
        primaryNumber: '+90 (555) 010 20 30',
      );

      expect(captured, '+905550102030');
    });
  });
}
