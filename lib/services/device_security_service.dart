import 'dart:async';

import 'package:flutter/services.dart';
import '../core/services/local_logger_service.dart';

/// A probe that FAILED is not a device that is clean (audit A-017).
enum DeviceIntegrity { clean, compromised, unknown }

/// What one native check observed. Only [absent] is evidence of cleanliness.
enum ProbeOutcome { found, absent, error }

class DeviceSecurityService {
  DeviceSecurityService({
    MethodChannel channel = defaultChannel,
    Duration timeout = const Duration(seconds: 3),
  }) : _channel = channel,
       _timeout = timeout;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.poyrazoncel.korubeni/device_integrity',
  );

  /// Checks whose FOUND means compromised on any build.
  static const List<String> hardChecks = <String>[
    'suBinary',
    'magiskBinary',
    'superuserArtifacts',
    'pathSuBinary',
    'rwSystemMounts',
  ];

  /// Checks every eng/userdebug build trips; ignored only when the native
  /// side positively observed a development build (safe_device parity).
  static const List<String> buildChecks = <String>[
    'testKeys',
    'dangerousProps',
  ];

  static const String devEnvironmentCheck = 'developmentEnvironment';

  static const List<String> allChecks = <String>[
    ...hardChecks,
    ...buildChecks,
    devEnvironmentCheck,
  ];

  final MethodChannel _channel;
  final Duration _timeout;

  Future<DeviceIntegrity> checkIntegrity() async {
    final Object? raw;
    try {
      raw = await _channel.invokeMethod<Object?>('probe').timeout(_timeout);
    } on Exception {
      // PlatformException, MissingPluginException, TimeoutException.
      return _unknown();
    } on Error {
      // The probe runs on the splash path; an OEM-specific failure must not
      // crash startup. Catching does not produce a clean verdict.
      return _unknown();
    }
    final outcomes = parse(raw);
    if (outcomes == null) return _unknown();
    final verdict = aggregate(outcomes);
    if (verdict == DeviceIntegrity.unknown) return _unknown();
    return verdict;
  }

  /// Strict decoding of the native reply. Null when anything is off: not a
  /// map, a missing check, a non-string key or an unknown value.
  static Map<String, ProbeOutcome>? parse(Object? raw) {
    if (raw is! Map) return null;
    final result = <String, ProbeOutcome>{};
    for (final check in allChecks) {
      final value = raw[check];
      final outcome = switch (value) {
        'found' => ProbeOutcome.found,
        'absent' => ProbeOutcome.absent,
        'error' => ProbeOutcome.error,
        _ => null,
      };
      if (outcome == null) return null;
      result[check] = outcome;
    }
    return result;
  }

  /// FOUND anywhere that counts -> compromised; otherwise any ERROR that
  /// counts -> unknown; clean only when every counted check is ABSENT.
  static DeviceIntegrity aggregate(Map<String, ProbeOutcome> outcomes) {
    final lenient = outcomes[devEnvironmentCheck] == ProbeOutcome.found;
    final counted = <String>[...hardChecks, if (!lenient) ...buildChecks];
    if (counted.any((c) => outcomes[c] == ProbeOutcome.found)) {
      return DeviceIntegrity.compromised;
    }
    if (counted.any((c) => outcomes[c] != ProbeOutcome.absent)) {
      return DeviceIntegrity.unknown;
    }
    return DeviceIntegrity.clean;
  }

  Future<DeviceIntegrity> _unknown() async {
    await LocalLoggerService.instance.warningCode(
      LocalWarningCode.deviceIntegrityUnknown,
    );
    return DeviceIntegrity.unknown;
  }
}

// Why this no longer touches safe_device
// -------------------------------------
// safe_device 1.3.10 converts failures into "not rooted" twice: its Dart
// getter catches everything and returns false, and its Java checks (and
// RootBeer under them) treat EACCES, a failed exec or an unreadable mount
// table as absence. Reading its channel directly fixed only the first layer.
// The native probe (android/.../integrity/DeviceIntegrityProbe.kt) reports
// found / absent / error per check, and this file is the only place those are
// turned into a verdict. The dependency stays in pubspec.yaml for this round;
// nothing at runtime calls it.
//
// Why `unknown` does not raise the warning dialog
// -----------------------------------------------
// It is not an accusation. The dialog is dismissible anyway, and locking
// someone out of their own phone is not the right answer in a duress model.
// What A-017 asks for is that a silent failure stop being recorded as
// "clean"; it is recorded, locally and allowlisted, as its own state.
