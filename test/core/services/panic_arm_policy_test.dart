import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_result_policy.dart';
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

  // Y-11 (owner decision 2026-10-09): without exact-alarm access there is no
  // native backup, so a countdown that looks protected must not start. On an
  // API 36 clean install the dialer-only countdown looked identical to a
  // protected one and a process death during it called nobody.
  group('Y-11: exact-alarm access missing', () {
    const denied = ArmRejected('exactAlarmDenied', rejectedToken: token);

    test('blocks the protected countdown', () {
      expect(PanicArmPolicy.dispositionFor(denied), PanicArmDisposition.blocked);
      expect(PanicArmPolicy.shouldStartCountdown(denied), isFalse);
      expect(
        PanicArmPolicy.blockedMessageKey(denied),
        EmergencyResultPolicy.exactAlarmRequiredBodyKey,
      );
    });

    EmergencyFailureCopy copyFor(ArmResult result) =>
        EmergencyResultPolicy.failureCopy(
          reason: EmergencyFailureReason.armRejected,
          bodyKeyOverride: PanicArmPolicy.blockedMessageKey(result),
        );

    test('offers background protection and a call to the armed target', () {
      expect(copyFor(denied).offersBackgroundProtection, isTrue);
      expect(
        PanicArmPolicy.manualDialNumber(denied, '+905001234567'),
        '+905001234567',
      );
    });

    test('no other refusal offers the exact-alarm settings', () {
      for (final reason in <String>{
        'callPermissionDenied',
        'notificationsDisabled',
        'entitlementDenied',
        'platformBridgeMissing',
      }) {
        expect(
          copyFor(
            ArmRejected(reason, rejectedToken: token),
          ).offersBackgroundProtection,
          isFalse,
          reason: reason,
        );
      }
    });
  });

  // Y-11 review: a dialer-only countdown has no native session, so a process
  // death during it calls nobody. It must not look like a protected one.
  test('only a foreground dial countdown is titled limited protection', () {
    const limited = 'countdown_limited_protection_title';
    for (final reason in <String>{
      'callPermissionDenied',
      'notificationsDisabled',
      'alertChannelNotHigh',
    }) {
      expect(
        PanicArmPolicy.countdownTitleKey(
          ArmRejected(reason, rejectedToken: token),
        ),
        limited,
        reason: reason,
      );
    }
    for (final result in <ArmResult?>[
      null,
      Armed(
        sessionToken: token,
        mainDeadline: DateTime.fromMillisecondsSinceEpoch(10000),
        finalDeadline: DateTime.fromMillisecondsSinceEpoch(10000),
      ),
      const ArmUnknown('timeout', uncertainToken: token),
      const ArmRejected('exactAlarmDenied', rejectedToken: token),
    ]) {
      expect(
        PanicArmPolicy.countdownTitleKey(result),
        'countdown_warning_title',
        reason: '$result',
      );
    }
  });

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

  group('A-005: a missing native bridge', () {
    const bridgeMissing = ArmRejected(
      'platformBridgeMissing',
      rejectedToken: token,
    );

    test('blocks the countdown instead of starting an unprotected one', () {
      expect(
        PanicArmPolicy.dispositionFor(bridgeMissing),
        PanicArmDisposition.blocked,
      );
      expect(PanicArmPolicy.shouldStartCountdown(bridgeMissing), isFalse);
      expect(
        PanicArmPolicy.blockedMessageKey(bridgeMissing),
        'safety_session_not_ready',
      );
    });

    test('offers the armed target for a manual call', () {
      expect(
        PanicArmPolicy.manualDialNumber(bridgeMissing, '+905001234567'),
        '+905001234567',
      );
      expect(PanicArmPolicy.manualDialNumber(bridgeMissing, null), '');
    });

    test('never offers a call for authorization or target refusals', () {
      for (final reason in <String>{
        'entitlementDenied',
        'entitlementUnknown',
        'pinNotConfigured',
        'pinReadFailed',
        'targetNotCallable',
        'callableTargetMissing',
        'unsupportedOs',
      }) {
        expect(
          PanicArmPolicy.manualDialNumber(
            ArmRejected(reason, rejectedToken: token),
            '+905001234567',
          ),
          '',
          reason: '$reason: a manual call here would bypass the refusing gate',
        );
      }
      expect(
        PanicArmPolicy.manualDialNumber(
          const ArmUnknown('timeout', uncertainToken: token),
          '+905001234567',
        ),
        '',
      );
    });
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
