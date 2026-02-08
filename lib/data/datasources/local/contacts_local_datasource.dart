import '../../../core/services/contact_service.dart';

class ContactsLocalDataSource {
  Future<List<String>> getContacts() {
    return ContactService.getContacts();
  }

  Future<void> saveContacts(List<String> numbers) {
    return ContactService.saveContacts(numbers);
  }

  Future<EmergencyContact?> getPrimaryEmergencyContact() {
    return ContactService.getEmergencyContact();
  }

  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) {
    return ContactService.savePrimaryEmergencyContact(name: name, phone: phone);
  }

  Future<List<String>> getAllEmergencyNumbers() {
    return ContactService.getAllEmergencyNumbers();
  }

  Future<void> saveEmergencyNumbers(List<String> numbers) {
    return ContactService.saveEmergencyContact(numbers);
  }
}
