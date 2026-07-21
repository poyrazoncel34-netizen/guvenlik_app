// ============================================================================
// HUKUKİ LOG SERVİSİ — TBK Md. 50 ispat kaydı, KVKK Md. 12 uyumlu
// Kural: Kişisel veri (isim, telefon, konum koordinatı) KESİNLİKLE kaydedilmez.
// Yalnızca: event tipi + feature adı + timestamp + başarı/hata kodu
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class LegalLogService {
  LegalLogService._();
  static final LegalLogService instance = LegalLogService._();

  static const String _logFileName = 'legal_logs.json';
  static const int _maxEntries = 500;
  static const int _retentionYears = 2;
  static final RegExp _codePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static const int _maxCheckboxes = 16;

  String? _cachedVersion;

  // ── Yeni olay kaydet ──────────────────────────────────────────────────────
  Future<void> logEvent(
    String event, {
    String? feature,
    String? result,
    String? errorType,
    List<String>? checkboxes,
  }) async {
    try {
      final entry = <String, dynamic>{
        'event': _safeCode(event, fallback: 'invalid_event'),
        'timestamp': DateTime.now().toIso8601String(),
        'app_version': await _getAppVersion(),
      };
      if (feature != null) {
        entry['feature'] = _safeCode(feature, fallback: 'invalid_feature');
      }
      if (result != null) {
        entry['result'] = _safeCode(result, fallback: 'invalid_result');
      }
      if (errorType != null) {
        entry['error_type'] = _safeCode(
          errorType,
          fallback: 'invalid_error_type',
        );
      }
      if (checkboxes != null) {
        entry['checkboxes'] = checkboxes
            .take(_maxCheckboxes)
            .map((value) => _safeCode(value, fallback: 'invalid_checkbox'))
            .toSet()
            .toList(growable: false);
      }

      final logs = await _loadLogs();
      logs.add(entry);
      _pruneEntries(logs);
      await _saveLogs(logs);
    } catch (_) {
      debugPrint('[LegalLogService] logEvent failed');
    }
  }

  // ── Tüm kayıtları oku ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      return await _loadLogs();
    } catch (_) {
      debugPrint('[LegalLogService] getLogs failed');
      return [];
    }
  }

  // ── Tüm kayıtları sil ────────────────────────────────────────────────────
  Future<void> deleteLogs() async {
    try {
      final file = await _logFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      debugPrint('[LegalLogService] deleteLogs failed');
    }
  }

  // ── Dahili: JSON dosyasını oku ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _loadLogs() async {
    final file = await _logFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map && decoded['legal_logs'] is List) {
        final raw = decoded['legal_logs'] as List;
        // Per-item filter so a single garbled entry can't poison the
        // whole audit log. Non-map rows are silently dropped.
        return raw
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      // Decoded successfully but the shape is wrong (missing key or wrong
      // type). Fall through to recovery — preserve nothing rather than
      // crashing every subsequent logEvent() call.
      throw const FormatException(
        'legal_logs file is valid JSON but the shape is unexpected',
      );
    } on FormatException {
      // Corrupted file (half-write, manual edit, schema drift). Rewrite it
      // with the empty container so the next logEvent() can append again.
      debugPrint('[LegalLogService] _loadLogs: recovering from malformed file');
      await _recoverEmptyFile(file);
      return [];
    } on TypeError {
      debugPrint('[LegalLogService] _loadLogs: recovering from type error');
      await _recoverEmptyFile(file);
      return [];
    }
  }

  // Best-effort recovery: replace the corrupted file with a valid empty
  // container so logging resumes on the next write. Failures here are
  // intentionally swallowed — write attempts will still fail loudly via
  // their own try/catch in logEvent.
  Future<void> _recoverEmptyFile(File file) async {
    try {
      await file.writeAsString(
        jsonEncode({'legal_logs': <Map<String, dynamic>>[]}),
        flush: true,
      );
      debugPrint('[LegalLogService] _loadLogs: recovery wrote empty container');
    } catch (_) {
      debugPrint('[LegalLogService] _loadLogs: recovery write failed');
    }
  }

  // ── Dahili: JSON dosyasını yaz ───────────────────────────────────────────
  Future<void> _saveLogs(List<Map<String, dynamic>> logs) async {
    final file = await _logFile();
    final json = jsonEncode({'legal_logs': logs});
    await file.writeAsString(json, flush: true);
  }

  // ── Dahili: Eski / fazla kayıtları temizle ───────────────────────────────
  void _pruneEntries(List<Map<String, dynamic>> logs) {
    final cutoff = DateTime.now().subtract(
      const Duration(days: _retentionYears * 365),
    );
    logs.removeWhere((entry) {
      try {
        final ts = DateTime.parse(entry['timestamp'] as String);
        return ts.isBefore(cutoff);
      } catch (_) {
        return false;
      }
    });
    // Max 500 kayıt — eski kayıtlar önce silinir
    while (logs.length > _maxEntries) {
      logs.removeAt(0);
    }
  }

  // ── Dahili: Log dosya yolu ───────────────────────────────────────────────
  Future<File> _logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_logFileName');
  }

  // ── Dahili: Uygulama versiyonu (cache'li) ────────────────────────────────
  Future<String> _getAppVersion() async {
    _cachedVersion ??= (await PackageInfo.fromPlatform()).version;
    return _cachedVersion!;
  }

  static String _safeCode(String value, {required String fallback}) {
    return _codePattern.hasMatch(value) ? value : fallback;
  }
}
