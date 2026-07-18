import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/services/emergency_session_contract.dart';

void main() {
  group('wire enums fail closed', () {
    test('session kinds accept canonical and migration aliases only', () {
      expect(
        EmergencySessionKind.fromWire('panic'),
        EmergencySessionKind.panic,
      );
      expect(
        EmergencySessionKind.fromWire('checkIn'),
        EmergencySessionKind.checkIn,
      );
      expect(
        EmergencySessionKind.fromWire('safeWalk'),
        EmergencySessionKind.safeWalk,
      );
      expect(
        EmergencySessionKind.fromWire('check_in'),
        EmergencySessionKind.checkIn,
      );
      expect(
        EmergencySessionKind.fromWire('safe_walk'),
        EmergencySessionKind.safeWalk,
      );
      expect(EmergencySessionKind.fromWire('other'), isNull);
      expect(EmergencySessionKind.fromWire(null), isNull);
    });

    test('entitlement, lifecycle and outcomes use conservative defaults', () {
      expect(
        EntitlementDecision.fromWire('authorized'),
        EntitlementDecision.authorized,
      );
      expect(
        EntitlementDecision.fromWire('denied'),
        EntitlementDecision.denied,
      );
      expect(
        EntitlementDecision.fromWire('unexpected'),
        EntitlementDecision.unknown,
      );
      expect(EntitlementDecision.authorized.wireName, 'authorized');

      final lifecycleCases = <String, EmergencySessionLifecycle>{
        'absent': EmergencySessionLifecycle.absent,
        'preparing': EmergencySessionLifecycle.preparing,
        'armed': EmergencySessionLifecycle.armed,
        'claimed': EmergencySessionLifecycle.claimed,
        'cancelled': EmergencySessionLifecycle.cancelled,
        'requestSubmittedUnconfirmed':
            EmergencySessionLifecycle.requestSubmittedUnconfirmed,
        'request_submitted_unconfirmed':
            EmergencySessionLifecycle.requestSubmittedUnconfirmed,
        'manualActionRequired': EmergencySessionLifecycle.manualActionRequired,
        'manual_action_required':
            EmergencySessionLifecycle.manualActionRequired,
        'requestFailed': EmergencySessionLifecycle.requestFailed,
        'request_failed': EmergencySessionLifecycle.requestFailed,
        'corrupted': EmergencySessionLifecycle.corrupted,
      };
      for (final entry in lifecycleCases.entries) {
        expect(EmergencySessionLifecycle.fromWire(entry.key), entry.value);
      }
      expect(
        EmergencySessionLifecycle.fromWire('newState'),
        EmergencySessionLifecycle.unknown,
      );
      for (final lifecycle in EmergencySessionLifecycle.values) {
        final shouldBeTerminal = <EmergencySessionLifecycle>{
          EmergencySessionLifecycle.cancelled,
          EmergencySessionLifecycle.requestSubmittedUnconfirmed,
          EmergencySessionLifecycle.manualActionRequired,
          EmergencySessionLifecycle.requestFailed,
          EmergencySessionLifecycle.corrupted,
        }.contains(lifecycle);
        expect(lifecycle.isTerminal, shouldBeTerminal, reason: lifecycle.name);
      }

      expect(
        CallRequestOutcome.fromWire('submittedUnconfirmed'),
        CallRequestOutcome.submittedUnconfirmed,
      );
      expect(
        CallRequestOutcome.fromWire('submitted_unconfirmed'),
        CallRequestOutcome.submittedUnconfirmed,
      );
      expect(CallRequestOutcome.fromWire('failed'), CallRequestOutcome.failed);
      expect(
        CallRequestOutcome.fromWire('other'),
        CallRequestOutcome.notAttempted,
      );
      expect(FallbackOutcome.fromWire('posted'), FallbackOutcome.posted);
      expect(FallbackOutcome.fromWire('failed'), FallbackOutcome.failed);
      expect(FallbackOutcome.fromWire('expired'), FallbackOutcome.expired);
      expect(FallbackOutcome.fromWire('other'), FallbackOutcome.notAttempted);
    });
  });

  group('session token validation', () {
    const token = SessionToken(
      protocolVersion: emergencyProtocolVersion,
      randomId: '0123456789abcdef0123456789abcdef',
      generation: 3,
      kind: EmergencySessionKind.safeWalk,
    );

    test('round trips and supports explicit migration field aliases', () {
      expect(token.isValid, isTrue);
      expect(SessionToken.fromMap(token.toMap()), token);
      expect(
        SessionToken.fromMap(<String, Object?>{
          'protocolVersion': '$emergencyProtocolVersion',
          'id': token.randomId,
          'revision': 3.9,
          'kind': 'safe_walk',
        }),
        token,
      );
      expect(token.hashCode, token.hashCode);
      expect(token == Object(), isFalse);
    });

    test('rejects every malformed identity field', () {
      final valid = token.toMap();
      final invalid = <Object?>[
        null,
        'not-a-map',
        <String, Object?>{...valid, 'protocolVersion': null},
        <String, Object?>{...valid, 'protocolVersion': 99},
        <String, Object?>{...valid, 'randomId': null},
        <String, Object?>{...valid, 'randomId': ''},
        <String, Object?>{...valid, 'generation': null},
        <String, Object?>{...valid, 'generation': 0},
        <String, Object?>{...valid, 'kind': 'unknown'},
      ];
      for (final value in invalid) {
        expect(SessionToken.fromMap(value), isNull, reason: '$value');
      }

      expect(
        const SessionToken(
          protocolVersion: 99,
          randomId: 'id',
          generation: 1,
          kind: EmergencySessionKind.panic,
        ).isValid,
        isFalse,
      );
      expect(
        const SessionToken(
          protocolVersion: emergencyProtocolVersion,
          randomId: '',
          generation: 1,
          kind: EmergencySessionKind.panic,
        ).isValid,
        isFalse,
      );
      expect(
        const SessionToken(
          protocolVersion: emergencyProtocolVersion,
          randomId: 'id',
          generation: 0,
          kind: EmergencySessionKind.panic,
        ).isValid,
        isFalse,
      );
    });

    test('session identity excludes only generation', () {
      final revision = SessionToken(
        protocolVersion: token.protocolVersion,
        randomId: token.randomId,
        generation: token.generation + 1,
        kind: token.kind,
      );
      expect(token.hasSameSessionIdentity(revision), isTrue);
      expect(
        token.hasSameSessionIdentity(
          SessionToken(
            protocolVersion: token.protocolVersion,
            randomId: 'different',
            generation: token.generation,
            kind: token.kind,
          ),
        ),
        isFalse,
      );
    });
  });

  test('typed results expose only truthful convenience projections', () {
    const token = SessionToken(
      protocolVersion: emergencyProtocolVersion,
      randomId: '0123456789abcdef0123456789abcdef',
      generation: 1,
      kind: EmergencySessionKind.checkIn,
    );
    final armed = Armed(
      sessionToken: token,
      mainDeadline: DateTime(2100),
      finalDeadline: DateTime(2100).add(const Duration(minutes: 1)),
    );
    expect(armed.isArmed, isTrue);
    expect(armed.token, token);
    expect(const ArmRejected('denied').isArmed, isFalse);
    expect(const ArmRejected('denied').token, isNull);
    expect(const ArmUnknown('timeout').token, isNull);

    expect(const SessionCancelled(token).isConfirmedCancelled, isTrue);
    expect(const SessionAlreadyCancelled(token).isConfirmedCancelled, isTrue);
    expect(
      const SessionCancelTooLate(
        token,
        EmergencySessionLifecycle.requestFailed,
      ).isConfirmedCancelled,
      isFalse,
    );
    expect(const SessionCancelStale(token).isConfirmedCancelled, isFalse);
    expect(
      const SessionCancelUnknown(token, 'timeout').isConfirmedCancelled,
      isFalse,
    );

    const dispatch = DispatchResult(
      token: token,
      callRequestOutcome: CallRequestOutcome.submittedUnconfirmed,
      fallbackOutcome: FallbackOutcome.posted,
      terminalState: EmergencySessionLifecycle.requestSubmittedUnconfirmed,
    );
    expect(dispatch.connectionState, 'unknown');
    expect(dispatch.requestWasSubmitted, isTrue);
    expect(dispatch.hasActionableFallback, isTrue);
    expect(dispatch.wasCancelled, isFalse);
    expect(
      const DispatchResult(
        token: token,
        callRequestOutcome: CallRequestOutcome.failed,
        fallbackOutcome: FallbackOutcome.failed,
        terminalState: EmergencySessionLifecycle.cancelled,
      ).wasCancelled,
      isTrue,
    );

    expect(
      const SessionSnapshot(
        status: SessionReadStatus.present,
        token: token,
      ).isPresent,
      isTrue,
    );
    expect(
      const SessionSnapshot(status: SessionReadStatus.absent).isPresent,
      isFalse,
    );
  });

  test('capability readiness requires every safety prerequisite', () {
    const ready = CapabilitySnapshot(
      supportedOs: true,
      telephonyCalling: true,
      telecomAvailable: true,
      dialHandlerAvailable: true,
      exactAlarmGranted: true,
      notificationsEnabled: true,
      alertChannelHigh: true,
      callPermissionGranted: true,
      pinConfigured: true,
      callableTarget: true,
      entitlementDecision: EntitlementDecision.authorized,
    );
    expect(ready.unattendedSessionReady, isTrue);
    expect(
      const CapabilitySnapshot.unavailable().unattendedSessionReady,
      isFalse,
    );

    final values = <CapabilitySnapshot>[
      const CapabilitySnapshot(
        supportedOs: false,
        telephonyCalling: true,
        telecomAvailable: true,
        dialHandlerAvailable: true,
        exactAlarmGranted: true,
        notificationsEnabled: true,
        alertChannelHigh: true,
        callPermissionGranted: true,
        pinConfigured: true,
        callableTarget: true,
        entitlementDecision: EntitlementDecision.authorized,
      ),
      const CapabilitySnapshot(
        supportedOs: true,
        telephonyCalling: true,
        telecomAvailable: true,
        dialHandlerAvailable: true,
        exactAlarmGranted: true,
        notificationsEnabled: true,
        alertChannelHigh: true,
        callPermissionGranted: true,
        pinConfigured: true,
        callableTarget: true,
        entitlementDecision: EntitlementDecision.unknown,
      ),
    ];
    for (final snapshot in values) {
      expect(snapshot.unattendedSessionReady, isFalse);
    }
  });

  test('wire scalar helpers reject ambiguous and invalid values', () {
    expect(wireMap(<Object?, Object?>{1: 'value'}), <String, Object?>{
      '1': 'value',
    });
    expect(wireMap('map'), isNull);
    expect(wireInt(7), 7);
    expect(wireInt(7.9), 7);
    expect(wireInt('42'), 42);
    expect(wireInt('not-an-int'), isNull);
    expect(wireInt(null), isNull);
    expect(wireDate(null), isNull);
    expect(wireDate(0), isNull);
    expect(wireDate(-1), isNull);
    expect(wireDate(1000)?.millisecondsSinceEpoch, 1000);
  });
}
