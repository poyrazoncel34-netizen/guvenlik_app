import '../../core/services/contact_service.dart';

abstract class ContactsRepository {
  Future<List<String>> getContacts();
  Future<void> saveContacts(List<String> numbers);
  Future<EmergencyContact?> getPrimaryEmergencyContact();
  Future<void> savePrimaryEmergencyContact({required String name, required String phone});
  Future<List<String>> getAllEmergencyNumbers();
  Future<void> saveEmergencyNumbers(List<String> numbers);
}
