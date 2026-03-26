// ============================================================================
// CHECK-IN SERVİSİ (KONTROL NOKTASI)
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/activity_event.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../screens/emergency_call_screen.dart';
import '../di/service_locator.dart';
import '../navigation/app_navigator.dart';
import '../services/activity_service.dart';
import '../services/call_service.dart';
import '../services/emergency_platform_service.dart';
import '../services/foreground_service.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/sms_service.dart';
import '../utils/emergency_message_helper.dart';

/// Manages check-in timer logic — if user doesn't confirm safety within the
/// set duration + grace period, an emergency is automatically triggered.
class CheckInService extends ChangeNotifier {
  CheckInService._();
  static final CheckInService instance = CheckInService._();

  static const int _gracePeriodSeconds = 60;
  static const String _stateKey = 'check_in_state_v2';
  // Legacy keys for migration
  static const String _activeKey = 'check_in_active';
  static const String _totalSecondsKey = 'check_in_total_seconds';
  static const String _endAtKey = 'check_in_end_at';
  static const String _graceEndAtKey = 'check_in_grace_end_at';

  Timer? _tickTimer;
  DateTime? _endAt;
  DateTime? _graceEndAt;
  bool _isActive = false;
  bool _isGracePeriod = false;
  bool _emergencyInProgress = false;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;

  bool get isActive => _isActive;
  bool get isGracePeriod => _isGracePeriod;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  DateTime? get endAt => _isGracePeriod ? _graceEndAt : _endAt;

  Future<void> initialize() async {
    await _restoreFromStorage();
  }

  Future<void> handleAppResumed() async {
    await _restoreFromStorage();
  }

  /// Start a check-in timer with [minutes] duration.
  Future<void> start(int minutes) async {
    await stop();

    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _isActive = true;
    _isGracePeriod = false;
    _endAt = DateTime.now().add(Duration(minutes: minutes));
    _graceEndAt = null;

    await _persistState();
    await _scheduleNativeMainDeadline();
    await _startBackgroundProtection();
    _startMainTicker();

    await ActivityService.logEvent(
      type: ActivityType.checkIn,
      title: "check_in_started_title".tr(),
      description: "check_in_started_desc".tr(
        namedArgs: {'minutes': '$minutes'},
      ),
    );

    notifyListeners();
  }

  /// User confirms they are safe — resets the timer.
  Future<void> confirmSafe() async {
    if (!_isActive || _totalSeconds <= 0) {
      return;
    }

    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = DateTime.now().add(Duration(seconds: _totalSeconds));
    _remainingSeconds = _totalSeconds;

    await _persistState();
    await _scheduleNativeMainDeadline();
    await _startBackgroundProtection();
    _startMainTicker();

    await ActivityService.logEvent(
      type: ActivityType.checkIn,
      title: "check_in_confirmed_title".tr(),
      description: "check_in_confirmed_desc".tr(),
    );

    notifyListeners();
  }

  /// Stop the check-in completely.
  Future<void> stop() async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _emergencyInProgress = false;

    await _clearPersistedState();
    await EmergencyPlatformService.instance.cancelCheckIn();
    await KoruBeniForegroundService.stop();
    notifyListeners();
  }

  Future<void> _restoreFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Try atomic JSON blob first
    final stateJson = prefs.getString(_stateKey);
    if (stateJson != null) {
      try {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        final active = state['active'] as bool? ?? false;
        if (!active) return;

        final totalSeconds = state['totalSeconds'] as int? ?? 0;
        final restoredEndAt = _parseDateTime(state['endAt'] as String?);
        if (totalSeconds <= 0 || restoredEndAt == null) {
          await stop();
          return;
        }

        _isActive = true;
        _totalSeconds = totalSeconds;
        _endAt = restoredEndAt;
        _graceEndAt = _parseDateTime(state['graceEndAt'] as String?);

        await _reconcileWithClock();
        return;
      } catch (_) {
        // Corrupted JSON — fall through to legacy
      }
    }

    // Legacy key migration
    final storedActive = prefs.getBool(_activeKey) ?? false;
    if (!storedActive) return;

    final totalSeconds = prefs.getInt(_totalSecondsKey) ?? 0;
    final restoredEndAt = _parseDateTime(prefs.getString(_endAtKey));
    if (totalSeconds <= 0 || restoredEndAt == null) {
      await stop();
      return;
    }

    _isActive = true;
    _totalSeconds = totalSeconds;
    _endAt = restoredEndAt;
    _graceEndAt = _parseDateTime(prefs.getString(_graceEndAtKey));

    // Migrate to atomic format
    await _persistState();
    await _clearLegacyKeys(prefs);

    await _reconcileWithClock();
  }

  Future<void> _reconcileWithClock() async {
    if (!_isActive || _endAt == null) {
      return;
    }

    final now = DateTime.now();
    if (_graceEndAt != null) {
      final graceRemaining = _graceEndAt!.difference(now).inSeconds;
      if (graceRemaining > 0) {
        _isGracePeriod = true;
        _remainingSeconds = graceRemaining;
        await _startBackgroundProtection();
        _startGraceTicker();
        notifyListeners();
        return;
      }

      await _triggerEmergency();
      return;
    }

    final mainRemaining = _endAt!.difference(now).inSeconds;
    if (mainRemaining > 0) {
      _isGracePeriod = false;
      _remainingSeconds = mainRemaining;
      await _startBackgroundProtection();
      _startMainTicker();
      notifyListeners();
      return;
    }

    _isGracePeriod = true;
    _graceEndAt = _endAt!.add(const Duration(seconds: _gracePeriodSeconds));
    await _persistState();

    final graceRemaining = _graceEndAt!.difference(now).inSeconds;
    if (graceRemaining > 0) {
      _remainingSeconds = graceRemaining;
      await _startBackgroundProtection();
      _startGraceTicker();
      notifyListeners();
      return;
    }

    await _triggerEmergency();
  }

  void _startMainTicker() {
    _cancelTicker();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _endAt;
      if (!_isActive || deadline == null || _isGracePeriod) {
        _cancelTicker();
        return;
      }

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _onMainTimerExpired();
        return;
      }

      _remainingSeconds = remaining;
      notifyListeners();
    });
  }

  void _startGraceTicker() {
    _cancelTicker();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _graceEndAt;
      if (!_isActive || deadline == null || !_isGracePeriod) {
        _cancelTicker();
        return;
      }

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _triggerEmergency();
        return;
      }

      _remainingSeconds = remaining;
      notifyListeners();
    });
  }

  Future<void> _onMainTimerExpired() async {
    if (!_isActive || _isGracePeriod) {
      return;
    }

    _cancelTicker();
    _isGracePeriod = true;
    _graceEndAt = DateTime.now().add(
      const Duration(seconds: _gracePeriodSeconds),
    );
    _remainingSeconds = _gracePeriodSeconds;

    await _persistState();
    await _scheduleNativeGraceDeadline();
    await _startBackgroundProtection();
    await _showGraceNotification();
    _startGraceTicker();
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
      // SILENT-4: Haptic fallback when notification fails
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    }
  }

  Future<void> _triggerEmergency() async {
    if (_emergencyInProgress) {
      return;
    }
    _emergencyInProgress = true;
    _cancelTicker();

    try {
      await ActivityService.logEvent(
        type: ActivityType.emergencyTriggered,
        title: "check_in_emergency_title".tr(),
        description: "check_in_emergency_desc".tr(),
      );
      await HapticService.emergencyTriggered();
      await NotificationService.instance.showEmergencyAlert(
        id: 9999,
        title: "check_in_emergency_title".tr(),
        body: "alarm_notification_body".tr(),
      );

      final contactsRepo = serviceLocator<ContactsRepository>();
      final numbers = await contactsRepo.getAllEmergencyNumbers();
      final primaryContact = await contactsRepo.getPrimaryEmergencyContact();
      final emergencyMessage =
          await EmergencyMessageHelper.buildCheckInMessage();

      final smsResult = numbers.isEmpty
          ? SmsComposeResult.failed('emergency_contact_not_found'.tr())
          : await SmsService.sendSms(
              numbers: numbers,
              message: emergencyMessage.message,
            );

      final primaryNumber =
          primaryContact?.phone ?? (numbers.isNotEmpty ? numbers.first : '');
      var calledNumber = primaryNumber;
      var callResult = EmergencyCallResult.failed(primaryNumber);

      if (primaryNumber.isNotEmpty) {
        callResult = await CallService.startEmergencyCall(primaryNumber);
        if (!callResult.isSuccess && numbers.length > 1) {
          for (final fallbackNumber in numbers) {
            if (fallbackNumber == primaryNumber) continue;
            final fallbackResult = await CallService.startEmergencyCall(
              fallbackNumber,
            );
            if (fallbackResult.isSuccess) {
              callResult = fallbackResult;
              calledNumber = fallbackNumber;
              break;
            }
          }
        }
      }

      final shouldKeepForeground = smsResult.isSuccess || callResult.isSuccess;
      await _clearMonitoringState(stopForeground: !shouldKeepForeground);

      final navigator = rootNavigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => EmergencyCallScreen(
              name: primaryContact?.name ?? "pin_verify_emergency_contact".tr(),
              phone: calledNumber,
              callResult: callResult,
              smsResult: smsResult,
              locationStatusMessage: emergencyMessage.locationStatusMessage,
            ),
          ),
        );
      } else if (shouldKeepForeground) {
        await KoruBeniForegroundService.stop();
      }
    } catch (e) {
      debugPrint('CheckInService emergency trigger failed: $e');
      await _clearMonitoringState(stopForeground: true);
    } finally {
      _emergencyInProgress = false;
    }
  }

  Future<void> _startBackgroundProtection() async {
    await KoruBeniForegroundService.start();

    final label = _isGracePeriod
        ? "check_in_grace_label".tr()
        : "check_in_title".tr();
    final body =
        '${"check_in_remaining".tr()}: ${_formatDuration(_remainingSeconds)}';
    KoruBeniForegroundService.updateNotification(label, body);
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isActive) {
      await _clearPersistedState();
      return;
    }

    final state = {
      'active': _isActive,
      'totalSeconds': _totalSeconds,
      'endAt': _endAt?.toIso8601String(),
      'graceEndAt': _graceEndAt?.toIso8601String(),
    };
    await prefs.setString(_stateKey, jsonEncode(state));
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await _clearLegacyKeys(prefs);
  }

  Future<void> _clearLegacyKeys(SharedPreferences prefs) async {
    await prefs.remove(_activeKey);
    await prefs.remove(_totalSecondsKey);
    await prefs.remove(_endAtKey);
    await prefs.remove(_graceEndAtKey);
  }

  Future<void> _clearMonitoringState({required bool stopForeground}) async {
    _cancelTicker();
    _isActive = false;
    _isGracePeriod = false;
    _graceEndAt = null;
    _endAt = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;

    await _clearPersistedState();
    await EmergencyPlatformService.instance.cancelCheckIn();
    if (stopForeground) {
      await KoruBeniForegroundService.stop();
    }
    notifyListeners();
  }

  Future<void> handleNativeGraceStarted() async {
    if (!_isActive) {
      return;
    }
    _cancelTicker();
    _isGracePeriod = true;
    _graceEndAt = DateTime.now().add(
      const Duration(seconds: _gracePeriodSeconds),
    );
    _remainingSeconds = _gracePeriodSeconds;
    await _persistState();
    await _scheduleNativeGraceDeadline();
    await _showGraceNotification();
    _startGraceTicker();
    notifyListeners();
  }

  Future<void> handleNativeExpired() async {
    if (!_isActive) {
      return;
    }
    await _triggerEmergency();
  }

  Future<void> _scheduleNativeMainDeadline() async {
    if (_endAt == null) {
      return;
    }
    await EmergencyPlatformService.instance.scheduleCheckIn(
      phase: 'main',
      deadline: _endAt!,
      graceDuration: const Duration(seconds: _gracePeriodSeconds),
    );
  }

  Future<void> _scheduleNativeGraceDeadline() async {
    if (_graceEndAt == null) {
      return;
    }
    await EmergencyPlatformService.instance.scheduleCheckIn(
      phase: 'grace',
      deadline: _graceEndAt!,
      graceDuration: Duration.zero,
    );
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _cancelTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }
}
