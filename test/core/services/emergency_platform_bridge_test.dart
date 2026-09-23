// A-005: when MainActivity fails to install the emergency MethodChannel, the
// app looked normal. `isSupported` only reports "this is Android", so the arm
// path saw a MissingPluginException, folded it into the generic
// `unexpectedError`, PanicArmPolicy read that as `uncertainNativeCountdown`
// and a countdown STARTED -- visually identical to a protected one, with no
// native AlarmManager session behind it. With the screen off in Doze, nothing
// would have happened.
//
// No handler is registered for the channel in these tests, so the platform
// raises a real MissingPluginException; nothing is stubbed to fake it.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/panic_arm_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EmergencyPlatformService absentBridge() =>
      EmergencyPlatformService.forTesting(
        // A channel name nothing handles: invoking it throws
        // MissingPluginException, exactly as an unregistered emergency
        // channel does in a process where MainActivity's catch fired.
        methodChannel: const MethodChannel('korubeni-test/never-registered'),
      );

  Future<ArmResult> arm(EmergencyPlatformService service) {
    final now = DateTime.now();
    return service.armEmergencySession(
      kind: EmergencySessionKind.panic,
      mainDeadline: now.add(const Duration(seconds: 10)),
      finalDeadline: now.add(const Duration(seconds: 20)),
      target: '+905001234567',
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
    );
  }

  group('a missing native bridge is its own state', () {
    test('arming is a definitive rejection named platformBridgeMissing', () async {
      final service = absentBridge();
      final result = await arm(service);
      expect(
        result,
        isA<ArmRejected>(),
        reason:
            'MissingPluginException proves native never received the arm, so '
            'no session exists. As ArmUnknown it started an unprotected '
            'countdown whose PIN cancel could never be confirmed',
      );
      expect(
        (result as ArmRejected).reasonCode,
        'platformBridgeMissing',
        reason:
            'collapsed into the same bucket as a transient failure, the one '
            'condition that cannot recover became indistinguishable from the '
            'ones that can',
      );
    });

    test('the countdown does not start and no session token survives', () async {
      final result = await arm(absentBridge());
      expect(
        PanicArmPolicy.shouldStartCountdown(result),
        isFalse,
        reason: 'a normal-looking countdown with nothing native behind it',
      );
      expect(
        PanicArmPolicy.dispositionFor(result),
        PanicArmDisposition.blocked,
      );
      expect(
        PanicArmPolicy.activeOrUncertainToken(result),
        isNull,
        reason:
            'a retained token sends the PIN cancel across the missing bridge, '
            'where it can only come back unconfirmed',
      );
    });

    test('the absence is latched and readable by Dart', () async {
      final service = absentBridge();
      expect(
        service.platformBridgeMissing,
        isFalse,
        reason: 'nothing has been invoked yet; the flag must not pre-accuse',
      );
      await arm(service);
      expect(service.platformBridgeMissing, isTrue);
    });

    test('isSupported still answers only the platform question', () async {
      final service = absentBridge();
      await arm(service);
      expect(
        service.isSupported,
        isTrue,
        reason:
            'this IS Android; conflating the two questions is what made the '
            'defect invisible. The new flag is the one that moved.',
      );
      expect(service.platformBridgeMissing, isTrue);
    });

    test('readiness is unavailable and names the reason', () async {
      final snapshot = await absentBridge().getPlatformReadiness();
      expect(snapshot.isKnown, isFalse);
      expect(snapshot.reasonCode, 'platformBridgeMissing');
      // The readiness card derives every chip from these two, so an unknown
      // snapshot already renders red -- asserted rather than assumed.
      expect(snapshot.criticalSafetyReady, isFalse);
      expect(snapshot.automaticCallReady, isFalse);
      expect(snapshot.backgroundAlertReady, isFalse);
    });
  });
}
