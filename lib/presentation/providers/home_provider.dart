import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/contact_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/permission_helper.dart';
import '../../core/services/location_service.dart';
import '../../domain/repositories/contacts_repository.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider();

  static const String onboardingKey = "onboarding_dismissed";

  // late: serviceLocator'a ilk kullanımda erişilir (constructor'da değil)
  late final LocationService _locationService =
      serviceLocator<LocationService>();
  late final ContactsRepository _contactsRepository =
      serviceLocator<ContactsRepository>();
  // Offline-first: No EmergencyRepository (Firebase removed)

  EmergencyContact? _emergencyContact;
  bool _contactsPermissionGranted = false;
  bool _locationPermissionGranted = false;
  bool _onboardingDismissed = false;
  bool _initialized = false;
  String? _pendingMessage;

  EmergencyContact? get emergencyContact => _emergencyContact;
  bool get contactsPermissionGranted => _contactsPermissionGranted;
  bool get locationPermissionGranted => _locationPermissionGranted;
  bool get onboardingDismissed => _onboardingDismissed;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([
      _loadEmergencyContact(),
      _loadPermissionsStatus(),
      _loadOnboardingStatus(),
    ]);
  }

  Future<void> refreshAfterContactsChanged() async {
    await _loadEmergencyContact();
    await _loadPermissionsStatus();
  }

  Future<void> _loadEmergencyContact() async {
    final contact = await _contactsRepository.getPrimaryEmergencyContact();
    _emergencyContact = contact;
    notifyListeners();
  }

  Future<void> _loadPermissionsStatus() async {
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    final permission = await _locationService.checkPermission();
    final locationGranted =
        serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse);
    // Contacts use a user-selected picker path plus manual entry fallback. The
    // app does not request READ_CONTACTS or bulk-read the address book.
    const contactsGranted = !kIsWeb;

    _locationPermissionGranted = locationGranted;
    _contactsPermissionGranted = contactsGranted;
    notifyListeners();
  }

  Future<void> _loadOnboardingStatus() async {
    // SharedPreferences usage kept here to avoid forcing secure storage for non-sensitive state.
    final prefs = await SharedPreferences.getInstance();
    _onboardingDismissed = prefs.getBool(onboardingKey) ?? false;
    notifyListeners();
  }

  Future<void> dismissOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingKey, true);
    _onboardingDismissed = true;
    notifyListeners();
  }

  /// Request location permission. Pass BuildContext for "Ayarlara Git" dialogs.
  Future<String?> requestLocationPermission({BuildContext? context}) async {
    if (context != null && context.mounted) {
      final granted = await PermissionHelper.requestLocationPermission(context);
      await _loadPermissionsStatus();
      return granted ? null : "home_location_permission_denied".tr();
    }
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _locationService.openLocationSettings();
      return null;
    }
    await _locationService.requestPermission();
    await _loadPermissionsStatus();
    return null;
  }

  Future<String?> requestContactsPermission() async {
    // Contact Picker uses Intent.ACTION_PICK — no permission request needed.
    return null;
  }

  String? takeMessage() {
    final message = _pendingMessage;
    _pendingMessage = null;
    return message;
  }

}
