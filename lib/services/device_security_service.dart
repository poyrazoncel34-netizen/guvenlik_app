import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import '../core/services/local_logger_service.dart';

/// A probe that FAILED is not a device that is clean (audit A-017).
enum DeviceIntegrity { clean, compromised, unknown }

class DeviceSecurityService {
  static const MethodChannel _channel = MethodChannel('safe_device');

  Future<DeviceIntegrity> checkIntegrity() async {
    try {
      SafeDevice.ensureInitiated();
      final raw = await _channel.invokeMethod<bool>('isJailBroken');
      if (raw == null) return _unknown();
      return raw ? DeviceIntegrity.compromised : DeviceIntegrity.clean;
    } on Exception {
      return _unknown();
    } on Error {
      // The probe runs on the splash path. An OEM-specific failure must not
      // crash startup -- that is why the original code caught everything. The
      // change is not that it stops catching, it is that catching no longer
      // produces a clean verdict.
      return _unknown();
    }
  }

  Future<DeviceIntegrity> _unknown() async {
    await LocalLoggerService.instance.warningCode(
      LocalWarningCode.deviceIntegrityUnknown,
    );
    return DeviceIntegrity.unknown;
  }
}

// Why this reads the platform channel instead of `SafeDevice.isJailBroken`
// ----------------------------------------------------------------------
// It looks like a layering violation, and fixing only our own `catch` would
// have looked like a fix. It would not have been one: safe_device 1.3.10 does
//
//     static Future<bool> get isJailBroken async {
//       try { ... } catch (e) { print(...); return false; }
//     }
//
// so the failure is already converted to "not rooted" ONE LEVEL DOWN, before
// our code ever sees it. A missing plugin, a revoked permission, an OEM
// implementation that throws, or a null reply all arrive at the caller as a
// confident `false`, indistinguishable from a genuinely clean device. Our
// `catch (e) { return false; }` was therefore not the fail-open -- it was a
// second, unreachable copy of it.
//
// Reading the same channel directly is the only way the three outcomes stay
// distinguishable. `SafeDevice.ensureInitiated()` is still called first, so
// the plugin's own init contract (a one-shot `init` invocation carrying the
// default config) is honoured exactly as before; only the error handling is
// ours.
//
// Why `unknown` does not raise the warning dialog
// -----------------------------------------------
// It is not an accusation. Turning every probe failure into a security
// warning would show a scary dialog to users whose device is fine but whose
// OEM build trips the plugin, and the dialog is dismissible anyway -- locking
// someone out of their own phone is not the right answer in a duress model.
// What A-017 asks for is that a silent failure stop being recorded as "clean";
// it is now recorded, locally and allowlisted, as its own state.
