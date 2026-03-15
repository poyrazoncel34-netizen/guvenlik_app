import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/contact_service.dart';
import '../../domain/repositories/contacts_repository.dart';

class ContactItem {
  final String name;
  final String phone;
  final IconData icon;
  final Color color;

  const ContactItem({
    required this.name,
    required this.phone,
    required this.icon,
    required this.color,
  });
}

class ContactsProvider extends ChangeNotifier {
  ContactsProvider();

  late final ContactsRepository _repository =
      serviceLocator<ContactsRepository>();
  final List<ContactItem> _emergencyContacts = [];

  String? _selectedEmergencyPhone;
  bool _initialized = false;
  bool _isLoading = false;

  List<ContactItem> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);
  String? get selectedEmergencyPhone => _selectedEmergencyPhone;
  bool get isLoading => _isLoading;
  bool get hasContacts => _emergencyContacts.isNotEmpty;
  bool get isAtLimit =>
      _emergencyContacts.length >= AppConstants.maxEmergencyContacts;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();

    try {
      await _loadContactsFromStorage();
      await _loadEmergencySelection();
    } catch (e) {
      debugPrint('ContactsProvider: initialize failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadContactsFromStorage() async {
    final saved = await _repository.getContactRecords();
    _emergencyContacts
      ..clear()
      ..addAll(
        List.generate(
          saved.length,
          (index) => ContactItem(
            name: saved[index].name,
            phone: saved[index].phone,
            icon: Icons.person_rounded,
            color: _getColorForIndex(index),
          ),
        ),
      );
  }

  Color _getColorForIndex(int index) {
    const colors = [
      AppColors.emergency,
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
    ];
    return colors[index % colors.length];
  }

  bool containsPhone(String phone) {
    final normalized = normalizePhoneNumber(phone);
    return _emergencyContacts.any(
      (item) => normalizePhoneNumber(item.phone) == normalized,
    );
  }

  Future<bool> addContact({required String name, required String phone}) async {
    if (name.trim().isEmpty || phone.trim().isEmpty) return false;
    if (containsPhone(phone)) return false;
    if (isAtLimit) return false;

    _emergencyContacts.add(
      ContactItem(
        name: name.trim(),
        phone: phone.trim(),
        icon: Icons.person_rounded,
        color: _getColorForIndex(_emergencyContacts.length),
      ),
    );
    await _persistContacts();
    notifyListeners();
    return true;
  }

  Future<bool> removeContact(String phone) async {
    final normalized = normalizePhoneNumber(phone);
    final index = _findIndexByPhone(normalized);
    if (index < 0) return false;

    _emergencyContacts.removeAt(index);
    if (normalizePhoneNumber(_selectedEmergencyPhone ?? '') == normalized) {
      _selectedEmergencyPhone = null;
      await _repository.clearPrimaryEmergencyContact();
    }

    await _persistContacts();
    notifyListeners();
    return true;
  }

  Future<void> selectEmergencyContact(ContactItem contact) async {
    await _repository.savePrimaryEmergencyContact(
      name: contact.name,
      phone: contact.phone,
    );
    _selectedEmergencyPhone = contact.phone;
    notifyListeners();
  }

  Future<void> _loadEmergencySelection() async {
    final emergency = await _repository.getPrimaryEmergencyContact();
    if (emergency == null) {
      _selectedEmergencyPhone = null;
      notifyListeners();
      return;
    }

    final index = _findIndexByPhone(emergency.phone);
    _selectedEmergencyPhone = index >= 0
        ? _emergencyContacts[index].phone
        : null;
    notifyListeners();
  }

  Future<void> _persistContacts() async {
    final contacts = _emergencyContacts
        .map(
          (contact) =>
              EmergencyContact(name: contact.name, phone: contact.phone),
        )
        .toList(growable: false);
    final numbers = contacts
        .map((contact) => contact.phone)
        .toList(growable: false);

    await _repository.saveContactRecords(contacts);
    await _repository.saveEmergencyNumbers(numbers);
  }

  /// Reorder contacts by moving item from oldIndex to newIndex.
  Future<void> reorderContact(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _emergencyContacts.removeAt(oldIndex);
    _emergencyContacts.insert(newIndex, item);
    await _persistContacts();
    notifyListeners();
  }

  int _findIndexByPhone(String phone) {
    final normalized = normalizePhoneNumber(phone);
    return _emergencyContacts.indexWhere(
      (contact) => normalizePhoneNumber(contact.phone) == normalized,
    );
  }
}
