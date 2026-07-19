import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/contact_service.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizePhoneNumber', () {
    test('removes dots from phone number', () {
      expect(normalizePhoneNumber('0536.449.90.39'), '05364499039');
    });
  });

  // Audit F5: every number crossing the platform channel passes through one
  // strict validate-and-normalize boundary. URI/dial-string syntax must fail
  // closed instead of being stripped into a different callable target.
  group('platform-channel target validation (audit F5)', () {
    const channel = MethodChannel(
      'com.poyrazoncel.korubeni/emergency_platform',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('source contract: typed arm validates and normalizes its target', () {
      final source = File(
        'lib/core/services/emergency_platform_service.dart',
      ).readAsStringSync();

      expect(
        source.contains('normalizedCallableOrNull'),
        isTrue,
        reason:
            'EmergencyPlatformService must be the strict target '
            'chokepoint for numbers crossing the channel',
      );
      expect(
        source.contains("import 'android_intent_service.dart';"),
        isTrue,
        reason: 'normalizer comes from the shared AndroidIntentService',
      );
    });

    test('typed arm sends the NORMALIZED target snapshot to native', () async {
      Object? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'armEmergencySession') {
              final arguments = call.arguments as Map;
              captured = arguments['target'];
              return {
                'type': 'armed',
                'token': {
                  'protocolVersion': 1,
                  'randomId': arguments['randomId'],
                  'generation': 1,
                  'kind': 'checkIn',
                },
                'mainDeadlineMs': arguments['mainDeadlineMs'],
                'finalDeadlineMs': arguments['finalDeadlineMs'],
              };
            }
            return null;
          });

      final service = EmergencyPlatformService.forTesting(
        methodChannel: channel,
      );
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      await service.armEmergencySession(
        kind: EmergencySessionKind.checkIn,
        mainDeadline: deadline,
        finalDeadline: deadline.add(const Duration(minutes: 1)),
        target: '(0555) 010-20-30',
        entitlementDecision: EntitlementDecision.authorized,
        pinConfigured: true,
      );

      expect(
        captured,
        '05550102030',
        reason:
            'Raw formatted input must be normalized BEFORE it is '
            'persisted into the native envelope',
      );
    });
  });
}
