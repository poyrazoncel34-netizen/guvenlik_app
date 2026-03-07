import '../../core/services/contact_service.dart';

abstract class ContactsRepository {
  Future<List<String>> getContacts();
  Future<List<EmergencyContact>> getContactRecords();
  Future<void> saveContacts(List<String> numbers);
  Future<void> saveContactRecords(List<EmergencyContact> contacts);
  Future<EmergencyContact?> getPrimaryEmergencyContact();
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  });
  Future<void> clearPrimaryEmergencyContact();
  Future<List<String>> getAllEmergencyNumbers();
  Future<void> saveEmergencyNumbers(List<String> numbers);
}
