// ============================================================================
// LOCAL LOGGER — Üretim ortamı için yerel dosya tabanlı hata kaydedici
// ============================================================================
// debugPrint() sadece debug build'lerinde çalışır; release build'lerde
// hatalar sessizce kaybolur. Bu servis aynı bilgiyi yerel bir dosyaya yazar.
// Hiçbir veri cihaz dışına çıkmaz (sunucu, analytics, Crashlytics yok).
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LocalErrorCode {
  flutterFrameworkUnhandled('flutter_framework_unhandled'),
  platformDispatcherUnhandled('platform_dispatcher_unhandled'),
  revenueCatInitializeFailed('revenuecat_initialize_failed'),
  revenueCatLegalStateReadFailed('revenuecat_legal_state_read_failed'),
  revenueCatPriorProHintReadFailed('revenuecat_prior_pro_hint_read_failed'),
  revenueCatPriorProHintWriteFailed('revenuecat_prior_pro_hint_write_failed'),
  revenueCatProAnchorReadFailed('revenuecat_pro_anchor_read_failed'),
  revenueCatProAnchorWriteFailed('revenuecat_pro_anchor_write_failed'),
  revenueCatCustomerInfoFailed('revenuecat_customer_info_failed'),
  revenueCatOfferingsFailed('revenuecat_offerings_failed'),
  revenueCatPurchaseFailed('revenuecat_purchase_failed'),
  revenueCatRestoreFailed('revenuecat_restore_failed');

  const LocalErrorCode(this.wireCode);
  final String wireCode;
}

enum LocalWarningCode {
  revenueCatLegalAcceptanceRequired('revenuecat_legal_acceptance_required'),
  revenueCatDisabledInSmoke('revenuecat_disabled_in_smoke'),
  revenueCatApiKeyMissing('revenuecat_api_key_missing'),
  safetySessionDispatchUnknown('safety_session_dispatch_unknown'),
  safetySessionDialerFallback('safety_session_dialer_fallback'),

  /// A safety WARNING notification (Check-In grace, Safe Walk pre-expiry) did
  /// not reach the user: switched off in app settings, or POST_NOTIFICATIONS
  /// revoked. The code carries no channel, no session and no contact -- only
  /// the fact that a warning surface was unavailable when it mattered.
  safetyAlertNotDelivered('safety_alert_not_delivered'),

  /// A quick-access panic request arrived with no root navigator mounted, so
  /// there was no surface to open a countdown on OR to explain the refusal on.
  quickPanicNavigatorUnavailable('quick_panic_navigator_unavailable'),

  /// The safety-history store could not be read; the timeline showed the
  /// user's notes and said the event list may be incomplete.
  timelineActivityUnreadable('timeline_activity_unreadable'),

  /// The root/jailbreak probe could not produce a verdict: plugin missing,
  /// channel error, or a non-boolean reply. Recorded because the previous
  /// behaviour -- reporting a failed probe as a clean device -- was fail-open
  /// in the one scenario where the offline entitlement anchor and local data
  /// are readable. Carries no device identifier, only the fact of the failure.
  deviceIntegrityUnknown('device_integrity_unknown'),

  /// The native emergency MethodChannel is not registered in this process, so
  /// the Doze-proof AlarmManager session cannot be armed at all. The readiness
  /// snapshot already reports not-ready in this case (every field is unknown),
  /// but nothing recorded WHY, and logcat is unreadable in release.
  emergencyPlatformBridgeMissing('emergency_platform_bridge_missing'),

  /// The PIN brute-force counters could not be read, so the lock screen does
  /// not know how many attempts have already failed. Recorded because the
  /// previous behaviour -- treating an unreadable counter as "0 failures, not
  /// locked" -- silently DISARMED the only lockout enforcement point (PIN
  /// verification itself never consults the lockout service) with no trace.
  /// Carries no PIN material and no counter value, only the fact of failure.
  pinLockoutStateUnreadable('pin_lockout_state_unreadable'),

  /// A failed PIN attempt could not be DEBITED to the brute-force counters, so
  /// the attempt happened without being counted. Distinct from
  /// [pinLockoutStateUnreadable]: there the counters could not be READ, here a
  /// readable counter could not be advanced. The distinction matters because
  /// only this one means the stored count is now lower than the real number of
  /// attempts. Previously this failure reached nothing but `debugPrint`, which
  /// release compiles out, so the one surface enforcing the lockout silently
  /// stopped enforcing it. Carries no PIN material and no counter value.
  pinLockoutRegisterFailed('pin_lockout_register_failed');

  const LocalWarningCode(this.wireCode);
  final String wireCode;
}

class LocalLoggerService {
  static final LocalLoggerService _instance = LocalLoggerService._();
  static LocalLoggerService get instance => _instance;
  LocalLoggerService._();

  static const String _logFileName = 'korubeni_errors.log';
  static const int _maxLines = 200;

  File? _logFile;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_logFileName');
      _initialized = true;
      debugPrint('LocalLogger: initialized at ${_logFile!.path}');
    } catch (e) {
      debugPrint('LocalLogger: init failed: $e');
    }
  }

  /// Persists only an allowlisted code. Exception text and stacks can contain
  /// PINs, customer identifiers, coordinates, URIs or contact data.
  Future<void> errorCode(LocalErrorCode code) async {
    final msg = _format('ERROR', 'runtime', code.wireCode, null);
    assert(() {
      debugPrint(msg);
      return true;
    }());
    await _write(msg);
  }

  /// Persists only an allowlisted warning code. Free-form SDK errors and user
  /// values are intentionally not accepted by the release diagnostics API.
  Future<void> warningCode(LocalWarningCode code) async {
    final msg = _format('WARN', 'runtime', code.wireCode, null);
    assert(() {
      debugPrint(msg);
      return true;
    }());
    await _write(msg);
  }

  /// Log an informational message (only in debug builds to avoid log bloat).
  void info(String tag, String message) {
    assert(() {
      debugPrint(_format('INFO', tag, message, null));
      return true;
    }());
  }

  String _format(String level, String tag, String message, String? stack) {
    final ts = DateTime.now().toIso8601String();
    final safeMessage = redactSensitive(message);
    final safeStack = stack == null ? null : redactSensitive(stack);
    final base = '[$ts][$level][$tag] $safeMessage';
    return safeStack != null ? '$base\n$safeStack' : base;
  }

  static String redactSensitive(String value) {
    return value
        .replaceAll(RegExp(r'\+?\d[\d\s\-\(\)]{6,}\d'), '[redacted-phone]')
        .replaceAll(
          RegExp(r'\b[-+]?\d{1,2}\.\d{4,}\s*,\s*[-+]?\d{1,3}\.\d{4,}\b'),
          '[redacted-location]',
        )
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '[redacted-email]',
        )
        .replaceAll(RegExp(r'(/[A-Za-z0-9._-]+){2,}'), '[redacted-path]');
  }

  Future<void> _write(String line) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
      await _rotate();
    } catch (e) {
      debugPrint('LocalLogger: write skipped: ${e.runtimeType}');
    }
  }

  /// Keep file under _maxLines by trimming the oldest entries.
  Future<void> _rotate() async {
    try {
      final file = _logFile!;
      if (!await file.exists()) return;
      final lines = await file.readAsLines();
      if (lines.length > _maxLines) {
        final trimmed = lines.skip(lines.length - _maxLines).join('\n');
        await file.writeAsString('$trimmed\n');
      }
    } catch (e) {
      debugPrint('LocalLogger: rotate skipped: ${e.runtimeType}');
    }
  }

  /// Returns the full log content for display in a debug screen.
  Future<String> readLogs() async {
    try {
      if (_logFile == null || !await _logFile!.exists()) return '';
      return await _logFile!.readAsString();
    } catch (e) {
      debugPrint('LocalLogger: read skipped: ${e.runtimeType}');
      return '';
    }
  }

  /// Clears the log file.
  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      debugPrint('LocalLogger: clear skipped: ${e.runtimeType}');
    }
  }
}
