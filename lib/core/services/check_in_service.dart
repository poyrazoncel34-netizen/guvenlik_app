// ============================================================================
// CHECK-IN SERVİSİ (KONTROL NOKTASI)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../domain/models/activity_event.dart';
import '../services/activity_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';
import '../di/service_locator.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../services/location_service.dart';

/// Manages check-in timer logic — if user doesn't confirm safety within the
/// set duration + grace period, an emergency is automatically triggered.
class CheckInService extends ChangeNotifier {
  CheckInService._();
  static final CheckInService instance = CheckInService._();

  Timer? _mainTimer;
  Timer? _graceTimer;
  Timer? _tickTimer;
  DateTime? _endAt;
  DateTime? _graceEndAt;
  bool _isActive = false;
  bool _isGracePeriod = false;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  static const int _gracePeriodSeconds = 60;

  bool get isActive => _isActive;
  bool get isGracePeriod => _isGracePeriod;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  DateTime? get endAt => _endAt;

  /// Start a check-in timer with [minutes] duration.
  void start(int minutes) {
    stop();
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _isActive = true;
    _isGracePeriod = false;
    _endAt = DateTime.now().add(Duration(minutes: minutes));

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _endAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _onTimerExpired();
      } else {
        _remainingSeconds = remaining;
        notifyListeners();
      }
    });

    ActivityService.logEvent(
      type: ActivityType.checkIn,
      title: "check_in_started_title".tr(),
      description: "check_in_started_desc".tr(
        namedArgs: {'minutes': '$minutes'},
      ),
    );

    notifyListeners();
  }

  /// User confirms they are safe — resets the timer.
  void confirmSafe() {
    _graceTimer?.cancel();
    _graceEndAt = null;
    _isGracePeriod = false;

    if (_isActive && _endAt != null) {
      // Reset to the original total duration
      _endAt = DateTime.now().add(Duration(seconds: _totalSeconds));
      _remainingSeconds = _totalSeconds;

      ActivityService.logEvent(
        type: ActivityType.checkIn,
        title: "check_in_confirmed_title".tr(),
        description: "check_in_confirmed_desc".tr(),
      );

      notifyListeners();
    }
  }

  /// Stop the check-in completely.
  void stop() {
    _mainTimer?.cancel();
    _graceTimer?.cancel();
    _tickTimer?.cancel();
    _isActive = false;
    _isGracePeriod = false;
    _endAt = null;
    _graceEndAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    notifyListeners();
  }

  void _onTimerExpired() {
    _tickTimer?.cancel();
    _isGracePeriod = true;
    _remainingSeconds = _gracePeriodSeconds;
    _graceEndAt = DateTime.now().add(
      const Duration(seconds: _gracePeriodSeconds),
    );

    // Show local notification
    _showGraceNotification();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _graceEndAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _triggerEmergency();
      } else {
        _remainingSeconds = remaining;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  Future<void> _showGraceNotification() async {
    try {
      await NotificationService.instance.showEmergencyAlert(
        id: 9999,
        title: "check_in_notification_title".tr(),
        body: "check_in_notification_body".tr(),
      );
    } catch (_) {
      // Notification not critical
    }
  }

  Future<void> _triggerEmergency() async {
    _tickTimer?.cancel();

    ActivityService.logEvent(
      type: ActivityType.emergencyTriggered,
      title: "check_in_emergency_title".tr(),
      description: "check_in_emergency_desc".tr(),
    );

    // Send SMS to emergency contacts
    try {
      final contactsRepo = serviceLocator<ContactsRepository>();
      final numbers = await contactsRepo.getAllEmergencyNumbers();
      if (numbers.isNotEmpty) {
        String message = "check_in_emergency_msg".tr();

        // Try to append location
        try {
          final locationService = serviceLocator<LocationService>();
          final result = await locationService.getCurrentLocation();
          if (result.isSuccess && result.position != null) {
            final lat = result.position!.latitude;
            final lng = result.position!.longitude;
            final url =
                'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
            message += '\n$url';
          }
        } catch (_) {
          // Location not available, send without
        }

        await SmsService.sendSms(numbers: numbers, message: message);
      }
    } catch (_) {
      // Best effort
    }

    stop();
  }
}
