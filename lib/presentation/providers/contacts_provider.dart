import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/service_locator.dart';
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

  // late: serviceLocator'a ilk kullanımda erişilir (constructor'da değil)
  late final ContactsRepository _repository = serviceLocator<ContactsRepository>();
  final List<ContactItem> _emergencyContacts = [];

  String? _selectedEmergencyPhone;
  bool _initialized = false;
  bool _isLoading = false;

  List<ContactItem> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  String? get selectedEmergencyPhone => _selectedEmergencyPhone;
  bool get isLoading => _isLoading;
  bool get hasContacts => _emergencyContacts.isNotEmpty;
  bool get isAtLimit => _emergencyContacts.length >= AppConstants.maxEmergencyContacts;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();

    await _loadContactsFromStorage();
    await _loadEmergencySelection();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadContactsFromStorage() async {
    final saved = await _repository.getContacts();
    _emergencyContacts.clear();
    for (int i = 0; i < saved.length; i++) {
      // Saved as phone numbers; try to get name from emergency contact
      _emergencyContacts.add(
        ContactItem(
          name: 'Kişi ${i + 1}',
          phone: saved[i],
          icon: Icons.person_rounded,
          color: _getColorForIndex(i),
        ),
      );
    }
    // Also check for primary emergency contact for name
    final primary = await _repository.getPrimaryEmergencyContact();
    if (primary != null) {
      final idx = _emergencyContacts.indexWhere((c) => c.phone.trim() == primary.phone.trim());
      if (idx >= 0) {
        _emergencyContacts[idx] = ContactItem(
          name: primary.name,
          phone: primary.phone,
          icon: Icons.favorite_rounded,
          color: AppColors.emergency,
        );
      }
    }
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
    final normalized = phone.replaceAll(RegExp(r'\s+'), '');
    return _emergencyContacts.any(
      (item) => item.phone.replaceAll(RegExp(r'\s+'), '') == normalized,
    );
  }

  Future<bool> addContact({
    required String name,
    required String phone,
  }) async {
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
    final normalized = phone.replaceAll(RegExp(r'\s+'), '');
    final idx = _emergencyContacts.indexWhere(
      (c) => c.phone.replaceAll(RegExp(r'\s+'), '') == normalized,
    );
    if (idx < 0) return false;

    _emergencyContacts.removeAt(idx);
    if (_selectedEmergencyPhone?.replaceAll(RegExp(r'\s+'), '') == normalized) {
      _selectedEmergencyPhone = null;
    }
    await _persistContacts();
    notifyListeners();
    return true;
  }

  Future<void> selectEmergencyContact(ContactItem contact) async {
    await _repository.savePrimaryEmergencyContact(name: contact.name, phone: contact.phone);
    _selectedEmergencyPhone = contact.phone;
    notifyListeners();
  }

  Future<void> _loadEmergencySelection() async {
    final emergency = await _repository.getPrimaryEmergencyContact();
    _selectedEmergencyPhone = emergency?.phone;
    notifyListeners();
  }

  Future<void> _persistContacts() async {
    final numbers = _emergencyContacts.map((contact) => contact.phone).toList();
    await _repository.saveContacts(numbers);
    await _repository.saveEmergencyNumbers(numbers);
  }
}
