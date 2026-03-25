import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'emergency_platform_service.dart';
import 'resource_monitor_service.dart';

/// Shake sensitivity levels.
enum ShakeSensitivity {
  low, // Hard shake only
  medium, // Default
  high, // Very sensitive
}

/// Detects phone shake gestures using accelerometer data.
/// When a shake is detected, [onShake] callback is triggered.
class ShakeDetectorService {
  ShakeDetectorService._();

  static final ShakeDetectorService _instance = ShakeDetectorService._();
  static ShakeDetectorService get instance => _instance;

  static const Map<ShakeSensitivity, double> _thresholds = {
    ShakeSensitivity.low: 22.0,
    ShakeSensitivity.medium: 15.0,
    ShakeSensitivity.high: 10.0,
  };

  static const int _shakeCountThreshold = 3; // shakes needed
  static const Duration _shakeWindow = Duration(milliseconds: 1500);
  static const Duration _cooldown = Duration(seconds: 3);

  StreamSubscription<AccelerometerEvent>? _subscription;
  VoidCallback? onShake;

  bool _isEnabled = true;
  ShakeSensitivity _sensitivity = ShakeSensitivity.medium;
  final List<DateTime> _shakeTimestamps = [];
  DateTime? _lastTrigger;
  bool _isListening = false;
  bool _lowBattery = false;
  StreamSubscription<bool>? _lowBatterySubscription;

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  ShakeSensitivity get sensitivity => _sensitivity;
  double get currentThreshold =>
      _lowBattery ? 22.0 : (_thresholds[_sensitivity] ?? 15.0);

  /// Load saved enablement and sensitivity from preferences.
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(AppConstants.prefShakeEnabled) ?? true;
    final index = prefs.getInt(AppConstants.prefShakeSensitivity) ?? 1;
    _sensitivity = ShakeSensitivity.values[index.clamp(0, 2)];
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefShakeEnabled, enabled);

    if (enabled) {
      if (onShake != null && !_isListening) {
        _startListening();
      }
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _isListening = false;
      await EmergencyPlatformService.instance.disarmShake();
    } else {
      _cancelSubscription();
    }
  }

  /// Set and persist sensitivity level.
  Future<void> setSensitivity(ShakeSensitivity level) async {
    _sensitivity = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefShakeSensitivity, level.index);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await EmergencyPlatformService.instance.setShakeSensitivity(level.index);
    }
  }

  /// Start listening for shake events
  void startListening({required VoidCallback onShakeDetected}) {
    onShake = onShakeDetected;
    _lowBatterySubscription ??= ResourceMonitorService.instance.lowBatteryStream
        .listen((isLow) => _lowBattery = isLow);
    if (!_isEnabled || _isListening) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _isListening = true;
      EmergencyPlatformService.instance.armShake();
      EmergencyPlatformService.instance.setShakeSensitivity(_sensitivity.index);
      return;
    }

    _startListening();
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;
    _subscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen(
          (event) {
            final magnitude = sqrt(
              event.x * event.x + event.y * event.y + event.z * event.z,
            );

            // Subtract gravity (~9.8) and check threshold
            if ((magnitude - 9.8).abs() > currentThreshold) {
              _registerShake();
            }
          },
          onError: (e) {
            debugPrint('ShakeDetector error: $e');
          },
        );
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _shakeTimestamps.clear();
  }

  void _registerShake() {
    final now = DateTime.now();

    // Cooldown check
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _cooldown) {
      return;
    }

    // Remove old timestamps outside the shake window
    _shakeTimestamps.removeWhere((ts) => now.difference(ts) > _shakeWindow);
    _shakeTimestamps.add(now);

    if (_shakeTimestamps.length >= _shakeCountThreshold) {
      _shakeTimestamps.clear();
      _lastTrigger = now;
      onShake?.call();
    }
  }

  /// Stop listening for shake events
  void stopListening() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _isListening = false;
      EmergencyPlatformService.instance.disarmShake();
    } else {
      _cancelSubscription();
    }
    onShake = null;
  }

  void dispose() {
    _lowBatterySubscription?.cancel();
    stopListening();
  }
}
