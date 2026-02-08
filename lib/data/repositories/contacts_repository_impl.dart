import '../../domain/repositories/contacts_repository.dart';
import '../datasources/local/contacts_local_datasource.dart';
import '../../core/services/contact_service.dart';

class ContactsRepositoryImpl implements ContactsRepository {
  final ContactsLocalDataSource _local;

  ContactsRepositoryImpl(this._local);

  @override
  Future<List<String>> getContacts() {
    return _local.getContacts();
  }

  @override
  Future<void> saveContacts(List<String> numbers) {
    return _local.saveContacts(numbers);
  }

  @override
  Future<EmergencyContact?> getPrimaryEmergencyContact() {
    return _local.getPrimaryEmergencyContact();
  }

  @override
  Future<void> savePrimaryEmergencyContact({
    required String name,
    required String phone,
  }) {
    return _local.savePrimaryEmergencyContact(name: name, phone: phone);
  }

  @override
  Future<List<String>> getAllEmergencyNumbers() {
    return _local.getAllEmergencyNumbers();
  }

  @override
  Future<void> saveEmergencyNumbers(List<String> numbers) {
    return _local.saveEmergencyNumbers(numbers);
  }
}
