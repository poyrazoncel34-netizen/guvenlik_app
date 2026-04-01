import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';
import 'local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Strips formatting characters from [raw] and returns the digit-only (+ optional
/// leading +) string, or an empty string if the result is not a plausible phone
/// number (fewer than 7 or more than 15 digits per ITU-T E.164).
String normalizePhoneNumber(String raw) {
  final stripped = raw.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
  final digits = stripped.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length < 7 || digits.length > 15) return '';
  // Re-attach a leading '+' if it was present in the original stripped string.
  return stripped.startsWith('+') ? '+$digits' : digits;
}

class ContactService {
  static String get _unknownNameFallback => "contacts_fallback_name".tr();
  static final SecureStorage _secureStorage = serviceLocator<SecureStorage>();
  static final LocalDatabaseService _databaseService =
      serviceLocator<LocalDatabaseService>();

  static Future<void> saveContacts(List<String> numbers) async {
    final existing = await getContactRecords();
    final contacts = <EmergencyContact>[];

    for (final number in numbers) {
      final normalizedPhone = normalizePhoneNumber(number);
      if (normalizedPhone.isEmpty ||
          contacts.any((contact) => contact.matchesPhone(number))) {
        continue;
      }

      final existingContact = _findContactByPhone(existing, number);
      contacts.add(
        existingContact ??
            EmergencyContact(
              name: "contacts_person_label".tr(
                namedArgs: {'index': '${contacts.length + 1}'},
              ),
              phone: number.trim(),
            ),
      );
    }

    await saveContactRecords(contacts);
  }

  static Future<void> saveContactRecords(
    List<EmergencyContact> contacts,
  ) async {
    final primary = await _readPrimaryFromDatabase();
    final deduplicated = <EmergencyContact>[];

    for (final contact in contacts) {
      final sanitized = EmergencyContact(
        name: contact.name.trim().isEmpty
            ? _unknownNameFallback
            : contact.name.trim(),
        phone: contact.phone.trim(),
      );
      if (sanitized.normalizedPhone.isEmpty ||
          deduplicated.any((item) => item.matchesPhone(sanitized.phone))) {
        continue;
      }
      deduplicated.add(sanitized);
    }

    final db = await _databaseService.database;
    try {
      await db.transaction((txn) async {
        await txn.delete('contacts');
        for (final contact in deduplicated) {
          await txn.insert('contacts', {
            'name': contact.name,
            'phone': contact.phone,
            'is_primary': primary != null && primary.matchesPhone(contact.phone)
                ? 1
                : 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (_) {
      rethrow;
    }
  }

  static Future<List<String>> getContacts() async {
    final contacts = await getContactRecords();
    return contacts.map((contact) => contact.phone).toList(growable: false);
  }

  static Future<List<EmergencyContact>> getContactRecords() async {
    final db = await _databaseService.database;
    var rows = await db.query(
      'contacts',
      orderBy: 'is_primary DESC, created_at ASC',
    );

    if (rows.isEmpty) {
      await _migrateLegacyContacts();
      rows = await db.query(
        'contacts',
        orderBy: 'is_primary DESC, created_at ASC',
      );
    }

    return rows
        .map(
          (row) => EmergencyContact(
            name: row['name']?.toString() ?? _unknownNameFallback,
            phone: row['phone']?.toString() ?? '',
          ),
        )
        .where((contact) => contact.normalizedPhone.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> saveEmergencyContact(List<String> numbers) async {
    await saveContacts(numbers);
  }

  static Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phone);
    if (normalizedPhone.isEmpty) {
      await clearPrimaryEmergencyContact();
      return;
    }

    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update('contacts', {'is_primary': 0});

      final existing = await txn.query(
        'contacts',
        where: 'phone = ?',
        whereArgs: [phone.trim()],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('contacts', {
          'name': name.trim().isEmpty ? _unknownNameFallback : name.trim(),
          'phone': phone.trim(),
          'is_primary': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await txn.update(
          'contacts',
          {
            'name': name.trim().isEmpty ? _unknownNameFallback : name.trim(),
            'is_primary': 1,
          },
          where: 'phone = ?',
          whereArgs: [phone.trim()],
        );
      }
    });
  }

  static Future<EmergencyContact?> getEmergencyContact() async {
    final db = await _databaseService.database;
    var rows = await db.query(
      'contacts',
      where: 'is_primary = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      await _migrateLegacyContacts();
      rows = await db.query(
        'contacts',
        where: 'is_primary = ?',
        whereArgs: [1],
        limit: 1,
      );
    }

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return EmergencyContact(
      name: row['name']?.toString() ?? _unknownNameFallback,
      phone: row['phone']?.toString() ?? '',
    );
  }

  static Future<void> clearPrimaryEmergencyContact() async {
    final db = await _databaseService.database;
    await db.update('contacts', {'is_primary': 0});
  }

  static Future<List<String>> getAllEmergencyNumbers() async {
    try {
      final contacts = await getContactRecords();
      return contacts.map((contact) => contact.phone).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> getEmergencyNumber() async {
    final emergency = await getEmergencyContact();
    if (emergency != null && emergency.phone.isNotEmpty) {
      return emergency.phone;
    }
    final list = await getAllEmergencyNumbers();
    if (list.isNotEmpty) {
      return list.first;
    }
    return null;
  }

  static Future<void> _migrateLegacyContacts() async {
    final secureValue = await _secureStorage.read(
      key: SecureStorageKeys.contactsData,
    );
    final secureContacts = _decodeContacts(secureValue);
    final legacyContacts = secureContacts.isNotEmpty
        ? secureContacts
        : (await _readLegacyContacts())
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

    if (legacyContacts.isNotEmpty) {
      await saveContactRecords(legacyContacts);
    }

    final primary = await _readStoredPrimaryContact();
    if (primary != null) {
      await savePrimaryEmergencyContact(
        name: primary.name,
        phone: primary.phone,
      );
    }
  }

  static Future<List<String>> _readLegacyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return _deduplicateNumbers(prefs.getStringList('saved_contacts') ?? []);
  }

  static Future<EmergencyContact?> _readStoredPrimaryContact() async {
    final securePhone = await _secureStorage.read(
      key: SecureStorageKeys.emergencyContactPhone,
    );
    if (securePhone != null && securePhone.isNotEmpty) {
      final secureName =
          await _secureStorage.read(
            key: SecureStorageKeys.emergencyContactName,
          ) ??
          _unknownNameFallback;
      return EmergencyContact(name: secureName, phone: securePhone);
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
      final normalizedPhone = normalizePhoneNumber(phone);
      if (normalizedPhone.isEmpty ||
          result.any(
            (existing) => normalizePhoneNumber(existing) == normalizedPhone,
          )) {
        continue;
      }
      result.add(phone);
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

  static Future<EmergencyContact?> _readPrimaryFromDatabase() async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'contacts',
      where: 'is_primary = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return EmergencyContact(
      name: row['name']?.toString() ?? _unknownNameFallback,
      phone: row['phone']?.toString() ?? '',
    );
  }
}

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  String get normalizedPhone => normalizePhoneNumber(phone);

  bool matchesPhone(String otherPhone) {
    return normalizedPhone == normalizePhoneNumber(otherPhone);
  }

  Map<String, dynamic> toJson() {
    return {'name': name.trim(), 'phone': phone.trim()};
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json['name']?.toString().trim().isNotEmpty ?? false)
          ? json['name'].toString().trim()
          : ContactService._unknownNameFallback,
      phone: json['phone']?.toString().trim() ?? '',
    );
  }
}
