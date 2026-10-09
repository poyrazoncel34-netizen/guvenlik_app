import 'dispatch_outcome.dart';
import 'emergency_snapshot_parser.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_intent_service.dart';
import 'emergency_platform_channel.dart';
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
  late final EmergencyPlatformChannel _channel = EmergencyPlatformChannel(
    _methodChannel,
    defaultTimeout: _defaultTimeout,
  );
  final bool? _supportedOverride;
  final Duration _defaultTimeout;
  final Duration _dispatchTimeout;
  static const EventChannel _eventChannel = EventChannel(
    'com.poyrazoncel.korubeni/emergency_platform/events',
  );

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<Object?>? _eventsSubscription;
  bool _initialized = false;

  bool get isSupported =>
      _supportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// True once any invocation proved the native handler is not registered.
  ///
  /// [isSupported] answers a DIFFERENT question: it reports that this is an
  /// Android build, never that MainActivity actually installed the emergency
  /// MethodChannel. MainActivity wraps that installation in a catch that only
  /// writes `EMERGENCY_PLATFORM_CONFIG_FAILED` to logcat, which a release user
  /// cannot read; the arm path then saw a MissingPluginException, folded it
  /// into the generic `unexpectedError`, and a countdown started looking
  /// exactly like a protected one while no native AlarmManager session
  /// existed (audit A-005).
  ///
  /// The audit's first suggestion -- have MainActivity persist a flag for Dart
  /// to read -- cannot work: the only way Dart could read it is the channel
  /// that is broken. Distinguishing the exception here is the one signal that
  /// survives, and it is the audit's own stated alternative.
  ///
  /// Latching (never cleared) is deliberate: the engine configures its
  /// channels once per FlutterEngine, so a bridge that was absent does not
  /// reappear within the process, and a safety signal must not flicker back
  /// to "fine" because a later call happened to time out instead.
  bool get platformBridgeMissing => _channel.bridgeMissing;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> initialize() async {
    if (!isSupported || _initialized) {
      return;
    }

    _eventsSubscription = _eventChannel.receiveBroadcastStream().listen((
      Object? event,
    ) {
      final mapped = EmergencyPlatformChannel.toMap(event);
      if (mapped != null) {
        _eventsController.add(mapped);
      }
    }, onError: _eventsController.addError);

    _initialized = true;
  }

  /// Arm a versioned native safety session. A malformed response is never
  /// treated as an acknowledgement. Timeout/error reconciles with the same
  /// proposed token and remains [ArmUnknown] unless native durable state proves
  /// the session is armed. A missing native bridge is the exception: it is a
  /// definitive [ArmRejected], because the call never reached native code.
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

    final invocation = await _channel.invokeTypedMap(
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
      if (invocation.reasonCode ==
          EmergencyPlatformChannel.bridgeMissingReason) {
        // MissingPluginException means no native handler received the arm, so
        // no session exists -- that is certainty, not uncertainty. Reporting
        // it as ArmUnknown let a countdown start with nothing native behind it
        // and made the PIN cancel unconfirmable (the cancel crosses the same
        // missing bridge), trapping the user in it (audit A-005).
        return ArmRejected(
          EmergencyPlatformChannel.bridgeMissingReason,
          rejectedToken: proposedToken,
        );
      }
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
    final invocation = await _channel.invokeTypedMap(
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

  Future<DispatchTargetOutcome> warnEmergencySession(
    SessionToken token, {
    bool preWarning = false,
  }) async {
    final result = await _channel.invokeTypedMap(
      'warnEmergencySession',
      arguments: {'token': token.toMap(), 'preWarning': preWarning},
    );
    if (!result.completed) return DispatchTargetOutcome.handoffUnconfirmed;
    return switch (result.value['outcome']) {
      'posted' => DispatchTargetOutcome.handoffAccepted,
      'failed' => DispatchTargetOutcome.platformRejected,
      'stale' => DispatchTargetOutcome.notAttempted,
      _ => DispatchTargetOutcome.handoffUnconfirmed,
    };
  }

  Future<List<SessionSnapshot>> pendingEmergencyOutcomes() async {
    final result = await _channel.invokeTypedMap('pendingEmergencyOutcomes');
    if (!result.completed || result.value['outcomes'] is! List) return [];
    return (result.value['outcomes'] as List)
        .map(
          (value) =>
              parseSessionSnapshot(wireMap(value) ?? <String, dynamic>{}),
        )
        .toList();
  }

  Future<void> acknowledgeEmergencyOutcome(SessionToken token) async {
    await _channel.invokeTypedMap(
      'acknowledgeEmergencyOutcome',
      arguments: {
        'protocolVersion': emergencyProtocolVersion,
        'token': token.toMap(),
      },
    );
  }

  /// App-private MethodChannel discovery; no intent or exported component.
  Future<SessionSnapshot> discoverEmergencySession(
    EmergencySessionKind kind,
  ) async {
    final invocation = await _channel.invokeTypedMap(
      'discoverEmergencySession',
      arguments: {
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
    return parseSessionSnapshot(invocation.value, requestedKind: kind);
  }

  Future<SessionSnapshot> readEmergencySession(SessionToken token) async {
    if (!isSupported) {
      return const SessionSnapshot(
        status: SessionReadStatus.unknown,
        reasonCode: 'unsupportedPlatform',
      );
    }
    final invocation = await _channel.invokeTypedMap(
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
    return parseSessionSnapshot(invocation.value, requestedToken: token);
  }

  Future<DispatchResult> dispatchEmergencySession({
    required SessionToken token,
    required String source,
  }) async {
    if (!isSupported) {
      return _unknownDispatch(token);
    }
    final invocation = await _channel.invokeTypedMap(
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

  /// The device's elapsedRealtime and boot identity, or null when unavailable.
  /// Dart has no monotonic clock that outlives its process; the PIN lockout
  /// needs one so a changed wall clock cannot end or stretch it (audit Y-05).
  Future<({int elapsedMs, int bootCount, String? bootId})?>
  readMonotonicClock() async {
    if (!isSupported) return null;
    final invocation = await _channel.invokeTypedMap(
      'readMonotonicClock',
      timeout: const Duration(milliseconds: 500),
    );
    if (!invocation.completed) return null;
    final elapsed = wireInt(invocation.value['elapsedRealtimeMs']);
    final boot = wireInt(invocation.value['bootCount']);
    if (elapsed == null || elapsed < 0 || boot == null) return null;
    final id = invocation.value['bootId'];
    return (
      elapsedMs: elapsed,
      bootCount: boot,
      bootId: id is String && id.isNotEmpty && id.length <= 64 ? id : null,
    );
  }

  Future<CapabilitySnapshot> getEmergencyCapabilities({
    required EntitlementDecision entitlementDecision,
    required bool pinConfigured,
    required bool callableTarget,
  }) async {
    if (!isSupported) return const CapabilitySnapshot.unavailable();
    final invocation = await _channel.invokeTypedMap(
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
    final invocation = await _channel.invokeTypedMap(
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
    return _channel.invokeMap('consumePendingTrigger');
  }

  Future<Map<String, dynamic>> getDeviceState() async {
    if (!isSupported) {
      return const <String, dynamic>{};
    }
    return _channel.invokeMap('getDeviceState');
  }

  /// Returns a bounded, allowlisted projection of native Direct Boot safety
  /// failures for the user's explicit local-data export. Unknown codes,
  /// malformed values and caller-controlled extra fields are discarded.
  Future<List<Map<String, Object?>>> readNativeSafetyDiagnostics() async {
    if (!isSupported) return const <Map<String, Object?>>[];
    final response = await _channel.invokeRaw('readNativeSafetyDiagnostics');
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
    final invocation = await _channel.invokeTypedMap('getDeviceState');
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
    return await _channel.invokeBool('canScheduleExactAlarms');
  }

  Future<void> requestExactAlarmPermission() async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeVoid('requestExactAlarmPermission');
  }

  Future<bool> openManufacturerSettings() async {
    if (!isSupported) {
      return false;
    }
    return _channel.invokeBool('openManufacturerSettings');
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
    return _channel.invokeBool('requestBatteryOptimizationExemption');
  }

  /// Opens the generic Android battery optimization settings list without
  /// submitting an app-scoped exemption request.
  Future<bool> openBatteryOptimizationSettings() async {
    if (!isSupported) {
      return false;
    }
    return _channel.invokeBool('openBatteryOptimizationSettings');
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

  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    await _eventsController.close();
  }
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
