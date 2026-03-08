import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/countdown_screen.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigator.dart';
import '../services/app_lifecycle_handler.dart';
import '../services/check_in_service.dart';
import '../services/shake_detector_service.dart';
import '../services/volume_trigger_service.dart';

class EmergencyTriggerHost extends StatefulWidget {
  final Widget child;

  const EmergencyTriggerHost({super.key, required this.child});

  @override
  State<EmergencyTriggerHost> createState() => _EmergencyTriggerHostState();
}

class _EmergencyTriggerHostState extends State<EmergencyTriggerHost>
    with WidgetsBindingObserver {
  final ShakeDetectorService _shakeDetector = ShakeDetectorService.instance;
  bool _countdownOpen = false;
  bool _foregroundTriggersEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CheckInService.instance.initialize();
    _startForegroundTriggers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundTriggers();
      CheckInService.instance.handleAppResumed();
      // Re-auth after prolonged background
      AppLifecycleHandler.instance.onResumed();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopForegroundTriggers();
      // Record background start time
      AppLifecycleHandler.instance.onPaused();
    }
  }

  void _startForegroundTriggers() {
    _foregroundTriggersEnabled = true;
    _startShakeIfEnabled();
    _startVolumeIfEnabled();
  }

  Future<void> _startShakeIfEnabled() async {
    await _shakeDetector.loadPreferences();
    if (!mounted || !_foregroundTriggersEnabled) return;
    _shakeDetector.startListening(onShakeDetected: _openCountdown);
  }

  Future<void> _startVolumeIfEnabled() async {
    if (!VolumeTriggerService.isSupported) return;

    VolumeTriggerService.instance.startListening(
      onPanicTriggered: _openCountdown,
    );
    await VolumeTriggerService.instance.loadPreference();
    if (!mounted || !_foregroundTriggersEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final volumeEnabled =
        prefs.getBool(AppConstants.prefVolumeTrigger) ?? false;
    if (volumeEnabled) {
      VolumeTriggerService.instance.startListening(
        onPanicTriggered: _openCountdown,
      );
    }
  }

  void _stopForegroundTriggers() {
    _foregroundTriggersEnabled = false;
    _shakeDetector.stopListening();
    VolumeTriggerService.instance.stopListening();
  }

  Future<void> _openCountdown() async {
    if (_countdownOpen) {
      return;
    }

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _countdownOpen = true;
    await HapticFeedback.heavyImpact();
    await navigator.push(
      MaterialPageRoute(builder: (_) => const CountdownScreen()),
    );
    _countdownOpen = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundTriggers();
    _shakeDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
