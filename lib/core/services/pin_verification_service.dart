import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/pin_hasher.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'emergency_session_contract.dart';

class PinVerificationResult {
  const PinVerificationResult({required this.state, required this.matches});

  final PinState state;
  final bool matches;
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
      // acknowledged; otherwise a later verification can silently fail. The
      // legacy plaintext is hashed on the way in, so it never lands in secure
      // storage in readable form.
      await _storage
          .write(
            key: SecureStorageKeys.userPin,
            value: PinHasher.encode(legacyPin),
          )
          .timeout(_operationTimeout);
      await preferences
          .remove(SecureStorageKeys.userPin)
          .timeout(_operationTimeout);
      return _state = PinState.configured;
    } catch (_) {
      return _state = PinState.readFailed;
    }
  }

  /// The ONLY way a PIN enters storage. Callers pass the PIN the user typed;
  /// what lands on disk is a salted hash they cannot reverse.
  Future<bool> writePin(String pin) async {
    if (pin.isEmpty) return false;
    try {
      await _storage
          .write(key: SecureStorageKeys.userPin, value: PinHasher.encode(pin))
          .timeout(_operationTimeout);
      final preferences = await _preferencesLoader().timeout(_operationTimeout);
      // A legacy plaintext copy in SharedPreferences must not outlive the
      // hashed record.
      await preferences.remove(SecureStorageKeys.userPin);
      _state = PinState.configured;
      return true;
    } catch (_) {
      _state = PinState.readFailed;
      return false;
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
          matches: await _matchesStoredRecord(migratedPin, candidate),
        );
      }

      _state = PinState.configured;
      return PinVerificationResult(
        state: PinState.configured,
        matches: await _matchesStoredRecord(configuredPin, candidate),
      );
    } catch (_) {
      return PinVerificationResult(
        state: _state = PinState.readFailed,
        matches: false,
      );
    }
  }

  /// Accepts both the hashed record and a raw PIN written by a pre-hash
  /// build. A correct legacy PIN is upgraded in place, so the plaintext copy
  /// disappears on first successful unlock without ever asking the user to
  /// re-enrol. A failed upgrade write does not fail the unlock: the user is
  /// already authenticated and the next attempt retries.
  Future<bool> _matchesStoredRecord(String stored, String candidate) async {
    if (PinHasher.isLegacyPlaintext(stored)) {
      final matches = _constantTimeEquals(candidate, stored);
      if (matches) {
        try {
          await _storage
              .write(
                key: SecureStorageKeys.userPin,
                value: PinHasher.encode(candidate),
              )
              .timeout(_operationTimeout);
        } catch (_) {
          // Keep the legacy record; the upgrade retries on the next unlock.
        }
      }
      return matches;
    }
    return PinHasher.matches(stored: stored, candidate: candidate);
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
