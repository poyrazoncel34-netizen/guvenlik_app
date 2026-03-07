import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';

String normalizePhoneNumber(String raw) {
  return raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
}

class ContactService {
  static String get _unknownNameFallback => "contacts_fallback_name".tr();
  static final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  // Kişileri Kaydet
  static Future<void> saveContacts(List<String> numbers) async {
    final existingContacts = await getContactRecords();
    final contacts = <EmergencyContact>[];

    for (int i = 0; i < numbers.length; i++) {
      final phone = numbers[i].trim();
      final normalizedPhone = normalizePhoneNumber(phone);
      if (normalizedPhone.isEmpty ||
          contacts.any((contact) => contact.matchesPhone(phone))) {
        continue;
      }

      final existingContact = _findContactByPhone(existingContacts, phone);
      contacts.add(
        existingContact ??
            EmergencyContact(
              name: "contacts_person_label".tr(
                namedArgs: {'index': '${contacts.length + 1}'},
              ),
              phone: phone,
            ),
      );
    }

    await _persistContactRecords(contacts);
  }

  static Future<void> saveContactRecords(
    List<EmergencyContact> contacts,
  ) async {
    await _persistContactRecords(contacts);
  }

  // Kişileri Getir
  static Future<List<String>> getContacts() async {
    final contacts = await getContactRecords();
    if (contacts.isNotEmpty) {
      return contacts.map((contact) => contact.phone).toList(growable: false);
    }

    return _readLegacyContacts();
  }

  static Future<List<EmergencyContact>> getContactRecords() async {
    final secureValue = await _secureStorage.read(
      key: SecureStorageKeys.contactsData,
    );
    final secureContacts = _decodeContacts(secureValue);
    if (secureContacts.isNotEmpty) {
      return secureContacts;
    }

    final legacyContacts = await _readLegacyContacts();
    if (legacyContacts.isEmpty) {
      return const [];
    }

    final primaryContact = await _readStoredPrimaryContact();
    final migratedContacts = <EmergencyContact>[];
    for (int i = 0; i < legacyContacts.length; i++) {
      final phone = legacyContacts[i];
      migratedContacts.add(
        EmergencyContact(
          name: primaryContact != null && primaryContact.matchesPhone(phone)
              ? primaryContact.name
              : "contacts_person_label".tr(
                  namedArgs: {'index': '${migratedContacts.length + 1}'},
                ),
          phone: phone,
        ),
      );
    }

    await _persistContactRecords(migratedContacts);
    return migratedContacts;
  }

  static Future<List<String>> _readLegacyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = _deduplicateNumbers(
      prefs.getStringList('saved_contacts') ?? [],
    );
    if (legacy.isNotEmpty) {
      await _secureStorage.write(
        key: SecureStorageKeys.contactsList,
        value: jsonEncode(legacy),
      );
      await prefs.remove('saved_contacts');
    }
    return legacy;
  }

  // Acil kişilerin telefon listesini kaydet
  static Future<void> saveEmergencyContact(List<String> numbers) async {
    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactsList,
      value: jsonEncode(_deduplicateNumbers(numbers)),
    );
  }

  // Birincil acil kişiyi kaydet (UI için)
  static Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phone);
    if (normalizedPhone.isEmpty) {
      await clearPrimaryEmergencyContact();
      return;
    }

    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactName,
      value: name.trim().isEmpty ? _unknownNameFallback : name.trim(),
    );
    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactPhone,
      value: normalizedPhone,
    );
  }

  // Acil kişiyi getir
  static Future<EmergencyContact?> getEmergencyContact() async {
    final stored = await _readStoredPrimaryContact();
    if (stored == null) {
      return null;
    }

    final allNumbers = await getAllEmergencyNumbers();
    final stillExists = allNumbers.any(stored.matchesPhone);
    if (!stillExists) {
      await clearPrimaryEmergencyContact();
      return null;
    }

    final matchingContact = _findContactByPhone(
      await getContactRecords(),
      stored.phone,
    );
    if (matchingContact != null && matchingContact.name != stored.name) {
      await savePrimaryEmergencyContact(
        name: matchingContact.name,
        phone: matchingContact.phone,
      );
      return matchingContact;
    }

    return stored;
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
    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactPhone,
      value: normalizePhoneNumber(legacyPhone),
    );
    await _secureStorage.write(
      key: SecureStorageKeys.emergencyContactName,
      value: legacyName,
    );
    await prefs.remove('emergency_contact_phone');
    await prefs.remove('emergency_contact_name');
    return EmergencyContact(name: legacyName, phone: legacyPhone);
  }

  static Future<void> clearPrimaryEmergencyContact() async {
    await _secureStorage.delete(key: SecureStorageKeys.emergencyContactName);
    await _secureStorage.delete(key: SecureStorageKeys.emergencyContactPhone);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('emergency_contact_phone');
    await prefs.remove('emergency_contact_name');
  }

  // Tüm acil telefon numaralarını getir
  static Future<List<String>> getAllEmergencyNumbers() async {
    final secureValue = await _secureStorage.read(
      key: SecureStorageKeys.emergencyContactsList,
    );
    final secureNumbers = _decodeList(secureValue);
    if (secureNumbers.isNotEmpty) {
      return secureNumbers;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacy = _deduplicateNumbers(
      prefs.getStringList('emergency_contacts') ?? [],
    );
    if (legacy.isNotEmpty) {
      await _secureStorage.write(
        key: SecureStorageKeys.emergencyContactsList,
        value: jsonEncode(legacy),
      );
      await prefs.remove('emergency_contacts');
      return legacy;
    }

    return getContacts();
  }

  // İlk Numarayı Getir (Acil Durum İçin)
  static Future<String?> getEmergencyNumber() async {
    final emergency = await getEmergencyContact();
    if (emergency != null && emergency.phone.isNotEmpty) {
      return emergency.phone;
    }
    final list = await getAllEmergencyNumbers();
    if (list.isNotEmpty) return list.first;
    return null;
  }

  static Future<void> _persistContactRecords(
    List<EmergencyContact> contacts,
  ) async {
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

    await _secureStorage.write(
      key: SecureStorageKeys.contactsData,
      value: jsonEncode(
        deduplicated.map((contact) => contact.toJson()).toList(growable: false),
      ),
    );
    await _secureStorage.write(
      key: SecureStorageKeys.contactsList,
      value: jsonEncode(
        deduplicated.map((contact) => contact.phone).toList(growable: false),
      ),
    );

    final primaryContact = await _readStoredPrimaryContact();
    if (primaryContact == null) {
      return;
    }

    final matchingContact = _findContactByPhone(
      deduplicated,
      primaryContact.phone,
    );
    if (matchingContact == null) {
      await clearPrimaryEmergencyContact();
      return;
    }

    if (matchingContact.name != primaryContact.name ||
        normalizePhoneNumber(matchingContact.phone) !=
            normalizePhoneNumber(primaryContact.phone)) {
      await savePrimaryEmergencyContact(
        name: matchingContact.name,
        phone: matchingContact.phone,
      );
    }
  }

  static List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _deduplicateNumbers(decoded.map((entry) => entry.toString()));
      }
    } catch (_) {}
    return const [];
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
