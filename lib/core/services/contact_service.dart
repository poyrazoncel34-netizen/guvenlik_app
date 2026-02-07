import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import '../security/secure_storage.dart';
import '../security/secure_storage_keys.dart';

class ContactService {
  static const String _unknownNameFallback = 'Acil Kişi';
  static final SecureStorage _secureStorage = serviceLocator<SecureStorage>();

  // Kişileri Kaydet
  static Future<void> saveContacts(List<String> numbers) async {
    final payload = jsonEncode(numbers);
    await _secureStorage.write(key: SecureStorageKeys.contactsList, value: payload);
  }

  // Kişileri Getir
  static Future<List<String>> getContacts() async {
    final secureValue = await _secureStorage.read(key: SecureStorageKeys.contactsList);
    if (secureValue != null && secureValue.isNotEmpty) {
      return _decodeList(secureValue);
    }
    // Legacy fallback
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList('saved_contacts') ?? [];
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
      value: jsonEncode(numbers),
    );
  }

  // Birincil acil kişiyi kaydet (UI için)
  static Future<void> savePrimaryEmergencyContact({required String name, required String phone}) async {
    await _secureStorage.write(key: SecureStorageKeys.emergencyContactName, value: name);
    await _secureStorage.write(key: SecureStorageKeys.emergencyContactPhone, value: phone);
  }

  // Acil kişiyi getir
  static Future<EmergencyContact?> getEmergencyContact() async {
    final phone = await _secureStorage.read(key: SecureStorageKeys.emergencyContactPhone);
    if (phone != null && phone.isNotEmpty) {
      final name =
          await _secureStorage.read(key: SecureStorageKeys.emergencyContactName) ?? _unknownNameFallback;
      return EmergencyContact(name: name, phone: phone);
    }
    // Legacy fallback
    final prefs = await SharedPreferences.getInstance();
    final legacyPhone = prefs.getString('emergency_contact_phone');
    if (legacyPhone == null || legacyPhone.isEmpty) {
      return null;
    }
    final legacyName = prefs.getString('emergency_contact_name') ?? _unknownNameFallback;
    await _secureStorage.write(key: SecureStorageKeys.emergencyContactPhone, value: legacyPhone);
    await _secureStorage.write(key: SecureStorageKeys.emergencyContactName, value: legacyName);
    await prefs.remove('emergency_contact_phone');
    await prefs.remove('emergency_contact_name');
    return EmergencyContact(name: legacyName, phone: legacyPhone);
  }

  // Tüm acil telefon numaralarını getir
  static Future<List<String>> getAllEmergencyNumbers() async {
    final secureValue = await _secureStorage.read(key: SecureStorageKeys.emergencyContactsList);
    if (secureValue != null && secureValue.isNotEmpty) {
      final list = _decodeList(secureValue);
      if (list.isNotEmpty) return list;
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList('emergency_contacts') ?? [];
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

  static List<String> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});
}
