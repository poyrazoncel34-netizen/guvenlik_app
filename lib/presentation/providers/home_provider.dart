import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluttercontactpicker_plus/fluttercontactpicker_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/activity_service.dart';
import '../../core/services/contact_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/permission_helper.dart';
import '../../core/services/location_service.dart';
import '../../domain/models/activity_event.dart' as app_activity;
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
  bool _isLocationSharing = false;
  DateTime? _locationShareEndAt;
  Timer? _locationShareTimer;
  bool _initialized = false;
  String? _pendingMessage;

  EmergencyContact? get emergencyContact => _emergencyContact;
  bool get contactsPermissionGranted => _contactsPermissionGranted;
  bool get locationPermissionGranted => _locationPermissionGranted;
  bool get onboardingDismissed => _onboardingDismissed;
  bool get isLocationSharing => _isLocationSharing;
  DateTime? get locationShareEndAt => _locationShareEndAt;

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
    final contactsGranted = kIsWeb
        ? false
        : await FlutterContactPicker.hasPermission();

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
    if (kIsWeb) {
      return "home_contacts_web_unsupported".tr();
    }
    await FlutterContactPicker.requestPermission();
    await _loadPermissionsStatus();
    return null;
  }

  Future<String?> startLocationSharing(int minutes) async {
    _locationShareEndAt = DateTime.now().add(Duration(minutes: minutes));
    _isLocationSharing = true;
    _locationShareTimer?.cancel();
    _locationShareTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_locationShareEndAt == null) return;
      final remaining = _locationShareEndAt!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds == 0) {
        stopLocationSharing(manual: false);
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
    ActivityService.logEvent(
      type: app_activity.ActivityType.locationShared,
      title: "home_location_shared_title".tr(),
      description: "home_location_shared_desc".tr(namedArgs: {'minutes': '$minutes'}),
    );
    return await _sendLocationShareSms();
  }

  void stopLocationSharing({bool manual = false}) {
    _locationShareTimer?.cancel();
    _locationShareEndAt = null;
    _isLocationSharing = false;
    if (!manual) {
      _pendingMessage = "home_location_sharing_ended".tr();
    }
    notifyListeners();
  }

  String? takeMessage() {
    final message = _pendingMessage;
    _pendingMessage = null;
    return message;
  }

  Future<String?> sendQuickMessage(String message) async {
    final numbers = await _contactsRepository.getAllEmergencyNumbers();
    if (numbers.isEmpty) {
      return 'emergency_contact_not_found'.tr();
    }
    return SmsService.sendSms(numbers: numbers, message: message);
  }

  Future<String?> _sendLocationShareSms() async {
    final numbers = await _contactsRepository.getAllEmergencyNumbers();
    if (numbers.isEmpty) {
      return 'emergency_contact_not_found'.tr();
    }

    final result = await _locationService.getCurrentLocation();
    if (!result.isSuccess || result.position == null) {
      return 'location_unavailable'.tr();
    }

    final lat = result.position!.latitude;
    final lng = result.position!.longitude;
    // Offline-first: No cloud sync, location used locally only
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final message = 'location_share_message'.tr(namedArgs: {'url': url});
    return SmsService.sendSms(numbers: numbers, message: message);
  }



  @override
  void dispose() {
    _locationShareTimer?.cancel();
    super.dispose();
  }
}
