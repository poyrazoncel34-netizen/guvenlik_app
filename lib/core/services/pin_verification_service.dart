import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'emergency_session_contract.dart';

class PinVerificationResult {
  const PinVerificationResult({required this.state, required this.matches});

  final PinState state;
  final bool matches;
}

enum PinChangeOutcome {
  changed,
  currentMismatch,
  sameAsCurrent,
  absent,
  readFailed,
  unknown,
}

/// Verifies the safety PIN without ever exposing the configured PIN to a
/// widget. Only the non-secret [PinState] is cached.
class PinVerificationService {
  PinVerificationService._({
    SecureStorage? secureStorage,
    Future<SharedPreferences> Function()? preferencesLoader,
    Duration operationTimeout = const Duration(seconds: 2),
  }) : _injectedStorage = secureStorage,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _operationTimeout = operationTimeout;

  factory PinVerificationService.forTesting({
    required SecureStorage secureStorage,
    Future<SharedPreferences> Function()? preferencesLoader,
    Duration operationTimeout = const Duration(milliseconds: 100),
  }) => PinVerificationService._(
    secureStorage: secureStorage,
    preferencesLoader: preferencesLoader,
    operationTimeout: operationTimeout,
  );

  static final PinVerificationService instance = PinVerificationService._();

  final SecureStorage? _injectedStorage;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Duration _operationTimeout;

  SecureStorage get _storage =>
      _injectedStorage ?? serviceLocator<SecureStorage>();

  PinState _state = PinState.loading;
  Future<PinState>? _loadInProgress;

  PinState get state => _state;

  Future<PinState> loadState() {
    return _loadInProgress ??= _loadStateOnce().whenComplete(() {
      _loadInProgress = null;
    });
  }

  Future<PinState> _loadStateOnce() async {
    _state = PinState.loading;
    try {
      final securePin = await _storage
          .read(key: SecureStorageKeys.userPin)
          .timeout(_operationTimeout);
      if (securePin != null && securePin.isNotEmpty) {
        return _state = PinState.configured;
      }

      final preferences = await _preferencesLoader().timeout(_operationTimeout);
      final legacyPin = preferences.getString(SecureStorageKeys.userPin);
      if (legacyPin == null || legacyPin.isEmpty) {
        return _state = PinState.absent;
      }

      // One-way migration. Do not report configured until the secure write is
      // acknowledged; otherwise a later verification can silently fail.
      await _storage
          .write(key: SecureStorageKeys.userPin, value: legacyPin)
          .timeout(_operationTimeout);
      await preferences
          .remove(SecureStorageKeys.userPin)
          .timeout(_operationTimeout);
      return _state = PinState.configured;
    } catch (_) {
      return _state = PinState.readFailed;
    }
  }

  Future<PinVerificationResult> verify(String candidate) async {
    if (candidate.isEmpty) {
      return PinVerificationResult(state: _state, matches: false);
    }

    try {
      final configuredPin = await _storage
          .read(key: SecureStorageKeys.userPin)
          .timeout(_operationTimeout);
      if (configuredPin == null || configuredPin.isEmpty) {
        final refreshedState = await loadState();
        if (refreshedState != PinState.configured) {
          return PinVerificationResult(state: refreshedState, matches: false);
        }
        final migratedPin = await _storage
            .read(key: SecureStorageKeys.userPin)
            .timeout(_operationTimeout);
        if (migratedPin == null || migratedPin.isEmpty) {
          return PinVerificationResult(
            state: _state = PinState.readFailed,
            matches: false,
          );
        }
        return PinVerificationResult(
          state: PinState.configured,
          matches: _constantTimeEquals(candidate, migratedPin),
        );
      }

      _state = PinState.configured;
      return PinVerificationResult(
        state: PinState.configured,
        matches: _constantTimeEquals(candidate, configuredPin),
      );
    } catch (_) {
      return PinVerificationResult(
        state: _state = PinState.readFailed,
        matches: false,
      );
    }
  }

  /// Replaces a PIN only after the current candidate is verified. The stored
  /// PIN never crosses this service boundary. [unknown] means a write was
  /// attempted but could not be read back, so callers must not claim success.
  Future<PinChangeOutcome> changePin({
    required String currentCandidate,
    required String newCandidate,
  }) async {
    final current = await verify(currentCandidate);
    if (current.state == PinState.absent) return PinChangeOutcome.absent;
    if (current.state != PinState.configured) {
      return PinChangeOutcome.readFailed;
    }
    if (!current.matches) return PinChangeOutcome.currentMismatch;
    if (_constantTimeEquals(currentCandidate, newCandidate)) {
      return PinChangeOutcome.sameAsCurrent;
    }

    try {
      await _storage
          .write(key: SecureStorageKeys.userPin, value: newCandidate)
          .timeout(_operationTimeout);
      final acknowledged = await _storage
          .read(key: SecureStorageKeys.userPin)
          .timeout(_operationTimeout);
      if (acknowledged == null ||
          !_constantTimeEquals(acknowledged, newCandidate)) {
        return PinChangeOutcome.unknown;
      }
      final preferences = await _preferencesLoader().timeout(_operationTimeout);
      await preferences
          .remove(SecureStorageKeys.userPin)
          .timeout(_operationTimeout);
      _state = PinState.configured;
      return PinChangeOutcome.changed;
    } catch (_) {
      return PinChangeOutcome.unknown;
    }
  }

  bool _constantTimeEquals(String left, String right) {
    var difference = left.length ^ right.length;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final leftCode = index < left.length ? left.codeUnitAt(index) : 0;
      final rightCode = index < right.length ? right.codeUnitAt(index) : 0;
      difference |= leftCode ^ rightCode;
    }
    return difference == 0;
  }
}
