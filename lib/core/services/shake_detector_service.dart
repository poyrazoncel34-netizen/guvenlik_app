import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects phone shake gestures using accelerometer data.
/// When a shake is detected, [onShake] callback is triggered.
class ShakeDetectorService {
  static const double _shakeThreshold = 15.0; // m/s^2
  static const int _shakeCountThreshold = 3; // shakes needed
  static const Duration _shakeWindow = Duration(milliseconds: 1500);
  static const Duration _cooldown = Duration(seconds: 3);

  StreamSubscription<AccelerometerEvent>? _subscription;
  VoidCallback? onShake;

  final List<DateTime> _shakeTimestamps = [];
  DateTime? _lastTrigger;
  bool _isListening = false;

  bool get isListening => _isListening;

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
            if ((magnitude - 9.8).abs() > _shakeThreshold) {
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
