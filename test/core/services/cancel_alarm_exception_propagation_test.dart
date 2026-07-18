import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';

/// Typed cancel failures are uncertainty, never silent success or an exception.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.poyrazoncel.korubeni/emergency_platform');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'typed cancel returns Unknown when native side throws MissingPluginException',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw MissingPluginException('${call.method} not implemented');
          });

      final service = EmergencyPlatformService.forTesting(
        methodChannel: channel,
      );
      const token = SessionToken(
        protocolVersion: 1,
        randomId: 'test-dispatch-id',
        generation: 1,
        kind: EmergencySessionKind.panic,
      );
      final result = await service.cancelEmergencySession(token);

      expect(result, isA<SessionCancelUnknown>());
      expect(result.isConfirmedCancelled, isFalse);
    },
  );
}
