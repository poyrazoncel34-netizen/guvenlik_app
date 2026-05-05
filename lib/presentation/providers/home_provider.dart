import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/activity_service.dart';
import '../../core/services/contact_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/foreground_service.dart';
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
  DateTime? _locationShareLastUpdatedAt;
  LatLng? _locationShareCurrentPosition;
  Timer? _locationShareTimer;
  bool _initialized = false;
  String? _pendingMessage;

  EmergencyContact? get emergencyContact => _emergencyContact;
  bool get contactsPermissionGranted => _contactsPermissionGranted;
  bool get locationPermissionGranted => _locationPermissionGranted;
  bool get onboardingDismissed => _onboardingDismissed;
  bool get isLocationSharing => _isLocationSharing;
  DateTime? get locationShareEndAt => _locationShareEndAt;
  DateTime? get locationShareLastUpdatedAt => _locationShareLastUpdatedAt;
  LatLng? get locationShareCurrentPosition => _locationShareCurrentPosition;

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
    // Contact Picker uses Intent.ACTION_PICK — no READ_CONTACTS permission needed.
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

  Future<bool> startLocationSharing(int minutes) async {
    final result = await _locationService.getCurrentLocation();
    if (!result.isSuccess || result.position == null) return false;

    _locationShareEndAt = DateTime.now().add(Duration(minutes: minutes));
    _isLocationSharing = true;
    _locationShareCurrentPosition = result.position;
    _locationShareLastUpdatedAt = DateTime.now();
    _locationShareTimer?.cancel();
    _locationShareTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      try {
        if (_locationShareEndAt == null) return;
        final remaining = _locationShareEndAt!.difference(DateTime.now());
        if (remaining.isNegative || remaining.inSeconds == 0) {
          stopLocationSharing(manual: false);
        } else {
          await _refreshLocationShareState(remaining);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('HomeProvider: Location share timer error: $e');
      }
    });
    await KoruBeniForegroundService.start();
    KoruBeniForegroundService.updateNotification(
      'foreground_location_share_title'.tr(),
      _buildLocationShareNotificationBody(Duration(minutes: minutes)),
    );
    notifyListeners();
    ActivityService.logEvent(
      type: app_activity.ActivityType.locationShared,
      title: "home_location_shared_title".tr(),
      description: "home_location_shared_desc".tr(
        namedArgs: {'minutes': '$minutes'},
      ),
    );
    return true;
  }

  void stopLocationSharing({bool manual = false}) {
    _locationShareTimer?.cancel();
    _locationShareEndAt = null;
    _locationShareLastUpdatedAt = null;
    _locationShareCurrentPosition = null;
    _isLocationSharing = false;
    KoruBeniForegroundService.stop();
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

  @override
  void dispose() {
    _locationShareTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocationShareState(Duration remaining) async {
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    final permission = await _locationService.checkPermission();
    final canReadLocation =
        serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse);

    if (canReadLocation) {
      final refreshed = await _locationService.getCurrentLocation(
        highAccuracy: false,
      );
      if (refreshed.isSuccess && refreshed.position != null) {
        _locationShareCurrentPosition = refreshed.position;
        _locationShareLastUpdatedAt = DateTime.now();
      }
    }

    KoruBeniForegroundService.updateNotification(
      'foreground_location_share_title'.tr(),
      _buildLocationShareNotificationBody(remaining),
    );
  }

  String _buildLocationShareNotificationBody(Duration remaining) {
    final minutes = remaining.inSeconds <= 0
        ? 1
        : ((remaining.inSeconds + 59) ~/ 60).clamp(1, 60 * 24);

    final updatedAt = _locationShareLastUpdatedAt;
    if (updatedAt == null) {
      return 'foreground_location_share_body'.tr(
        namedArgs: {'minutes': '$minutes'},
      );
    }

    return 'foreground_location_share_body_updated'.tr(
      namedArgs: {'minutes': '$minutes', 'time': _formatClock(updatedAt)},
    );
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
