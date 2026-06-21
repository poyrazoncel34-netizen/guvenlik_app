// ============================================================================
// CONSENT MANAGER — KVKK Rıza Yönetim Servisi
// Rıza audit log'u (kullanıcının kendi onay/geri-çekme seçimleri + zaman
// damgaları + app/OS metası) düz, uygulamaya-özel SharedPreferences'ta saklanır.
// Bunlar sır değildir ve keystore bağımlılığı bu veride güvenilmez kalıcılığa
// yol açıyordu. PIN/kişiler/ENCRYPTION_KEY şifreli deposuna DOKUNULMAZ; eski
// kayıt yalnızca tek seferlik, salt-okunur migrasyon için okunur.
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

/// Thrown when a consent record could not be persisted.
class ConsentStorageException implements Exception {
  const ConsentStorageException(this.message);
  final String message;
  @override
  String toString() => 'ConsentStorageException: $message';
}

class ConsentManager {
  /// Plain app-private store key for the consent audit log (NOT the keystore).
  static const String _consentLogKey = 'kvkk_consent_log_v2';

  // ── Mevcut onaylı rıza durumu (bellek önbelleği) ──────────────────────────
  final Map<String, bool> _consentCache = {};
  bool _initialized = false;
  bool _legacyMigrationDone = false;

  /// True when the most recent cache load could not read secure storage at all
  /// (distinct from per-record parse skips). Surfaced by the consent UI so the
  /// user is warned instead of silently seeing every consent as "off".
  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  // ── Singleton başlatma ────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadConsentCache();
    _initialized = true;
  }

  Future<void> _loadConsentCache() async {
    _loadFailed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacyConsentLog(prefs);
      final raw = prefs.getString(_consentLogKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final List<dynamic> list = decoded;
      // Son durumu bul (her tür için en son kaydı al).
      // Tek bir bozuk kayıt, geçerli onayları SİLMEMELİ — KVKK kayıtları
      // kullanıcının açık iradesini yansıtır; yarım yazma veya şema
      // değişikliği sonrası tek bir kayıt bozulduğunda diğerleri korunur.
      final Map<String, ConsentRecord> latest = {};
      var skipped = 0;
      for (final item in list) {
        try {
          final record = ConsentRecord.fromJson(item as Map<String, dynamic>);
          final existing = latest[record.consentType];
          if (existing == null ||
              record.timestamp.isAfter(existing.timestamp)) {
            latest[record.consentType] = record;
          }
        } catch (e) {
          skipped++;
          debugPrint(
            '[ConsentManager] _loadConsentCache: skipping malformed entry: $e',
          );
        }
      }
      if (skipped > 0) {
        debugPrint(
          '[ConsentManager] _loadConsentCache: $skipped malformed entries '
          'skipped, ${latest.length} valid consents loaded',
        );
      }
      for (final entry in latest.entries) {
        _consentCache[entry.key] = entry.value.granted;
      }
    } catch (e) {
      // Storage itself was unreadable (not a per-record parse skip). Flag it so
      // the consent UI can warn the user instead of silently showing every
      // consent as "off".
      _loadFailed = true;
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
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacyConsentLog(prefs);
      final raw = prefs.getString(_consentLogKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final List<dynamic> list = decoded;
      // Tek bir bozuk kayıt tüm KVKK audit log'unu silmesin — geçerli olan
      // kayıtlar export/management ekranlarında görünmeye devam etmeli.
      final records = <ConsentRecord>[];
      var skipped = 0;
      for (final item in list) {
        try {
          records.add(ConsentRecord.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          skipped++;
          debugPrint(
            '[ConsentManager] getAllLogs: skipping malformed entry: $e',
          );
        }
      }
      if (skipped > 0) {
        debugPrint(
          '[ConsentManager] getAllLogs: $skipped malformed entries skipped, '
          '${records.length} valid logs returned',
        );
      }
      return records;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentLogKey);
    _consentCache.clear();
    // SharedPreferences legal flags temizle
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

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyConsentLog(prefs);

    // Read the existing log. Tolerate a corrupt/non-list blob by starting a
    // fresh list so the new consent can still be recorded.
    final raw = prefs.getString(_consentLogKey);
    var list = <dynamic>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      } on FormatException catch (e) {
        debugPrint('[ConsentManager] _recordConsent: corrupt log reset: $e');
      }
    }
    list.add(record.toJson());

    // No silent failure: if the write does not commit, surface it so the user
    // is told the change was NOT saved instead of the toggle appearing to
    // succeed and silently reverting on next launch.
    final ok = await prefs.setString(_consentLogKey, jsonEncode(list));
    if (!ok) {
      throw const ConsentStorageException('consent log write did not commit');
    }
  }

  /// One-time, read-only migration of the consent log from the old
  /// keystore-backed secure store into [_consentLogKey]. The secure store
  /// (shared with PIN/contacts/ENCRYPTION_KEY) is only READ — never written or
  /// deleted. If the legacy read fails (e.g. keystore unavailable) the key is
  /// left absent and migration retries next launch; meanwhile the user simply
  /// has no prior consent and re-consents.
  Future<void> _migrateLegacyConsentLog(SharedPreferences prefs) async {
    if (_legacyMigrationDone || prefs.containsKey(_consentLogKey)) {
      _legacyMigrationDone = true;
      return;
    }
    try {
      const legacy = FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      final old = await legacy.read(key: SecureStorageKeys.consentLog);
      // Read succeeded — seal the migration (even when empty) so it is one-time.
      await prefs.setString(
        _consentLogKey,
        old != null && old.isNotEmpty ? old : '[]',
      );
      _legacyMigrationDone = true;
    } on Exception catch (e) {
      debugPrint('[ConsentManager] legacy consent migration deferred: $e');
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
      if (Platform.isAndroid) {
        return 'android-${Platform.operatingSystemVersion}';
      }
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
