// ============================================================================
// CONSENT MANAGER — KVKK Rıza Yönetim Servisi
// Tüm rızaları flutter_secure_storage üzerinde JSON olarak saklar.
// Her işlemde audit log oluşturulur.
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/security/secure_storage_keys.dart';
import '../models/consent_record.dart';
import '../constants/legal_texts.dart';

class ConsentManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Mevcut onaylı rıza durumu (bellek önbelleği) ──────────────────────────
  final Map<String, bool> _consentCache = {};
  bool _initialized = false;

  // ── Singleton başlatma ────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadConsentCache();
    _initialized = true;
  }

  Future<void> _loadConsentCache() async {
    try {
      final raw = await _storage.read(key: SecureStorageKeys.consentLog);
      if (raw == null || raw.isEmpty) return;
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      // Son durumu bul (her tür için en son kaydı al)
      final Map<String, ConsentRecord> latest = {};
      for (final item in list) {
        final record = ConsentRecord.fromJson(item as Map<String, dynamic>);
        final existing = latest[record.consentType];
        if (existing == null || record.timestamp.isAfter(existing.timestamp)) {
          latest[record.consentType] = record;
        }
      }
      for (final entry in latest.entries) {
        _consentCache[entry.key] = entry.value.granted;
      }
    } catch (e) {
      debugPrint('[ConsentManager] _loadConsentCache hata: $e');
    }
  }

  // ── Rıza ver ──────────────────────────────────────────────────────────────
  Future<void> grantConsent(String consentType, {String? locale}) async {
    await _recordConsent(
      consentType: consentType,
      granted: true,
      locale: locale,
    );
    _consentCache[consentType] = true;
  }

  // ── Rızayı geri çek ───────────────────────────────────────────────────────
  Future<void> revokeConsent(String consentType, {String? locale}) async {
    await _recordConsent(
      consentType: consentType,
      granted: false,
      locale: locale,
    );
    _consentCache[consentType] = false;
  }

  // ── Rıza durumu sorgula ───────────────────────────────────────────────────
  bool isGranted(String consentType) {
    return _consentCache[consentType] ?? false;
  }

  // ── Tüm aktif rızalar ─────────────────────────────────────────────────────
  Map<String, bool> getAllConsentStatus() {
    return Map.unmodifiable(_consentCache);
  }

  // ── Tüm log kayıtları ─────────────────────────────────────────────────────
  Future<List<ConsentRecord>> getAllLogs() async {
    try {
      final raw = await _storage.read(key: SecureStorageKeys.consentLog);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ConsentManager] getAllLogs hata: $e');
      return [];
    }
  }

  // ── Dışa aktarım (KVKK Madde 11/ğ) ───────────────────────────────────────
  Future<Map<String, dynamic>> exportConsentLog() async {
    final logs = await getAllLogs();
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': await _getAppVersion(),
      'consentLog': logs.map((e) => e.toJson()).toList(),
      'currentStatus': _consentCache,
    };
  }

  // ── Tüm rızaları sıfırla (veri silme) ────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.delete(key: SecureStorageKeys.consentLog);
    _consentCache.clear();
    // SharedPreferences legal flags temizle
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_legal_disclaimer_accepted');
    await prefs.remove('pref_terms_version');
    await prefs.remove('pref_kvkk_version');
    await prefs.remove('pref_fake_call_warned');
    _initialized = false;
  }

  // ── Terimler/KVKK versiyonu kontrol ──────────────────────────────────────
  Future<bool> needsReConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTerms = prefs.getString('pref_terms_version') ?? '';
    final savedKvkk = prefs.getString('pref_kvkk_version') ?? '';
    return savedTerms != LegalTexts.termsVersion ||
        savedKvkk != LegalTexts.kvkkVersion;
  }

  Future<void> markLegalVersionsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_terms_version', LegalTexts.termsVersion);
    await prefs.setString('pref_kvkk_version', LegalTexts.kvkkVersion);
    await prefs.setBool('pref_legal_disclaimer_accepted', true);
  }

  // ── Kayıt oluştur ─────────────────────────────────────────────────────────
  Future<void> _recordConsent({
    required String consentType,
    required bool granted,
    String? locale,
  }) async {
    try {
      final appVersion = await _getAppVersion();
      final record = ConsentRecord(
        consentType: consentType,
        granted: granted,
        timestamp: DateTime.now(),
        appVersion: appVersion,
        osVersion: _getOsVersion(),
        deviceModel: _getDeviceModel(),
        consentTextVersion: _getConsentTextVersion(consentType),
        locale: locale ?? 'tr',
      );

      // Mevcut logu oku
      final raw = await _storage.read(key: SecureStorageKeys.consentLog);
      final List<dynamic> list = raw != null && raw.isNotEmpty
          ? jsonDecode(raw) as List<dynamic>
          : [];
      list.add(record.toJson());

      await _storage.write(
        key: SecureStorageKeys.consentLog,
        value: jsonEncode(list),
      );
    } catch (e) {
      debugPrint('[ConsentManager] _recordConsent hata: $e');
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  String _getOsVersion() {
    try {
      if (kIsWeb) return 'web';
      if (Platform.isAndroid)
        return 'android-${Platform.operatingSystemVersion}';
      if (Platform.isIOS) return 'ios-${Platform.operatingSystemVersion}';
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }

  String _getDeviceModel() {
    try {
      if (kIsWeb) return 'web';
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  String _getConsentTextVersion(String consentType) {
    switch (consentType) {
      case ConsentRecord.typeTerms:
        return LegalTexts.termsVersion;
      case ConsentRecord.typeKvkk:
        return LegalTexts.kvkkVersion;
      default:
        return LegalTexts.kvkkVersion;
    }
  }
}
