import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import '../utils/emergency_number_validator.dart';
import 'local_database_service.dart';

String normalizePhoneNumber(String raw) {
  final normalized = raw.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (normalized.startsWith('+')) {
    return '+${normalized.substring(1).replaceAll('+', '')}';
  }
  return normalized.replaceAll('+', '');
}

/// Single source of truth for emergency contacts: the Android Keystore-backed
/// [SecureStorage] (KRİTİK-1 / H1). A process-lifetime, write-through memory
/// cache is warmed at startup so the emergency path never blocks on, or fails
/// because of, a slow/locked Keystore. The plaintext sqflite `contacts` table
/// is migrated once (kill-safe) and then left empty — never the source again.
class ContactService {
  static String get _unknownNameFallback => "contacts_fallback_name".tr();

  // Resolved per call (not cached in a static final) so tests that reset the
  // service locator pick up fresh fakes.
  static SecureStorage get _secureStorage => serviceLocator<SecureStorage>();
  static LocalDatabaseService get _databaseService =>
      serviceLocator<LocalDatabaseService>();

  /// Warm, write-through cache. `null` means "not loaded yet".
  static List<EmergencyContact>? _cache;

  /// Single-flight guard so concurrent warm-up + reads don't double-migrate.
  static Future<List<EmergencyContact>>? _inflight;

  // ---------------------------------------------------------------------------
  // Warm-up / cache lifecycle
  // ---------------------------------------------------------------------------

  /// Load the canonical store into the warm cache at startup. Best-effort: a
  /// failure here never blocks boot — lazy reads self-heal.
  static Future<void> warmUp() async {
    try {
      await getContactRecords();
    } catch (_) {
      // Never block boot on a warm-up failure.
    }
  }

  /// Drop the in-memory cache. Used by KVKK "delete my data" (AppResetService)
  /// and by tests.
  static void resetCache() {
    _cache = null;
    _inflight = null;
  }

  // ---------------------------------------------------------------------------
  // Reads (cache-first, secure-storage-backed, DB/legacy fail-safe)
  // ---------------------------------------------------------------------------

  static Future<List<EmergencyContact>> getContactRecords() {
    final cached = _cache;
    if (cached != null) {
      return Future.value(cached);
    }
    return _ensureCanonical();
  }

  static Future<List<String>> getContacts() async {
    final contacts = await getContactRecords();
    return contacts.map((contact) => contact.phone).toList(growable: false);
  }

  static Future<List<String>> getAllEmergencyNumbers() async {
    final contacts = await getContactRecords();
    return contacts.map((contact) => contact.phone).toList(growable: false);
  }

  static Future<EmergencyContact?> getEmergencyContact() async {
    final contacts = await getContactRecords();
    return _primaryOf(contacts);
  }

  static Future<String?> getEmergencyNumber() async {
    final emergency = await getEmergencyContact();
    if (emergency != null && emergency.phone.isNotEmpty) {
      return emergency.phone;
    }
    // List order is not consent to call. Safety flows require an explicitly
    // selected primary contact and fail closed when it is absent.
    return null;
  }

  // ---------------------------------------------------------------------------
  // Writes (write-through: secure storage + cache updated atomically)
  // ---------------------------------------------------------------------------

  static Future<void> saveContacts(List<String> numbers) async {
    final existing = await getContactRecords();
    final contacts = <EmergencyContact>[];

    for (final number in numbers) {
      final normalizedPhone =
          EmergencyNumberValidator.normalizedCallableTargetOrNull(number);
      if (normalizedPhone == null ||
          contacts.any((contact) => contact.matchesPhone(normalizedPhone))) {
        continue;
      }

      final existingContact = _findContactByPhone(existing, normalizedPhone);
      contacts.add(
        existingContact ??
            EmergencyContact(
              name: "contacts_person_label".tr(
                namedArgs: {'index': '${contacts.length + 1}'},
              ),
              phone: normalizedPhone,
            ),
      );
    }

    await saveContactRecords(contacts);
  }

  static Future<void> saveContactRecords(
    List<EmergencyContact> contacts,
  ) async {
    final current = await getContactRecords();
    final currentPrimary = _primaryOf(current);
    final deduplicated = <EmergencyContact>[];

    for (final contact in contacts) {
      final name = contact.name.trim().isEmpty
          ? _unknownNameFallback
          : contact.name.trim();
      final phone = EmergencyNumberValidator.normalizedCallableTargetOrNull(
        contact.phone,
      );
      if (phone == null) continue;
      final candidate = EmergencyContact(
        name: name,
        phone: phone,
        isPrimary: currentPrimary != null && currentPrimary.matchesPhone(phone),
      );
      if (deduplicated.any((item) => item.matchesPhone(candidate.phone))) {
        continue;
      }
      deduplicated.add(candidate);
      if (deduplicated.length == AppConstants.maxEmergencyContacts) {
        break;
      }
    }

    await _persist(deduplicated);
  }

  static Future<void> saveEmergencyContact(List<String> numbers) async {
    await saveContacts(numbers);
  }

  static Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    final normalizedPhone =
        EmergencyNumberValidator.normalizedCallableTargetOrNull(phone);
    if (normalizedPhone == null) {
      if (phone.trim().isEmpty) {
        await clearPrimaryEmergencyContact();
      }
      return;
    }

    final current = await getContactRecords();
    final trimmedName = name.trim().isEmpty
        ? _unknownNameFallback
        : name.trim();
    final trimmedPhone = normalizedPhone;

    final updated = <EmergencyContact>[];
    var found = false;
    for (final contact in current) {
      if (contact.matchesPhone(trimmedPhone)) {
        found = true;
        updated.add(
          EmergencyContact(
            name: trimmedName,
            phone: contact.phone,
            isPrimary: true,
          ),
        );
      } else {
        updated.add(contact.copyWith(isPrimary: false));
      }
    }
    if (!found) {
      updated.add(
        EmergencyContact(
          name: trimmedName,
          phone: trimmedPhone,
          isPrimary: true,
        ),
      );
    }

    await _persist(updated);
  }

  static Future<void> clearPrimaryEmergencyContact() async {
    final current = await getContactRecords();
    final updated = current
        .map((contact) => contact.copyWith(isPrimary: false))
        .toList(growable: false);
    await _persist(updated);
  }

  // ---------------------------------------------------------------------------
  // Canonical store internals
  // ---------------------------------------------------------------------------

  static Future<List<EmergencyContact>> _ensureCanonical() {
    return _inflight ??= _loadCanonical().whenComplete(() => _inflight = null);
  }

  static Future<List<EmergencyContact>> _loadCanonical() async {
    // Establish canonical (idempotent: import from DB/legacy, verify, clear).
    try {
      await _migrateToCanonicalIfNeeded();
    } on Exception {
      // Best-effort; never block the read path.
    }

    String? raw;
    try {
      raw = await _secureStorage.read(
        key: SecureStorageKeys.emergencyContactsV1,
      );
    } on Exception {
      return _failsafeFallback();
    }

    if (raw == null || raw.isEmpty) {
      // Canonical not established. If the DB still holds rows (migration not
      // yet confirmed), serve them so a contact is never unreadable.
      final dbRows = await _readDbContactsSafe();
      _cache = dbRows;
      return dbRows;
    }

    final decoded = _decodeEnvelope(raw);
    if (decoded == null) {
      // Corrupt canonical value — never auto-delete it (AR-2).
      return _failsafeFallback();
    }
    _cache = decoded;
    return decoded;
  }

  /// AR-2: on a secure-storage read failure, never throw and never delete.
  /// Serve last-good cache, then a read-only DB copy (not cached, so a later
  /// post-unlock read can retry), then an empty list.
  static Future<List<EmergencyContact>> _failsafeFallback() async {
    final lastGood = _cache;
    if (lastGood != null) {
      return lastGood;
    }
    return _readDbContactsSafe();
  }

  /// Kill-safe, idempotent, verify-before-delete migration into the canonical
  /// secure store. Invariant: while the `contacts` table holds rows, migration
  /// is not confirmed complete, so this runs again to finish it.
  static Future<void> _migrateToCanonicalIfNeeded() async {
    final migrated = await _isMigrated();

    String? canonical;
    try {
      canonical = await _secureStorage.read(
        key: SecureStorageKeys.emergencyContactsV1,
      );
    } on Exception {
      return; // Cannot read; never migrate/delete blindly.
    }
    final canonicalDecoded = (canonical != null && canonical.isNotEmpty)
        ? _decodeEnvelope(canonical)
        : null;
    final canonicalValid = canonicalDecoded != null;

    final dbRows = await _readDbContactsSafe();

    // Already finalized: canonical authoritative AND no stale DB rows.
    if (migrated && dbRows.isEmpty) {
      return;
    }

    // Canonical valid but DB rows linger (crash before clear): reconcile.
    if (canonicalValid && dbRows.isNotEmpty) {
      await _clearDbContacts();
      await _clearLegacyContactStorage();
      await _setMigrated(true);
      return;
    }

    // (Re)build canonical from a source. Priority: DB rows, else legacy.
    final source = dbRows.isNotEmpty ? dbRows : await _readLegacySources();

    if (source.isEmpty) {
      // Nothing anywhere; mark migrated so we don't rescan legacy each boot.
      await _setMigrated(true);
      return;
    }

    // WRITE
    try {
      await _writeCanonicalRaw(source);
    } on Exception {
      return; // Write failed; sources intact — no loss.
    }

    // VERIFY (read-back)
    String? readBack;
    try {
      readBack = await _secureStorage.read(
        key: SecureStorageKeys.emergencyContactsV1,
      );
    } on Exception {
      await _safeDelete(SecureStorageKeys.emergencyContactsV1);
      return; // Roll back; keep sources.
    }
    if (!_verifyMatches(readBack, source)) {
      await _safeDelete(SecureStorageKeys.emergencyContactsV1);
      return; // Roll back; keep sources.
    }

    // CLEAR sources only after a verified write.
    await _clearDbContacts();
    await _clearLegacyContactStorage();
    await _setMigrated(true);
  }

  static Future<void> _persist(List<EmergencyContact> contacts) async {
    final ordered = _orderedPrimaryFirst(_normalizeList(contacts));
    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactsV1,
      value: _encodeEnvelope(ordered),
    );
    await _setMigrated(true);
    _cache = ordered;
  }

  static Future<void> _writeCanonicalRaw(
    List<EmergencyContact> contacts,
  ) async {
    final ordered = _orderedPrimaryFirst(_normalizeList(contacts));
    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactsV1,
      value: _encodeEnvelope(ordered),
    );
  }

  static String _encodeEnvelope(List<EmergencyContact> contacts) {
    return jsonEncode({
      'version': 1,
      'contacts': contacts.map((c) => c.toSecureJson()).toList(),
    });
  }

  static List<EmergencyContact>? _decodeEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final contactsRaw = decoded['contacts'];
      if (contactsRaw is! List) {
        return null;
      }
      final contacts = <EmergencyContact>[];
      for (final entry in contactsRaw) {
        if (entry is! Map) {
          continue;
        }
        final contact = EmergencyContact.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (contact.normalizedPhone.isEmpty ||
            contacts.any((item) => item.matchesPhone(contact.phone))) {
          continue;
        }
        contacts.add(contact);
      }
      return contacts;
    } catch (_) {
      return null; // Corrupt — signalled distinctly from a valid empty list.
    }
  }

  static bool _verifyMatches(String? readBack, List<EmergencyContact> source) {
    if (readBack == null || readBack.isEmpty) {
      return false;
    }
    final decoded = _decodeEnvelope(readBack);
    if (decoded == null) {
      return false;
    }
    final expected = _orderedPrimaryFirst(_normalizeList(source));
    if (decoded.length != expected.length) {
      return false;
    }
    final expectedPhones = expected.map((c) => c.normalizedPhone).toSet();
    final decodedPhones = decoded.map((c) => c.normalizedPhone).toSet();
    if (!setEquals(expectedPhones, decodedPhones)) {
      return false;
    }
    final expectedPrimary = expected
        .where((c) => c.isPrimary)
        .map((c) => c.normalizedPhone)
        .toSet();
    final decodedPrimary = decoded
        .where((c) => c.isPrimary)
        .map((c) => c.normalizedPhone)
        .toSet();
    return setEquals(expectedPrimary, decodedPrimary);
  }

  static List<EmergencyContact> _normalizeList(
    List<EmergencyContact> contacts,
  ) {
    final out = <EmergencyContact>[];
    for (final contact in contacts) {
      final normalizedPhone = contact.normalizedPhone;
      if (normalizedPhone.isEmpty) {
        continue;
      }
      if (out.any((item) => item.matchesPhone(normalizedPhone))) {
        continue;
      }
      out.add(contact.copyWith(phone: normalizedPhone));
    }
    return out;
  }

  static List<EmergencyContact> _orderedPrimaryFirst(
    List<EmergencyContact> contacts,
  ) {
    final primary = contacts.where((c) => c.isPrimary).toList(growable: false);
    final rest = contacts.where((c) => !c.isPrimary).toList(growable: false);
    return [...primary, ...rest];
  }

  static EmergencyContact? _primaryOf(List<EmergencyContact> contacts) {
    for (final contact in contacts) {
      if (contact.isPrimary) {
        return contact;
      }
    }
    return null;
  }

  static Future<void> _safeDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on Exception {
      // Best-effort.
    }
  }

  // ---------------------------------------------------------------------------
  // DB (read-only fallback + post-migration clear)
  // ---------------------------------------------------------------------------

  static Future<List<EmergencyContact>> _readDbContactsSafe() async {
    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        'contacts',
        orderBy: 'is_primary DESC, created_at ASC',
      );
      return rows
          .map(
            (row) => EmergencyContact(
              name: row['name']?.toString() ?? _unknownNameFallback,
              phone: row['phone']?.toString() ?? '',
              isPrimary: ((row['is_primary'] as int?) ?? 0) == 1,
            ),
          )
          .where((contact) => contact.normalizedPhone.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _clearDbContacts() async {
    try {
      final db = await _databaseService.database;
      await db.delete('contacts');
    } catch (_) {
      // Best-effort; the invariant retries while rows remain.
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy sources (old secure JSON / SharedPreferences) — one-time import
  // ---------------------------------------------------------------------------

  static Future<List<EmergencyContact>> _readLegacySources() async {
    String? secureValue;
    try {
      secureValue = await _secureStorage.read(
        key: SecureStorageKeys.contactsData,
      );
    } on Exception {
      secureValue = null;
    }
    final secureContacts = _decodeContacts(secureValue);

    final base = secureContacts.isNotEmpty
        ? secureContacts
        : (await _readLegacyNumbers())
              .asMap()
              .entries
              .map(
                (entry) => EmergencyContact(
                  name: "contacts_person_label".tr(
                    namedArgs: {'index': '${entry.key + 1}'},
                  ),
                  phone: entry.value,
                ),
              )
              .toList(growable: false);

    final primary = await _readStoredPrimaryContact();

    final merged = <EmergencyContact>[];
    var primaryIncluded = false;
    for (final contact in base) {
      final isPrimary = primary != null && primary.matchesPhone(contact.phone);
      if (isPrimary) {
        primaryIncluded = true;
      }
      merged.add(
        EmergencyContact(
          name: contact.name,
          phone: contact.phone,
          isPrimary: isPrimary,
        ),
      );
    }
    if (primary != null && !primaryIncluded) {
      merged.add(
        EmergencyContact(
          name: primary.name,
          phone: primary.phone,
          isPrimary: true,
        ),
      );
    }

    return _normalizeList(
      merged,
    ).take(AppConstants.maxEmergencyContacts).toList(growable: false);
  }

  static Future<List<String>> _readLegacyNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    return _deduplicateNumbers(prefs.getStringList('saved_contacts') ?? []);
  }

  static Future<EmergencyContact?> _readStoredPrimaryContact() async {
    String? securePhone;
    try {
      securePhone = await _secureStorage.read(
        key: SecureStorageKeys.emergencyContactPhone,
      );
    } on Exception {
      securePhone = null;
    }
    if (securePhone != null && securePhone.isNotEmpty) {
      String? secureName;
      try {
        secureName = await _secureStorage.read(
          key: SecureStorageKeys.emergencyContactName,
        );
      } on Exception {
        secureName = null;
      }
      return EmergencyContact(
        name: secureName ?? _unknownNameFallback,
        phone: securePhone,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyPhone = prefs.getString('emergency_contact_phone');
    if (legacyPhone == null || legacyPhone.isEmpty) {
      return null;
    }
    final legacyName =
        prefs.getString('emergency_contact_name') ?? _unknownNameFallback;
    return EmergencyContact(name: legacyName, phone: legacyPhone);
  }

  static Future<void> _clearLegacyContactStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_contacts');
    await prefs.remove('emergency_contact_phone');
    await prefs.remove('emergency_contact_name');
    await _safeDelete(SecureStorageKeys.contactsData);
    await _safeDelete(SecureStorageKeys.emergencyContactPhone);
    await _safeDelete(SecureStorageKeys.emergencyContactName);
  }

  static List<EmergencyContact> _decodeContacts(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final contacts = <EmergencyContact>[];
      for (final entry in decoded) {
        if (entry is! Map) {
          continue;
        }
        final contact = EmergencyContact.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (contact.normalizedPhone.isEmpty ||
            contacts.any((item) => item.matchesPhone(contact.phone))) {
          continue;
        }
        contacts.add(contact);
      }
      return contacts;
    } catch (_) {
      return const [];
    }
  }

  static List<String> _deduplicateNumbers(Iterable<String> numbers) {
    final result = <String>[];
    for (final entry in numbers) {
      final phone = entry.trim();
      final normalizedPhone =
          EmergencyNumberValidator.normalizedCallableTargetOrNull(phone);
      if (normalizedPhone == null ||
          result.any(
            (existing) =>
                EmergencyNumberValidator.normalizedCallableTargetOrNull(
                  existing,
                ) ==
                normalizedPhone,
          )) {
        continue;
      }
      result.add(normalizedPhone);
    }
    return result;
  }

  static EmergencyContact? _findContactByPhone(
    Iterable<EmergencyContact> contacts,
    String phone,
  ) {
    for (final contact in contacts) {
      if (contact.matchesPhone(phone)) {
        return contact;
      }
    }
    return null;
  }

  static Future<bool> _isMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefContactsSecureMigratedV1) ?? false;
  }

  static Future<void> _setMigrated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefContactsSecureMigratedV1, value);
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final bool isPrimary;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.isPrimary = false,
  });

  String get normalizedPhone =>
      EmergencyNumberValidator.normalizedCallableTargetOrNull(phone) ?? '';

  bool matchesPhone(String otherPhone) {
    final otherNormalized =
        EmergencyNumberValidator.normalizedCallableTargetOrNull(otherPhone);
    return normalizedPhone.isNotEmpty && normalizedPhone == otherNormalized;
  }

  EmergencyContact copyWith({String? name, String? phone, bool? isPrimary}) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  /// KVKK export form — kept byte-stable (name + phone only).
  Map<String, dynamic> toJson() {
    return {'name': name.trim(), 'phone': phone.trim()};
  }

  /// Canonical secure-store form — includes the primary flag.
  Map<String, dynamic> toSecureJson() {
    return {'name': name.trim(), 'phone': phone.trim(), 'isPrimary': isPrimary};
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json['name']?.toString().trim().isNotEmpty ?? false)
          ? json['name'].toString().trim()
          : ContactService._unknownNameFallback,
      phone: json['phone']?.toString().trim() ?? '',
      isPrimary: json['isPrimary'] == true,
    );
  }
}
