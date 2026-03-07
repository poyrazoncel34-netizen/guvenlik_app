import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/countdown_screen.dart';
import '../navigation/app_navigator.dart';
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
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  bool _countdownOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startForegroundTriggers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundTriggers();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopForegroundTriggers();
    }
  }

  Future<void> _startForegroundTriggers() async {
    _shakeDetector.startListening(onShakeDetected: _openCountdown);

    if (VolumeTriggerService.isSupported) {
      await VolumeTriggerService.instance.loadPreference();
      VolumeTriggerService.instance.startListening(
        onPanicTriggered: _openCountdown,
      );
    }
  }

  void _stopForegroundTriggers() {
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
