import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics event tracking.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Screen tracking
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics screen error: $e');
    }
  }

  // Emergency events
  static Future<void> logEmergencyTriggered() async {
    await _logEvent('emergency_triggered');
  }

  static Future<void> logEmergencyCancelled() async {
    await _logEvent('emergency_cancelled');
  }

  // Feature usage
  static Future<void> logPanicButtonPressed() async {
    await _logEvent('panic_button_pressed');
  }

  static Future<void> logFakeCallUsed() async {
    await _logEvent('fake_call_used');
  }

  static Future<void> logSirenActivated() async {
    await _logEvent('siren_activated');
  }

  static Future<void> logLocationShared({required int minutes}) async {
    await _logEvent('location_shared', {'duration_minutes': minutes});
  }

  static Future<void> logQuickMessageSent() async {
    await _logEvent('quick_message_sent');
  }

  static Future<void> logContactAdded() async {
    await _logEvent('contact_added');
  }

  static Future<void> logSafeWalkStarted({required int minutes}) async {
    await _logEvent('safe_walk_started', {'duration_minutes': minutes});
  }

  static Future<void> logSafeWalkCompleted() async {
    await _logEvent('safe_walk_completed');
  }

  static Future<void> logAudioRecordingStarted() async {
    await _logEvent('audio_recording_started');
  }

  static Future<void> logShakeDetected() async {
    await _logEvent('shake_detected');
  }

  static Future<void> logBiometricUsed({required bool success}) async {
    await _logEvent('biometric_auth', {'success': success});
  }

  // Settings
  static Future<void> logSettingChanged(String setting, bool value) async {
    await _logEvent('setting_changed', {'setting': setting, 'value': value});
  }

  static Future<void> logPinChanged() async {
    await _logEvent('pin_changed');
  }

  // Auth
  static Future<void> logLogin() async {
    try {
      await _analytics.logLogin(loginMethod: 'phone');
    } catch (e) {
      debugPrint('Analytics login error: $e');
    }
  }

  static Future<void> logSignUp() async {
    try {
      await _analytics.logSignUp(signUpMethod: 'phone');
    } catch (e) {
      debugPrint('Analytics signup error: $e');
    }
  }

  // Generic event
  static Future<void> _logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics event error ($name): $e');
    }
  }
}
