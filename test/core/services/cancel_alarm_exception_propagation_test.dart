import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';

/// Blocker 1 behavioral test:
/// cancelCountdownAlarm must NOT propagate any exception to its caller.
///
/// If it throws, the Dart dispatch path in _makeEmergencyCall dies before
/// _executeEmergency() is ever called. This test verifies the service layer
/// swallows ALL exception types — including MissingPluginException which is
/// NOT a PlatformException and would escape the current specific catches.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.poyrazoncel.korubeni/emergency_platform');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'cancelCountdownAlarm does not throw when native side throws MissingPluginException',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'cancelCountdownAlarm') {
              throw MissingPluginException(
                'cancelCountdownAlarm not implemented',
              );
            }
            return null;
          });

      // Must complete without throwing — any exception here kills dispatch
      await expectLater(
        EmergencyPlatformService.instance.cancelCountdownAlarm(
          dispatchId: 'test-dispatch-id',
        ),
        completes,
      );
    },
  );
}
