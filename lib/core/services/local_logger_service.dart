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
  safetySessionDialerFallback('safety_session_dialer_fallback');

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
