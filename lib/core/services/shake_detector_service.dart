import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shake sensitivity levels.
enum ShakeSensitivity {
  low,    // Hard shake only
  medium, // Default
  high,   // Very sensitive
}

/// Detects phone shake gestures using accelerometer data.
/// When a shake is detected, [onShake] callback is triggered.
class ShakeDetectorService {
  static const Map<ShakeSensitivity, double> _thresholds = {
    ShakeSensitivity.low: 22.0,
    ShakeSensitivity.medium: 15.0,
    ShakeSensitivity.high: 10.0,
  };

  static const int _shakeCountThreshold = 3; // shakes needed
  static const Duration _shakeWindow = Duration(milliseconds: 1500);
  static const Duration _cooldown = Duration(seconds: 3);
  static const String _prefSensitivity = 'pref_shake_sensitivity';

  StreamSubscription<AccelerometerEvent>? _subscription;
  VoidCallback? onShake;

  ShakeSensitivity _sensitivity = ShakeSensitivity.medium;
  final List<DateTime> _shakeTimestamps = [];
  DateTime? _lastTrigger;
  bool _isListening = false;

  bool get isListening => _isListening;
  ShakeSensitivity get sensitivity => _sensitivity;
  double get currentThreshold => _thresholds[_sensitivity] ?? 15.0;

  /// Load saved sensitivity from preferences.
  Future<void> loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefSensitivity) ?? 1;
    _sensitivity = ShakeSensitivity.values[index.clamp(0, 2)];
  }

  /// Set and persist sensitivity level.
  Future<void> setSensitivity(ShakeSensitivity level) async {
    _sensitivity = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSensitivity, level.index);
  }

  /// Start listening for shake events
  void startListening({required VoidCallback onShakeDetected}) {
    if (_isListening) return;
    onShake = onShakeDetected;
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
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _shakeTimestamps.clear();
    onShake = null;
  }

  void dispose() {
    stopListening();
  }
}
