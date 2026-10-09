import 'emergency_session_contract.dart';

SessionSnapshot parseSessionSnapshot(
  Map<String, dynamic> map, {
  SessionToken? requestedToken,
  EmergencySessionKind? requestedKind,
}) {
  final type = map['type']?.toString();
  if (type == 'absent') {
    return SessionSnapshot(
      status: SessionReadStatus.absent,
      token: requestedToken,
      lifecycleState: EmergencySessionLifecycle.absent,
      reasonCode: map['reasonCode']?.toString(),
    );
  }
  if (type == 'corrupted') {
    return SessionSnapshot(
      status: SessionReadStatus.corrupted,
      token: requestedToken,
      lifecycleState: EmergencySessionLifecycle.corrupted,
      reasonCode: map['reasonCode']?.toString(),
    );
  }
  if (type != 'present') {
    return SessionSnapshot(
      status: SessionReadStatus.unknown,
      token: requestedToken,
      reasonCode: map['reasonCode']?.toString() ?? 'malformedResponse',
    );
  }
  final session = wireMap(map['session']);
  if (session == null) {
    return SessionSnapshot(
      status: SessionReadStatus.unknown,
      token: requestedToken,
      reasonCode: 'missingSession',
    );
  }
  final token = SessionToken.fromMap(session['token']);
  if (token == null ||
      (requestedToken != null && token != requestedToken) ||
      (requestedKind != null && token.kind != requestedKind)) {
    return SessionSnapshot(
      status: SessionReadStatus.unknown,
      token: requestedToken,
      reasonCode: 'invalidToken',
    );
  }
  final lifecycle = EmergencySessionLifecycle.fromWire(
    session['lifecycleState'],
  );
  final mainDeadline = wireDate(session['mainDeadlineMs']);
  final finalDeadline = wireDate(session['finalDeadlineMs']);
  final target = session['target'];
  final callOutcome = parseCallRequestOutcome(
    session['callRequestOutcome'] ?? map['callRequestOutcome'],
  );
  final fallbackOutcome = parseFallbackOutcome(
    session['fallbackOutcome'] ?? map['fallbackOutcome'],
  );
  if (lifecycle == EmergencySessionLifecycle.unknown ||
      lifecycle == EmergencySessionLifecycle.absent ||
      mainDeadline == null ||
      finalDeadline == null ||
      finalDeadline.isBefore(mainDeadline) ||
      target is! String ||
      callOutcome == null ||
      fallbackOutcome == null) {
    return SessionSnapshot(
      status: SessionReadStatus.unknown,
      token: requestedToken,
      reasonCode: 'malformedSession',
    );
  }
  return SessionSnapshot(
    status: SessionReadStatus.present,
    token: token,
    lifecycleState: lifecycle,
    completedAt: (wireInt(session['completedAtMs']) ?? 0) > 0
        ? wireDate(session['completedAtMs'])
        : null,
    mainDurationSeconds: (wireInt(session['mainDurationMs']) ?? 0) ~/ 1000,
    mainDeadline: mainDeadline,
    finalDeadline: finalDeadline,
    target: target,
    callRequestOutcome: callOutcome,
    fallbackOutcome: fallbackOutcome,
    reasonCode: map['reasonCode']?.toString(),
    // Absent on older native builds: no evidence of a revocation.
    exactAlarmPermitted: map['exactAlarmPermitted'] != false,
  );
}

CallRequestOutcome? parseCallRequestOutcome(Object? value) =>
    switch (value?.toString()) {
      'notAttempted' || 'not_attempted' => CallRequestOutcome.notAttempted,
      'submittedUnconfirmed' ||
      'submitted_unconfirmed' => CallRequestOutcome.submittedUnconfirmed,
      'failed' => CallRequestOutcome.failed,
      _ => null,
    };

FallbackOutcome? parseFallbackOutcome(Object? value) =>
    switch (value?.toString()) {
      'notAttempted' || 'not_attempted' => FallbackOutcome.notAttempted,
      'posted' => FallbackOutcome.posted,
      'failed' => FallbackOutcome.failed,
      'expired' => FallbackOutcome.expired,
      _ => null,
    };
