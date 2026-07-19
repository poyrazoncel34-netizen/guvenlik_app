import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'readiness starts unknown and fail closed before the platform probe',
    () {
      const channel = MethodChannel('emergency_readiness_initial_state_test');
      final platform = EmergencyPlatformService.forTesting(
        methodChannel: channel,
      );
      final readiness = EmergencyReadinessService.forTesting(
        platformService: platform,
      );

      expect(readiness.lastState, isNull);
      expect(readiness.isReady, isFalse);
    },
  );
}
