import 'package:flutter/foundation.dart';

/// Versioned wire contract shared by Flutter and the Android safety kernel.
const int emergencyProtocolVersion = 1;

enum EmergencySessionKind {
  panic('panic'),
  checkIn('checkIn'),
  safeWalk('safeWalk');

  const EmergencySessionKind(this.wireName);

  final String wireName;

  static EmergencySessionKind? fromWire(Object? value) {
    final wire = value?.toString();
    for (final kind in values) {
      if (kind.wireName == wire) return kind;
    }
    return switch (wire) {
      'check_in' => checkIn,
      'safe_walk' => safeWalk,
      _ => null,
    };
  }
}

enum EntitlementDecision {
  authorized,
  denied,
  unknown;

  String get wireName => name;

  static EntitlementDecision fromWire(Object? value) =>
      switch (value?.toString()) {
        'authorized' => authorized,
        'denied' => denied,
        _ => unknown,
      };
}

enum PinState { loading, configured, absent, readFailed }

enum EmergencySessionLifecycle {
  absent,
  preparing,
  armed,
  claimed,
  cancelled,
  requestSubmittedUnconfirmed,
  manualActionRequired,
  requestFailed,
  corrupted,
  unknown;

  static EmergencySessionLifecycle fromWire(Object? value) => switch (value
      ?.toString()) {
    'absent' => absent,
    'preparing' => preparing,
    'armed' => armed,
    'claimed' => claimed,
    'cancelled' => cancelled,
    'requestSubmittedUnconfirmed' ||
    'request_submitted_unconfirmed' => requestSubmittedUnconfirmed,
    'manualActionRequired' || 'manual_action_required' => manualActionRequired,
    'requestFailed' || 'request_failed' => requestFailed,
    'corrupted' => corrupted,
    _ => unknown,
  };

  bool get isTerminal => switch (this) {
    cancelled ||
    requestSubmittedUnconfirmed ||
    manualActionRequired ||
    requestFailed ||
    corrupted => true,
    _ => false,
  };
}

enum CallRequestOutcome {
  notAttempted,
  submittedUnconfirmed,
  failed;

  static CallRequestOutcome fromWire(Object? value) => switch (value
      ?.toString()) {
    'submittedUnconfirmed' || 'submitted_unconfirmed' => submittedUnconfirmed,
    'failed' => failed,
    _ => notAttempted,
  };
}

enum FallbackOutcome {
  notAttempted,
  posted,
  failed,
  expired;

  static FallbackOutcome fromWire(Object? value) => switch (value?.toString()) {
    'posted' => posted,
    'failed' => failed,
    'expired' => expired,
    _ => notAttempted,
  };
}

@immutable
class SessionToken {
  const SessionToken({
    required this.protocolVersion,
    required this.randomId,
    required this.generation,
    required this.kind,
  });

  final int protocolVersion;
  final String randomId;
  final int generation;
  final EmergencySessionKind kind;

  bool get isValid =>
      protocolVersion == emergencyProtocolVersion &&
      randomId.isNotEmpty &&
      generation > 0;

  Map<String, Object?> toMap() => <String, Object?>{
    'protocolVersion': protocolVersion,
    'randomId': randomId,
    'generation': generation,
    'kind': kind.wireName,
  };

  static SessionToken? fromMap(Object? raw) {
    final map = wireMap(raw);
    if (map == null) return null;
    final version = wireInt(map['protocolVersion']);
    final randomId = (map['randomId'] ?? map['id'])?.toString();
    final generation = wireInt(map['generation'] ?? map['revision']);
    final kind = EmergencySessionKind.fromWire(map['kind']);
    if (version == null ||
        version != emergencyProtocolVersion ||
        randomId == null ||
        randomId.isEmpty ||
        generation == null ||
        generation <= 0 ||
        kind == null) {
      return null;
    }
    return SessionToken(
      protocolVersion: version,
      randomId: randomId,
      generation: generation,
      kind: kind,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionToken &&
      protocolVersion == other.protocolVersion &&
      randomId == other.randomId &&
      generation == other.generation &&
      kind == other.kind;

  @override
  int get hashCode => Object.hash(protocolVersion, randomId, generation, kind);

  /// Identity excluding the revision counter. A newer generation may only be
  /// reconciled when the protocol, random id and session kind still match.
  bool hasSameSessionIdentity(SessionToken other) =>
      protocolVersion == other.protocolVersion &&
      randomId == other.randomId &&
      kind == other.kind;
}

sealed class ArmResult {
  const ArmResult();

  SessionToken? get token;
  bool get isArmed => this is Armed;
}

final class Armed extends ArmResult {
  const Armed({
    required this.sessionToken,
    required this.mainDeadline,
    required this.finalDeadline,
  });

  final SessionToken sessionToken;
  final DateTime mainDeadline;
  final DateTime finalDeadline;

  @override
  SessionToken get token => sessionToken;
}

final class ArmRejected extends ArmResult {
  const ArmRejected(this.reasonCode, {this.rejectedToken});

  final String reasonCode;
  final SessionToken? rejectedToken;

  @override
  SessionToken? get token => rejectedToken;
}

final class ArmUnknown extends ArmResult {
  const ArmUnknown(this.reasonCode, {this.uncertainToken});

  final String reasonCode;
  final SessionToken? uncertainToken;

  @override
  SessionToken? get token => uncertainToken;
}

sealed class CancelResult {
  const CancelResult(this.token);

  final SessionToken token;
  bool get isConfirmedCancelled =>
      this is SessionCancelled || this is SessionAlreadyCancelled;
}

final class SessionCancelled extends CancelResult {
  const SessionCancelled(super.token);
}

final class SessionAlreadyCancelled extends CancelResult {
  const SessionAlreadyCancelled(super.token);
}

final class SessionCancelTooLate extends CancelResult {
  const SessionCancelTooLate(super.token, this.terminalState);

  final EmergencySessionLifecycle terminalState;
}

final class SessionCancelStale extends CancelResult {
  const SessionCancelStale(super.token);
}

final class SessionCancelUnknown extends CancelResult {
  const SessionCancelUnknown(super.token, this.reasonCode);

  final String reasonCode;
}

@immutable
class DispatchResult {
  const DispatchResult({
    required this.token,
    required this.callRequestOutcome,
    required this.fallbackOutcome,
    required this.terminalState,
    this.isReconciled = false,
    this.isUnknown = false,
  });

  final SessionToken token;
  final CallRequestOutcome callRequestOutcome;
  final FallbackOutcome fallbackOutcome;
  final EmergencySessionLifecycle terminalState;
  final bool isReconciled;
  final bool isUnknown;

  /// Connection cannot be inferred from an Android Telecom request.
  String get connectionState => 'unknown';

  bool get requestWasSubmitted =>
      callRequestOutcome == CallRequestOutcome.submittedUnconfirmed;

  bool get hasActionableFallback => fallbackOutcome == FallbackOutcome.posted;

  bool get wasCancelled => terminalState == EmergencySessionLifecycle.cancelled;
}

enum SessionReadStatus { present, absent, corrupted, unknown }

@immutable
class SessionSnapshot {
  const SessionSnapshot({
    required this.status,
    this.token,
    this.lifecycleState = EmergencySessionLifecycle.unknown,
    this.mainDeadline,
    this.finalDeadline,
    this.target,
    this.callRequestOutcome = CallRequestOutcome.notAttempted,
    this.fallbackOutcome = FallbackOutcome.notAttempted,
    this.reasonCode,
  });

  final SessionReadStatus status;
  final SessionToken? token;
  final EmergencySessionLifecycle lifecycleState;
  final DateTime? mainDeadline;
  final DateTime? finalDeadline;
  final String? target;
  final CallRequestOutcome callRequestOutcome;
  final FallbackOutcome fallbackOutcome;
  final String? reasonCode;

  bool get isPresent => status == SessionReadStatus.present && token != null;
}

enum WipeResult { completed, pending, tooLate, unknown }

@immutable
class CapabilitySnapshot {
  const CapabilitySnapshot({
    required this.supportedOs,
    required this.telephonyCalling,
    required this.telecomAvailable,
    required this.dialHandlerAvailable,
    required this.exactAlarmGranted,
    required this.notificationsEnabled,
    required this.alertChannelHigh,
    required this.callPermissionGranted,
    required this.pinConfigured,
    required this.callableTarget,
    required this.entitlementDecision,
  });

  const CapabilitySnapshot.unavailable()
    : supportedOs = false,
      telephonyCalling = false,
      telecomAvailable = false,
      dialHandlerAvailable = false,
      exactAlarmGranted = false,
      notificationsEnabled = false,
      alertChannelHigh = false,
      callPermissionGranted = false,
      pinConfigured = false,
      callableTarget = false,
      entitlementDecision = EntitlementDecision.unknown;

  final bool supportedOs;
  final bool telephonyCalling;
  final bool telecomAvailable;
  final bool dialHandlerAvailable;
  final bool exactAlarmGranted;
  final bool notificationsEnabled;
  final bool alertChannelHigh;
  final bool callPermissionGranted;
  final bool pinConfigured;
  final bool callableTarget;
  final EntitlementDecision entitlementDecision;

  bool get unattendedSessionReady =>
      supportedOs &&
      telephonyCalling &&
      telecomAvailable &&
      dialHandlerAvailable &&
      exactAlarmGranted &&
      notificationsEnabled &&
      alertChannelHigh &&
      callPermissionGranted &&
      pinConfigured &&
      callableTarget &&
      entitlementDecision == EntitlementDecision.authorized;
}

Map<String, dynamic>? wireMap(Object? raw) {
  if (raw is! Map) return null;
  return raw.map(
    (Object? key, Object? value) => MapEntry(key.toString(), value),
  );
}

int? wireInt(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

DateTime? wireDate(Object? value) {
  final milliseconds = wireInt(value);
  if (milliseconds == null || milliseconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
