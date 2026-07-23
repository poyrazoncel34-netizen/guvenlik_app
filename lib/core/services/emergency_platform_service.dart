import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_intent_service.dart';
import 'emergency_session_contract.dart';

class EmergencyPlatformService {
  EmergencyPlatformService._({
    MethodChannel? methodChannel,
    bool? supportedOverride,
    Duration defaultTimeout = const Duration(seconds: 5),
    Duration dispatchTimeout = const Duration(seconds: 5),
  }) : _methodChannel = methodChannel ?? const MethodChannel(channelName),
       _supportedOverride = supportedOverride,
       _defaultTimeout = defaultTimeout,
       _dispatchTimeout = dispatchTimeout;

  factory EmergencyPlatformService.forTesting({
    required MethodChannel methodChannel,
    bool supported = true,
    Duration defaultTimeout = const Duration(milliseconds: 100),
    Duration dispatchTimeout = const Duration(milliseconds: 100),
  }) => EmergencyPlatformService._(
    methodChannel: methodChannel,
    supportedOverride: supported,
    defaultTimeout: defaultTimeout,
    dispatchTimeout: dispatchTimeout,
  );

  static final EmergencyPlatformService instance = EmergencyPlatformService._();

  static const String channelName =
      'com.poyrazoncel.korubeni/emergency_platform';
  final MethodChannel _methodChannel;
  final bool? _supportedOverride;
  final Duration _defaultTimeout;
  final Duration _dispatchTimeout;
  static const EventChannel _eventChannel = EventChannel(
    'com.poyrazoncel.korubeni/emergency_platform/events',
  );

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _eventsSubscription;
  bool _initialized = false;

  bool get isSupported =>
      _supportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> initialize() async {
    if (!isSupported || _initialized) {
      return;
    }

    _eventsSubscription = _eventChannel.receiveBroadcastStream().listen((
      dynamic event,
    ) {
      final mapped = _toMap(event);
      if (mapped != null) {
        _eventsController.add(mapped);
      }
    }, onError: _eventsController.addError);

    _initialized = true;
  }

  /// Arm a versioned native safety session. A malformed response is never
  /// treated as an acknowledgement. Timeout/error reconciles with the same
  /// proposed token and remains [ArmUnknown] unless native durable state proves
  /// the session is armed.
  Future<ArmResult> armEmergencySession({
    required EmergencySessionKind kind,
    required DateTime mainDeadline,
    required DateTime finalDeadline,
    required String target,
    required EntitlementDecision entitlementDecision,
    required bool pinConfigured,
    String? randomId,
    int generation = 1,
  }) async {
    final proposedToken = SessionToken(
      protocolVersion: emergencyProtocolVersion,
      randomId: randomId ?? _newRandomId(),
      generation: generation,
      kind: kind,
    );
    if (!isSupported) {
      return ArmRejected('unsupportedPlatform', rejectedToken: proposedToken);
    }
    final normalizedTarget = AndroidIntentService.normalizedCallableOrNull(
      target,
    );
    if (normalizedTarget == null) {
      return ArmRejected('invalidTarget', rejectedToken: proposedToken);
    }

    final invocation = await _invokeTypedMap(
      'armEmergencySession',
      arguments: <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'kind': kind.wireName,
        'randomId': proposedToken.randomId,
        'requestedGeneration': proposedToken.generation,
        'mainDeadlineMs': mainDeadline.millisecondsSinceEpoch,
        'finalDeadlineMs': finalDeadline.millisecondsSinceEpoch,
        'target': normalizedTarget,
        'entitlementDecision': entitlementDecision.wireName,
        'pinConfigured': pinConfigured,
      },
    );
    if (!invocation.completed) {
      final snapshot = await readEmergencySession(proposedToken);
      if (snapshot.isPresent &&
          snapshot.lifecycleState == EmergencySessionLifecycle.armed &&
          snapshot.token == proposedToken &&
          _sameWireInstant(snapshot.mainDeadline, mainDeadline) &&
          _sameWireInstant(snapshot.finalDeadline, finalDeadline)) {
        return Armed(
          sessionToken: snapshot.token!,
          mainDeadline: snapshot.mainDeadline!,
          finalDeadline: snapshot.finalDeadline!,
        );
      }
      return ArmUnknown(invocation.reasonCode, uncertainToken: proposedToken);
    }
    return _parseArmResult(
      invocation.value,
      proposedToken: proposedToken,
      requestedMainDeadline: mainDeadline,
      requestedFinalDeadline: finalDeadline,
    );
  }

  /// Atomic deadline revision. The native coordinator recognizes the same
  /// random ID and issues the next generation; no entitlement network lookup
  /// occurs during an already-armed session.
  Future<ArmResult> reviseEmergencySession({
    required SessionToken token,
    required DateTime mainDeadline,
    required DateTime finalDeadline,
    required String targetSnapshot,
  }) async {
    final result = await armEmergencySession(
      kind: token.kind,
      mainDeadline: mainDeadline,
      finalDeadline: finalDeadline,
      target: targetSnapshot,
      entitlementDecision: EntitlementDecision.authorized,
      pinConfigured: true,
      randomId: token.randomId,
      generation: token.generation + 1,
    );
    if (result is Armed && result.sessionToken.generation <= token.generation) {
      return ArmUnknown(
        'nonMonotonicGeneration',
        uncertainToken: result.sessionToken,
      );
    }
    return result;
  }

  Future<CancelResult> cancelEmergencySession(SessionToken token) async {
    if (!isSupported) {
      return SessionCancelUnknown(token, 'unsupportedPlatform');
    }
    final invocation = await _invokeTypedMap(
      'cancelEmergencySession',
      arguments: <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'token': token.toMap(),
      },
    );
    if (!invocation.completed) {
      return _reconcileCancel(
        token,
        await readEmergencySession(token),
        invocation.reasonCode,
      );
    }
    return _parseCancelResult(invocation.value, token);
  }

  Future<SessionSnapshot> readEmergencySession(SessionToken token) async {
    if (!isSupported) {
      return const SessionSnapshot(
        status: SessionReadStatus.unknown,
        reasonCode: 'unsupportedPlatform',
      );
    }
    final invocation = await _invokeTypedMap(
      'readEmergencySession',
      arguments: <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'token': token.toMap(),
      },
    );
    if (!invocation.completed) {
      return SessionSnapshot(
        status: SessionReadStatus.unknown,
        token: token,
        reasonCode: invocation.reasonCode,
      );
    }
    return _parseSnapshot(invocation.value, requestedToken: token);
  }

  /// Finds the durable native session for [kind] when Flutter's projection is
  /// missing. This does not create or revise a session; it only reads the
  /// device-protected native authority.
  Future<SessionSnapshot> discoverEmergencySession(
    EmergencySessionKind kind,
  ) async {
    if (!isSupported) {
      return const SessionSnapshot(
        status: SessionReadStatus.unknown,
        reasonCode: 'unsupportedPlatform',
      );
    }
    final invocation = await _invokeTypedMap(
      'readEmergencySessionByKind',
      arguments: <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'kind': kind.wireName,
      },
    );
    if (!invocation.completed) {
      return SessionSnapshot(
        status: SessionReadStatus.unknown,
        reasonCode: invocation.reasonCode,
      );
    }
    return _parseDiscoveredSnapshot(invocation.value, requestedKind: kind);
  }

  Future<DispatchResult> dispatchEmergencySession({
    required SessionToken token,
    required String source,
  }) async {
    if (!isSupported) {
      return _unknownDispatch(token);
    }
    final invocation = await _invokeTypedMap(
      'dispatchEmergencySession',
      arguments: <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'token': token.toMap(),
        'source': source,
      },
      timeout: _dispatchTimeout,
    );
    if (!invocation.completed) {
      final snapshot = await readEmergencySession(token);
      if (snapshot.isPresent &&
          snapshot.token == token &&
          (snapshot.callRequestOutcome != CallRequestOutcome.notAttempted ||
              snapshot.fallbackOutcome != FallbackOutcome.notAttempted ||
              snapshot.lifecycleState.isTerminal)) {
        return DispatchResult(
          token: token,
          callRequestOutcome: snapshot.callRequestOutcome,
          fallbackOutcome: snapshot.fallbackOutcome,
          terminalState: snapshot.lifecycleState,
          isReconciled: true,
        );
      }
      return _unknownDispatch(token);
    }
    return _parseDispatchResult(invocation.value, token);
  }

  Future<CapabilitySnapshot> getEmergencyCapabilities({
    required EntitlementDecision entitlementDecision,
    required bool pinConfigured,
    required bool callableTarget,
  }) async {
    if (!isSupported) return const CapabilitySnapshot.unavailable();
    final invocation = await _invokeTypedMap(
      'getEmergencyCapabilities',
      arguments: <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
        'entitlementDecision': entitlementDecision.wireName,
        'pinConfigured': pinConfigured,
        'callableTarget': callableTarget,
      },
    );
    if (!invocation.completed) {
      return const CapabilitySnapshot.unavailable();
    }
    final map = invocation.value;
    return CapabilitySnapshot(
      supportedOs: map['supportedOs'] == true,
      telephonyCalling: map['telephonyCalling'] == true,
      telecomAvailable: map['telecomAvailable'] == true,
      dialHandlerAvailable: map['dialHandlerAvailable'] == true,
      exactAlarmGranted: map['exactAlarmGranted'] == true,
      notificationsEnabled: map['notificationsEnabled'] == true,
      alertChannelHigh: map['alertChannelHigh'] == true,
      callPermissionGranted: map['callPermissionGranted'] == true,
      pinConfigured: map['pinConfigured'] == true,
      callableTarget: map['callableTarget'] == true,
      entitlementDecision: EntitlementDecision.fromWire(
        map['entitlementDecision'],
      ),
    );
  }

  Future<WipeResult> wipeEmergencySessions() async {
    if (!isSupported) return WipeResult.unknown;
    final invocation = await _invokeTypedMap(
      'wipeEmergencySessions',
      arguments: const <String, Object?>{
        'protocolVersion': emergencyProtocolVersion,
      },
    );
    if (!invocation.completed) return WipeResult.unknown;
    return switch (invocation.value['type']?.toString()) {
      'completed' => WipeResult.completed,
      'pending' => WipeResult.pending,
      'tooLate' => WipeResult.tooLate,
      _ => WipeResult.unknown,
    };
  }

  Future<Map<String, dynamic>?> consumePendingTrigger() async {
    if (!isSupported) {
      return null;
    }
    return _invokeMap('consumePendingTrigger');
  }

  Future<Map<String, dynamic>> getDeviceState() async {
    if (!isSupported) {
      return const <String, dynamic>{};
    }
    return _invokeMap('getDeviceState');
  }

  /// Returns a bounded, allowlisted projection of native Direct Boot safety
  /// failures for the user's explicit local-data export. Unknown codes,
  /// malformed values and caller-controlled extra fields are discarded.
  Future<List<Map<String, Object?>>> readNativeSafetyDiagnostics() async {
    if (!isSupported) return const <Map<String, Object?>>[];
    try {
      final response = await _methodChannel
          .invokeMethod<dynamic>('readNativeSafetyDiagnostics')
          .timeout(_defaultTimeout);
      if (response is! List) return const <Map<String, Object?>>[];
      final normalized = <Map<String, Object?>>[];
      for (final raw in response) {
        if (normalized.length >= _maxNativeSafetyDiagnostics) break;
        if (raw is! Map) continue;
        final code = raw['code'];
        final occurredAtMs = raw['occurredAtMs'];
        if (code is! String ||
            !_nativeSafetyDiagnosticCodes.contains(code) ||
            occurredAtMs is! int ||
            occurredAtMs <= 0) {
          continue;
        }
        normalized.add(<String, Object?>{
          'code': code,
          'occurredAtMs': occurredAtMs,
        });
      }
      return List<Map<String, Object?>>.unmodifiable(normalized);
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] native diagnostics read timed out');
      return const <Map<String, Object?>>[];
    } on PlatformException {
      debugPrint('[EmergencyPlatform] native diagnostics read failed');
      return const <Map<String, Object?>>[];
    } on Exception {
      debugPrint('[EmergencyPlatform] native diagnostics read failed');
      return const <Map<String, Object?>>[];
    }
  }

  static const int _maxNativeSafetyDiagnostics = 64;
  static const Set<String> _nativeSafetyDiagnosticCodes = <String>{
    'boot_receiver_boundary_failure',
    'clock_receiver_boundary_failure',
    'exact_alarm_permission_receiver_boundary_failure',
    'panic_receiver_boundary_failure',
    'long_session_receiver_boundary_failure',
    'fallback_cleanup_receiver_boundary_failure',
  };

  /// Reads platform-only readiness as a strict typed snapshot.
  ///
  /// Every field is mandatory. A timeout, plugin error, missing key or wrong
  /// wire type returns [PlatformReadinessSnapshot.unavailable] instead of
  /// silently converting an unknown capability into a successful check.
  Future<PlatformReadinessSnapshot> getPlatformReadiness() async {
    if (!isSupported) {
      return const PlatformReadinessSnapshot.unavailable(
        reasonCode: 'unsupportedPlatform',
      );
    }
    final invocation = await _invokeTypedMap('getDeviceState');
    if (!invocation.completed) {
      return PlatformReadinessSnapshot.unavailable(
        reasonCode: invocation.reasonCode,
      );
    }
    return PlatformReadinessSnapshot.fromMap(invocation.value) ??
        const PlatformReadinessSnapshot.unavailable(
          reasonCode: 'malformedResponse',
        );
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!isSupported) {
      return false;
    }
    return await _invokeBool('canScheduleExactAlarms');
  }

  Future<void> requestExactAlarmPermission() async {
    if (!isSupported) {
      return;
    }
    try {
      await _methodChannel
          .invokeMethod<void>('requestExactAlarmPermission')
          .timeout(_defaultTimeout);
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] requestExactAlarmPermission timed out');
    } on PlatformException {
      debugPrint('[EmergencyPlatform] requestExactAlarmPermission failed');
    } on Exception {
      debugPrint('[EmergencyPlatform] requestExactAlarmPermission failed');
    }
  }

  Future<bool> openManufacturerSettings() async {
    if (!isSupported) {
      return false;
    }
    return _invokeBool('openManufacturerSettings');
  }

  /// Opens Android's app-scoped battery optimization exemption request.
  ///
  /// `true` means only that Android accepted the settings intent. It is not a
  /// grant acknowledgement. Read [getDeviceState] after the app resumes and
  /// inspect `batteryOptimizationsIgnored` for the current state.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!isSupported) {
      return false;
    }
    return _invokeBool('requestBatteryOptimizationExemption');
  }

  /// Opens the generic Android battery optimization settings list without
  /// submitting an app-scoped exemption request.
  Future<bool> openBatteryOptimizationSettings() async {
    if (!isSupported) {
      return false;
    }
    return _invokeBool('openBatteryOptimizationSettings');
  }

  ArmResult _parseArmResult(
    Map<String, dynamic> map, {
    required SessionToken proposedToken,
    required DateTime requestedMainDeadline,
    required DateTime requestedFinalDeadline,
  }) {
    final type = map['type']?.toString();
    final returnedToken = SessionToken.fromMap(map['token']);
    final mainDeadline = wireDate(map['mainDeadlineMs']);
    final finalDeadline = wireDate(map['finalDeadlineMs']);
    final tokenMatches =
        returnedToken != null &&
        returnedToken.isValid &&
        returnedToken.hasSameSessionIdentity(proposedToken) &&
        returnedToken.generation == proposedToken.generation;
    final deadlinesMatch =
        _sameWireInstant(mainDeadline, requestedMainDeadline) &&
        _sameWireInstant(finalDeadline, requestedFinalDeadline) &&
        !requestedFinalDeadline.isBefore(requestedMainDeadline);
    if (type == 'armed' && tokenMatches && deadlinesMatch) {
      return Armed(
        sessionToken: returnedToken,
        mainDeadline: mainDeadline!,
        finalDeadline: finalDeadline!,
      );
    }
    final reasonCode = map['reasonCode']?.toString() ?? 'malformedResponse';
    if (type == 'rejected') {
      return ArmRejected(
        reasonCode,
        rejectedToken: tokenMatches ? returnedToken : proposedToken,
      );
    }
    return ArmUnknown(
      reasonCode,
      uncertainToken: tokenMatches ? returnedToken : proposedToken,
    );
  }

  CancelResult _parseCancelResult(
    Map<String, dynamic> map,
    SessionToken requestedToken,
  ) {
    final token = SessionToken.fromMap(map['token']);
    if (token == null || token != requestedToken) {
      return SessionCancelUnknown(requestedToken, 'invalidToken');
    }
    return switch (map['type']?.toString()) {
      'cancelled' => SessionCancelled(token),
      'alreadyCancelled' => SessionAlreadyCancelled(token),
      'tooLate'
          when _isTooLateTerminal(
            EmergencySessionLifecycle.fromWire(map['terminalState']),
          ) =>
        SessionCancelTooLate(
          token,
          EmergencySessionLifecycle.fromWire(map['terminalState']),
        ),
      'stale' => SessionCancelStale(token),
      _ => SessionCancelUnknown(
        token,
        map['reasonCode']?.toString() ?? 'malformedResponse',
      ),
    };
  }

  CancelResult _reconcileCancel(
    SessionToken token,
    SessionSnapshot snapshot,
    String failureReason,
  ) {
    if (snapshot.token != token) {
      return SessionCancelUnknown(token, failureReason);
    }
    if (snapshot.lifecycleState == EmergencySessionLifecycle.cancelled) {
      return SessionAlreadyCancelled(token);
    }
    if (snapshot.lifecycleState == EmergencySessionLifecycle.claimed ||
        (snapshot.lifecycleState.isTerminal &&
            snapshot.lifecycleState != EmergencySessionLifecycle.corrupted)) {
      return SessionCancelTooLate(token, snapshot.lifecycleState);
    }
    return SessionCancelUnknown(token, failureReason);
  }

  SessionSnapshot _parseSnapshot(
    Map<String, dynamic> map, {
    required SessionToken requestedToken,
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
    if (token == null || token != requestedToken) {
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
    final callOutcome = _parseCallRequestOutcome(
      session['callRequestOutcome'] ?? map['callRequestOutcome'],
    );
    final fallbackOutcome = _parseFallbackOutcome(
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
      mainDeadline: mainDeadline,
      finalDeadline: finalDeadline,
      target: target,
      callRequestOutcome: callOutcome,
      fallbackOutcome: fallbackOutcome,
      reasonCode: map['reasonCode']?.toString(),
    );
  }

  SessionSnapshot _parseDiscoveredSnapshot(
    Map<String, dynamic> map, {
    required EmergencySessionKind requestedKind,
  }) {
    final type = map['type']?.toString();
    if (type == 'absent') {
      return SessionSnapshot(
        status: SessionReadStatus.absent,
        lifecycleState: EmergencySessionLifecycle.absent,
        reasonCode: map['reasonCode']?.toString(),
      );
    }
    if (type == 'corrupted') {
      return SessionSnapshot(
        status: SessionReadStatus.corrupted,
        lifecycleState: EmergencySessionLifecycle.corrupted,
        reasonCode: map['reasonCode']?.toString(),
      );
    }
    if (type != 'present') {
      return SessionSnapshot(
        status: SessionReadStatus.unknown,
        reasonCode: map['reasonCode']?.toString() ?? 'malformedResponse',
      );
    }
    final session = wireMap(map['session']);
    final token = SessionToken.fromMap(session?['token']);
    if (token == null || token.kind != requestedKind) {
      return const SessionSnapshot(
        status: SessionReadStatus.unknown,
        reasonCode: 'invalidDiscoveredToken',
      );
    }
    return _parseSnapshot(map, requestedToken: token);
  }

  DispatchResult _parseDispatchResult(
    Map<String, dynamic> map,
    SessionToken requestedToken,
  ) {
    final token = SessionToken.fromMap(map['token']);
    final callOutcome = _parseCallRequestOutcome(map['callRequestOutcome']);
    final fallbackOutcome = _parseFallbackOutcome(map['fallbackOutcome']);
    final terminalState = EmergencySessionLifecycle.fromWire(
      map['terminalState'],
    );
    if (token == null ||
        token != requestedToken ||
        callOutcome == null ||
        fallbackOutcome == null) {
      return _unknownDispatch(requestedToken);
    }
    final nothingAttempted =
        callOutcome == CallRequestOutcome.notAttempted &&
        fallbackOutcome == FallbackOutcome.notAttempted;
    final malformed =
        map['connectionState']?.toString() != 'unknown' ||
        terminalState == EmergencySessionLifecycle.unknown ||
        terminalState == EmergencySessionLifecycle.absent ||
        terminalState == EmergencySessionLifecycle.preparing ||
        (nothingAttempted && !terminalState.isTerminal);
    if (malformed) return _unknownDispatch(token);
    return DispatchResult(
      token: token,
      callRequestOutcome: callOutcome,
      fallbackOutcome: fallbackOutcome,
      terminalState: terminalState,
    );
  }

  DispatchResult _unknownDispatch(SessionToken token) => DispatchResult(
    token: token,
    callRequestOutcome: CallRequestOutcome.notAttempted,
    fallbackOutcome: FallbackOutcome.notAttempted,
    terminalState: EmergencySessionLifecycle.unknown,
    isUnknown: true,
  );

  bool _isTooLateTerminal(EmergencySessionLifecycle state) =>
      state == EmergencySessionLifecycle.claimed ||
      (state.isTerminal && state != EmergencySessionLifecycle.cancelled);

  bool _sameWireInstant(DateTime? actual, DateTime expected) =>
      actual?.millisecondsSinceEpoch == expected.millisecondsSinceEpoch;

  CallRequestOutcome? _parseCallRequestOutcome(Object? value) =>
      switch (value?.toString()) {
        'notAttempted' || 'not_attempted' => CallRequestOutcome.notAttempted,
        'submittedUnconfirmed' ||
        'submitted_unconfirmed' => CallRequestOutcome.submittedUnconfirmed,
        'failed' => CallRequestOutcome.failed,
        _ => null,
      };

  FallbackOutcome? _parseFallbackOutcome(Object? value) =>
      switch (value?.toString()) {
        'notAttempted' || 'not_attempted' => FallbackOutcome.notAttempted,
        'posted' => FallbackOutcome.posted,
        'failed' => FallbackOutcome.failed,
        'expired' => FallbackOutcome.expired,
        _ => null,
      };

  String _newRandomId() {
    final random = Random.secure();
    return List<String>.generate(
      8,
      (_) => random.nextInt(1 << 16).toRadixString(16).padLeft(4, '0'),
      growable: false,
    ).join();
  }

  Future<_TypedInvocation> _invokeTypedMap(
    String method, {
    Map<String, Object?>? arguments,
    Duration? timeout,
  }) async {
    try {
      final response = await _methodChannel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout ?? _defaultTimeout);
      final mapped = _toMap(response);
      if (mapped == null) {
        return const _TypedInvocation.failed('malformedResponse');
      }
      return _TypedInvocation.completed(mapped);
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] $method timed out');
      return const _TypedInvocation.failed('timeout');
    } on PlatformException {
      debugPrint('[EmergencyPlatform] $method failed');
      return const _TypedInvocation.failed('platformError');
    } on Exception {
      debugPrint('[EmergencyPlatform] $method failed');
      return const _TypedInvocation.failed('unexpectedError');
    }
  }

  Future<Map<String, dynamic>> _invokeMap(
    String method, {
    Map<String, Object?>? arguments,
    Duration? timeout,
  }) async {
    try {
      final response = await _methodChannel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout ?? _defaultTimeout);
      return _toMap(response) ?? const <String, dynamic>{};
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] $method timed out');
      return const <String, dynamic>{};
    } on PlatformException {
      debugPrint('[EmergencyPlatform] $method failed');
      return const <String, dynamic>{};
    } on Exception {
      debugPrint('[EmergencyPlatform] $method failed');
      return const <String, dynamic>{};
    }
  }

  Future<bool> _invokeBool(
    String method, {
    Map<String, Object?>? arguments,
  }) async {
    try {
      return await _methodChannel
              .invokeMethod<bool>(method, arguments)
              .timeout(_defaultTimeout) ??
          false;
    } on TimeoutException {
      debugPrint('[EmergencyPlatform] $method timed out');
      return false;
    } on PlatformException {
      debugPrint('[EmergencyPlatform] $method failed');
      return false;
    } on Exception {
      debugPrint('[EmergencyPlatform] $method failed');
      return false;
    }
  }

  Map<String, dynamic>? _toMap(dynamic event) {
    if (event is Map) {
      return event.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    await _eventsController.close();
  }
}

class _TypedInvocation {
  const _TypedInvocation.completed(this.value)
    : completed = true,
      reasonCode = '';

  const _TypedInvocation.failed(this.reasonCode)
    : completed = false,
      value = const <String, dynamic>{};

  final bool completed;
  final Map<String, dynamic> value;
  final String reasonCode;
}

@immutable
class PlatformReadinessSnapshot {
  const PlatformReadinessSnapshot({
    required this.supportedOs,
    required this.telephonyCalling,
    required this.telecomAvailable,
    required this.dialHandlerAvailable,
    required this.batteryOptimizationWhitelisted,
    required this.exactAlarmPermission,
    required this.callPermission,
    required this.notificationPermission,
    required this.alertChannelHigh,
  }) : isKnown = true,
       reasonCode = null;

  const PlatformReadinessSnapshot.unavailable({this.reasonCode})
    : isKnown = false,
      supportedOs = false,
      telephonyCalling = false,
      telecomAvailable = false,
      dialHandlerAvailable = false,
      batteryOptimizationWhitelisted = false,
      exactAlarmPermission = false,
      callPermission = false,
      notificationPermission = false,
      alertChannelHigh = false;

  final bool isKnown;
  final String? reasonCode;
  final bool supportedOs;
  final bool telephonyCalling;
  final bool telecomAvailable;
  final bool dialHandlerAvailable;
  final bool batteryOptimizationWhitelisted;
  final bool exactAlarmPermission;
  final bool callPermission;
  final bool notificationPermission;
  final bool alertChannelHigh;

  bool get backgroundAlertReady =>
      isKnown &&
      exactAlarmPermission &&
      notificationPermission &&
      alertChannelHigh;

  bool get automaticCallReady =>
      isKnown &&
      supportedOs &&
      telephonyCalling &&
      telecomAvailable &&
      dialHandlerAvailable &&
      callPermission;

  bool get criticalSafetyReady => backgroundAlertReady && automaticCallReady;

  static PlatformReadinessSnapshot? fromMap(Map<String, dynamic> map) {
    const requiredBooleanKeys = <String>{
      'supportedOs',
      'telephonyCalling',
      'telecomAvailable',
      'dialHandlerAvailable',
      'batteryOptimizationsIgnored',
      'canScheduleExactAlarms',
      'callPermissionGranted',
      'notificationsEnabled',
      'alertChannelHigh',
    };
    if (requiredBooleanKeys.any((key) => map[key] is! bool)) {
      return null;
    }
    return PlatformReadinessSnapshot(
      supportedOs: map['supportedOs'] as bool,
      telephonyCalling: map['telephonyCalling'] as bool,
      telecomAvailable: map['telecomAvailable'] as bool,
      dialHandlerAvailable: map['dialHandlerAvailable'] as bool,
      batteryOptimizationWhitelisted:
          map['batteryOptimizationsIgnored'] as bool,
      exactAlarmPermission: map['canScheduleExactAlarms'] as bool,
      callPermission: map['callPermissionGranted'] as bool,
      notificationPermission: map['notificationsEnabled'] as bool,
      alertChannelHigh: map['alertChannelHigh'] as bool,
    );
  }
}
