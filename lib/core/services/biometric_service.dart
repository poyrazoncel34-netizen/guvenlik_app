import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._();
  static BiometricService get instance => _instance;
  BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric auth is available on this device
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('BiometricService.isAvailable error: $e');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService.getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Authenticate user with biometrics
  Future<bool> authenticate({String? reason}) async {
    final localizedReason = reason ?? 'biometric_auth_reason'.tr();
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern fallback
        ),
      );
    } catch (e) {
      debugPrint('BiometricService.authenticate error: $e');
      return false;
    }
  }

  /// Get a human-readable label for the primary biometric type
  Future<String> getBiometricLabel() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'biometric_fingerprint'.tr();
    if (types.contains(BiometricType.iris)) return 'Iris';
    return 'biometric_default'.tr();
  }
}
