import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/panic_arm_policy.dart';

void main() {
  const token = SessionToken(
    protocolVersion: emergencyProtocolVersion,
    randomId: 'panic-policy-test',
    generation: 1,
    kind: EmergencySessionKind.panic,
  );

  test(
    'only platform capability rejections retain foreground dial fallback',
    () {
      for (final reason in <String>{
        'callPermissionDenied',
        'exactAlarmDenied',
        'notificationsDisabled',
        'alertChannelNotHigh',
      }) {
        expect(
          PanicArmPolicy.dispositionFor(
            ArmRejected(reason, rejectedToken: token),
          ),
          PanicArmDisposition.foregroundDialCountdown,
          reason: reason,
        );
      }
    },
  );

  test(
    'authorization identity and unsupported-device rejections are blocked',
    () {
      for (final reason in <String>{
        'entitlementDenied',
        'entitlementUnknown',
        'pinNotConfigured',
        'pinReadFailed',
        'targetNotCallable',
        'callableTargetMissing',
        'unsupportedOs',
        'telephonyUnavailable',
        'telecomUnavailable',
        'dialHandlerUnavailable',
      }) {
        final result = ArmRejected(reason, rejectedToken: token);
        expect(
          PanicArmPolicy.dispositionFor(result),
          PanicArmDisposition.blocked,
          reason: reason,
        );
        expect(PanicArmPolicy.shouldStartCountdown(result), isFalse);
      }
    },
  );

  test('rejected diagnostic token is never treated as an active session', () {
    expect(
      PanicArmPolicy.activeOrUncertainToken(
        const ArmRejected('callPermissionDenied', rejectedToken: token),
      ),
      isNull,
    );
    expect(
      PanicArmPolicy.activeOrUncertainToken(
        const ArmUnknown('timeout', uncertainToken: token),
      ),
      token,
    );
  });

  test('armed and uncertain outcomes keep their distinct countdown modes', () {
    final deadline = DateTime.fromMillisecondsSinceEpoch(10000);
    expect(
      PanicArmPolicy.dispositionFor(
        Armed(
          sessionToken: token,
          mainDeadline: deadline,
          finalDeadline: deadline,
        ),
      ),
      PanicArmDisposition.nativeProtectedCountdown,
    );
    expect(
      PanicArmPolicy.dispositionFor(
        const ArmUnknown('timeout', uncertainToken: token),
      ),
      PanicArmDisposition.uncertainNativeCountdown,
    );
  });
}
