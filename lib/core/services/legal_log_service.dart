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
        'event': event,
        'timestamp': DateTime.now().toIso8601String(),
        'app_version': await _getAppVersion(),
      };
      if (feature != null) entry['feature'] = feature;
      if (result != null) entry['result'] = result;
      if (errorType != null) entry['error_type'] = errorType;
      if (checkboxes != null) entry['checkboxes'] = checkboxes;

      final logs = await _loadLogs();
      logs.add(entry);
      _pruneEntries(logs);
      await _saveLogs(logs);
    } catch (e) {
      debugPrint('[LegalLogService] logEvent error: $e');
    }
  }

  // ── Tüm kayıtları oku ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      return await _loadLogs();
    } catch (e) {
      debugPrint('[LegalLogService] getLogs error: $e');
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
    } catch (e) {
      debugPrint('[LegalLogService] deleteLogs error: $e');
    }
  }

  // ── Dahili: JSON dosyasını oku ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _loadLogs() async {
    final file = await _logFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final decoded = jsonDecode(content);
    if (decoded is Map && decoded.containsKey('legal_logs')) {
      return List<Map<String, dynamic>>.from(decoded['legal_logs'] as List);
    }
    return [];
  }

  // ── Dahili: JSON dosyasını yaz ───────────────────────────────────────────
  Future<void> _saveLogs(List<Map<String, dynamic>> logs) async {
    final file = await _logFile();
    final json = jsonEncode({'legal_logs': logs});
    await file.writeAsString(json, flush: true);
  }

  // ── Dahili: Eski / fazla kayıtları temizle ───────────────────────────────
  void _pruneEntries(List<Map<String, dynamic>> logs) {
    final cutoff = DateTime.now().subtract(Duration(days: _retentionYears * 365));
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
}
