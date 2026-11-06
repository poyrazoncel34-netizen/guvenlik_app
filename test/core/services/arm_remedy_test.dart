// Every refusal code -> the fix the blocked-arm dialog offers, whether it may
// offer the manual call, and the sentence beside them (2026-11-02).
//
// The expectations are literal on purpose. The codes come from
// `CapabilitySnapshot.rejectionReason()` and `EmergencySessionCoordinator`
// (Kotlin) and from the Dart pre-arm checks in CountdownScreen; a code added
// on either side without a row here is caught by the "unknown code" row only
// as far as "it still gets the call", which is the floor, not the goal.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/arm_remedy.dart';
import 'package:guvenlik_app/core/services/emergency_platform_service.dart';
import 'package:guvenlik_app/core/services/emergency_result_policy.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';
import 'package:guvenlik_app/core/services/panic_arm_policy.dart';

const token = SessionToken(
  protocolVersion: emergencyProtocolVersion,
  randomId: 'arm-remedy-test',
  generation: 1,
  kind: EmergencySessionKind.panic,
);

const String target = '+905001234567';

class _Expect {
  const _Expect(this.remedy, {required this.call, required this.bodyKey});

  final ArmRemedy? remedy;
  final bool call;
  final String bodyKey;
}

const String notReady = 'safety_session_not_ready';

const Map<String, _Expect> _table = <String, _Expect>{
  // CapabilitySnapshot.rejectionReason(), in its order.
  'unsupportedOs': _Expect(null, call: true, bodyKey: notReady),
  'entitlementDenied': _Expect(
    ArmRemedy.subscription,
    call: false,
    bodyKey: 'safety_session_entitlement_unverified',
  ),
  'entitlementUnknown': _Expect(
    ArmRemedy.subscription,
    call: false,
    bodyKey: 'safety_session_entitlement_unverified',
  ),
  'pinNotConfigured': _Expect(
    ArmRemedy.pinSetup,
    call: false,
    bodyKey: 'safety_session_pin_required',
  ),
  'targetNotCallable': _Expect(
    ArmRemedy.emergencyContact,
    call: false,
    bodyKey: 'timer_emergency_contact_required',
  ),
  'telephonyUnavailable': _Expect(null, call: true, bodyKey: notReady),
  'telecomUnavailable': _Expect(null, call: true, bodyKey: notReady),
  'dialHandlerUnavailable': _Expect(null, call: true, bodyKey: notReady),
  'exactAlarmDenied': _Expect(
    ArmRemedy.exactAlarm,
    call: true,
    bodyKey: 'panic_exact_alarm_required',
  ),
  'callPermissionDenied': _Expect(
    ArmRemedy.callPermission,
    call: true,
    bodyKey: notReady,
  ),
  'notificationsDisabled': _Expect(
    ArmRemedy.notifications,
    call: true,
    bodyKey: notReady,
  ),
  'alertChannelNotHigh': _Expect(
    ArmRemedy.alertChannel,
    call: true,
    bodyKey: notReady,
  ),
  // EmergencySessionCoordinator / EmergencyPlatformHandler.
  'unsupportedProtocol': _Expect(null, call: true, bodyKey: notReady),
  'invalidRandomId': _Expect(null, call: true, bodyKey: notReady),
  'invalidGeneration': _Expect(null, call: true, bodyKey: notReady),
  'invalidDeadline': _Expect(null, call: true, bodyKey: notReady),
  'invalidKind': _Expect(null, call: true, bodyKey: notReady),
  'invalidTarget': _Expect(
    ArmRemedy.emergencyContact,
    call: false,
    bodyKey: 'timer_emergency_contact_required',
  ),
  'generationMismatch': _Expect(null, call: true, bodyKey: notReady),
  'immutableTargetMismatch': _Expect(null, call: true, bodyKey: notReady),
  'activeSessionExists': _Expect(null, call: true, bodyKey: notReady),
  'exactAlarmScheduleFailed': _Expect(
    ArmRemedy.exactAlarm,
    call: true,
    bodyKey: notReady,
  ),
  // Dart side.
  'platformBridgeMissing': _Expect(null, call: true, bodyKey: notReady),
  'pinReadFailed': _Expect(
    ArmRemedy.pinSettings,
    call: false,
    bodyKey: 'pin_state_read_failed',
  ),
  'callableTargetMissing': _Expect(
    ArmRemedy.emergencyContact,
    call: false,
    bodyKey: 'timer_emergency_contact_required',
  ),
  // What an older app build makes of a code a newer native build added.
  'someFutureRefusal': _Expect(null, call: true, bodyKey: notReady),
};

PlatformReadinessSnapshot readiness({
  bool exactAlarm = true,
  bool call = true,
  bool notifications = true,
  bool channel = true,
}) => PlatformReadinessSnapshot(
  supportedOs: true,
  telephonyCalling: true,
  telecomAvailable: true,
  dialHandlerAvailable: true,
  batteryOptimizationWhitelisted: true,
  exactAlarmPermission: exactAlarm,
  callPermission: call,
  notificationPermission: notifications,
  alertChannelHigh: channel,
);

void main() {
  group('every refusal code', () {
    for (final MapEntry(key: code, value: want) in _table.entries) {
      test('$code -> ${want.remedy?.name ?? 'no fix'}, '
          '${want.call ? 'call' : 'no call'}', () {
        final refused = ArmRejected(code, rejectedToken: token);

        expect(PanicArmPolicy.remedyFor(refused), want.remedy);
        expect(
          PanicArmPolicy.manualDialNumber(refused, target),
          want.call ? target : '',
        );
        expect(PanicArmPolicy.blockedMessageKey(refused), want.bodyKey);

        final refusal = PanicArmPolicy.refusalFor(refused);
        expect(refusal.bodyKey, want.bodyKey);
        expect(refusal.remedy, want.remedy);
      });
    }

    test('no blocked refusal leaves the dialog with nothing to press', () {
      for (final code in _table.keys) {
        final refused = ArmRejected(code, rejectedToken: token);
        if (!PanicArmPolicy.shouldStartCountdown(refused)) {
          expect(
            PanicArmPolicy.remedyFor(refused) != null ||
                PanicArmPolicy.manualDialNumber(refused, target).isNotEmpty,
            isTrue,
            reason: '$code: neither a fix nor a call',
          );
        }
      }
    });
  });

  // Parity with the native source: a refusal code added there without a row
  // here would reach users with whatever the default row gives it.
  test('every code native can refuse with has a row in this table', () {
    const dir =
        'android/app/src/main/kotlin/com/poyrazoncel/korubeni/emergency';
    final models = File('$dir/EmergencySessionModels.kt').readAsStringSync();
    final start = models.indexOf('fun rejectionReason()');
    final body = models.substring(start, models.indexOf('else -> null', start));
    final codes = <String>{
      for (final match in RegExp(r'-> "(\w+)"').allMatches(body)) match[1]!,
      for (final file in const <String>[
        'EmergencySessionCoordinator.kt',
        'EmergencyPlatformHandler.kt',
      ])
        for (final match in RegExp(
          r'ArmResult\.Rejected\("(\w+)"\)',
        ).allMatches(File('$dir/$file').readAsStringSync()))
          match[1]!,
    };

    expect(codes, hasLength(greaterThanOrEqualTo(21)));
    expect(
      codes.difference(_table.keys.toSet()),
      isEmpty,
      reason: 'native refusal codes with no row here',
    );
  });

  test('non-rejections carry no fix and no call', () {
    final deadline = DateTime.fromMillisecondsSinceEpoch(10000);
    for (final result in <ArmResult>[
      Armed(
        sessionToken: token,
        mainDeadline: deadline,
        finalDeadline: deadline,
      ),
      const ArmUnknown('timeout', uncertainToken: token),
    ]) {
      expect(PanicArmPolicy.remedyFor(result), isNull);
      expect(PanicArmPolicy.manualDialNumber(result, target), '');
    }
  });

  test('a refused arm with no armed target offers no number', () {
    expect(
      PanicArmPolicy.manualDialNumber(
        const ArmRejected('telephonyUnavailable', rejectedToken: token),
        null,
      ),
      '',
    );
  });

  group('capability order', () {
    test('matches CapabilitySnapshot.rejectionReason()', () {
      expect(ArmRemedy.capabilityOrder, <ArmRemedy>[
        ArmRemedy.exactAlarm,
        ArmRemedy.callPermission,
        ArmRemedy.notifications,
        ArmRemedy.alertChannel,
      ]);
    });

    test('missing capabilities come back in that order', () {
      expect(
        ArmRemedy.missingCapabilities(
          readiness(exactAlarm: false, call: false, channel: false),
        ),
        <ArmRemedy>[
          ArmRemedy.exactAlarm,
          ArmRemedy.callPermission,
          ArmRemedy.alertChannel,
        ],
      );
      expect(
        ArmRemedy.missingCapabilities(readiness(notifications: false)),
        <ArmRemedy>[ArmRemedy.notifications],
      );
      expect(ArmRemedy.missingCapabilities(readiness()), isEmpty);
    });

    test('an unknown probe claims nothing is missing', () {
      expect(
        ArmRemedy.missingCapabilities(
          const PlatformReadinessSnapshot.unavailable(reasonCode: 'timeout'),
        ),
        isEmpty,
      );
    });

    test('only device capabilities track readiness', () {
      expect(
        ArmRemedy.values.where((remedy) => remedy.isCapability),
        ArmRemedy.capabilityOrder,
      );
    });
  });

  group('failure copy', () {
    const refusal = ArmRefusal(
      bodyKey: 'panic_exact_alarm_required',
      remedy: ArmRemedy.exactAlarm,
    );

    test('an arm refusal carries its sentence and its fix', () {
      final copy = EmergencyResultPolicy.failureCopy(
        reason: EmergencyFailureReason.armRejected,
        refusal: refusal,
      );
      expect(copy.bodyKey, 'panic_exact_alarm_required');
      expect(copy.remedy, ArmRemedy.exactAlarm);
      expect(copy.claimsNothingCompleted, isTrue);
    });

    test('no other failure offers a settings fix', () {
      for (final reason in EmergencyFailureReason.values.where(
        (reason) => reason != EmergencyFailureReason.armRejected,
      )) {
        expect(
          EmergencyResultPolicy.failureCopy(
            reason: reason,
            refusal: refusal,
          ).remedy,
          isNull,
          reason: '$reason: the moment to fix settings has passed',
        );
      }
    });
  });
}
