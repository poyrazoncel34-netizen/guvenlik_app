// ============================================================================
// SES TUŞU TETİKLEYİCİ SERVİSİ
// ============================================================================
// Native Kotlin VolumeButtonDetector ile iletişim kurar.
// Ses tuşlarına art arda basıldığında (2 sn içinde 3 basış) panik modu
// tetiklenir.
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Ses tuşu ile acil durum tetikleme servisi.
///
/// Android'de native [VolumeButtonDetector] ile iletişim kurar.
/// iOS'ta henüz desteklenmez (API kısıtlaması).
class VolumeTriggerService {
  static const String _eventChannel = 'com.poyrazoncel.korubeni/volume_button';
  static const String _controlChannel =
      'com.poyrazoncel.korubeni/volume_button/control';

  static VolumeTriggerService? _instance;
  static VolumeTriggerService get instance =>
      _instance ??= VolumeTriggerService._();

  VolumeTriggerService._({
    bool? supportedOverride,
    Stream<Object?>? eventStream,
    Future<void> Function(bool enabled)? nativeSetter,
  }) : _supportedOverride = supportedOverride,
       _eventStreamOverride = eventStream,
       _nativeSetter = nativeSetter;

  factory VolumeTriggerService.forTesting({
    required Stream<Object?> eventStream,
    required Future<void> Function(bool enabled) nativeSetter,
    bool supported = true,
  }) => VolumeTriggerService._(
    supportedOverride: supported,
    eventStream: eventStream,
    nativeSetter: nativeSetter,
  );

  final EventChannel _events = const EventChannel(_eventChannel);
  final MethodChannel _control = const MethodChannel(_controlChannel);
  final bool? _supportedOverride;
  final Stream<Object?>? _eventStreamOverride;
  final Future<void> Function(bool enabled)? _nativeSetter;

  StreamSubscription<Object?>? _subscription;
  VoidCallback? _onPanicTriggered;

  bool _isEnabled = false;
  bool _isListening = false;

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;

  /// Platform desteği var mı?
  static bool get isSupported => !kIsWeb && Platform.isAndroid;
  bool get _supported => _supportedOverride ?? isSupported;

  /// Tercih edilen durumu SharedPreferences'tan yükle.
  Future<void> loadPreference() async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(AppConstants.prefVolumeTrigger) ?? false;
  }

  /// Tercihi kaydet ve native tarafı güncelle.
  Future<void> setEnabled(bool enabled) async {
    if (!_supported) return;
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefVolumeTrigger, enabled);

    try {
      await _setNativeEnabled(enabled);
    } catch (e) {
      debugPrint('VolumeTrigger setEnabled failed: $e');
    }

    if (enabled && !_isListening) {
      _startListening();
    } else if (!enabled && _isListening) {
      _stopListening();
    }
  }

  /// Callback belirleyerek dinlemeyi başlat.
  void bindCallback({required VoidCallback onPanicTriggered}) {
    _onPanicTriggered = onPanicTriggered;
  }

  /// Callback belirleyerek etkin tercih için dinlemeyi başlat.
  void startListening({required VoidCallback onPanicTriggered}) {
    bindCallback(onPanicTriggered: onPanicTriggered);
    if (_isEnabled && !_isListening) {
      _startListening();
    }
  }

  void _startListening() {
    if (!_supported || _isListening) return;

    try {
      final eventStream =
          _eventStreamOverride ?? _events.receiveBroadcastStream();
      _subscription = eventStream.listen(
        (event) {
          if (event == 'volume_panic') {
            debugPrint('>>> Volume panic triggered!');
            _onPanicTriggered?.call();
          }
        },
        onError: (error) {
          debugPrint('VolumeTrigger stream error: $error');
        },
      );
      _isListening = true;

      // Native tarafı da etkinleştir
      _setNativeEnabled(true).catchError((_) {});
    } catch (e) {
      debugPrint('VolumeTrigger startListening failed: $e');
    }
  }

  Future<void> _setNativeEnabled(bool enabled) async {
    final setter = _nativeSetter;
    if (setter != null) {
      await setter(enabled);
      return;
    }
    await _control.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }

  /// Dinlemeyi durdur ama tercihi değiştirme.
  void stopListening() {
    _stopListening();
    _onPanicTriggered = null;
  }

  void dispose() {
    stopListening();
    _instance = null;
  }
}
