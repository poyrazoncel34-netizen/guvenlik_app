import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../presentation/providers/subscription_provider.dart';
import '../../screens/countdown_screen.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigator.dart';
import '../services/app_lifecycle_handler.dart';
import '../services/check_in_expiry_coordinator.dart';
import '../services/check_in_service.dart';
import '../services/emergency_platform_service.dart';
import '../services/emergency_readiness_service.dart';
import '../services/volume_trigger_service.dart';

class EmergencyTriggerHost extends StatefulWidget {
  final Widget child;

  const EmergencyTriggerHost({super.key, required this.child});

  @override
  State<EmergencyTriggerHost> createState() => _EmergencyTriggerHostState();
}

class _EmergencyTriggerHostState extends State<EmergencyTriggerHost>
    with WidgetsBindingObserver {
  bool _countdownOpen = false;
  StreamSubscription<Map<String, dynamic>>? _platformEventsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CheckInService.instance.initialize();
    unawaited(EmergencyReadinessService.instance.checkReadiness());
    _bindPlatformEvents();
    _startForegroundTriggers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(EmergencyReadinessService.instance.checkReadiness());
      _startForegroundTriggers();
      CheckInService.instance.handleAppResumed();
      _consumePendingTrigger();
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
    _startVolumeIfEnabled();
  }

  Future<void> _startVolumeIfEnabled() async {
    if (!VolumeTriggerService.isSupported) return;

    await VolumeTriggerService.instance.loadPreference();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final volumeEnabled =
        prefs.getBool(AppConstants.prefVolumeTrigger) ?? false;
    if (volumeEnabled) {
      final subscription = context.read<SubscriptionProvider>();
      await subscription.initialize();
      if (!mounted) return;
      if (!subscription.isPro) {
        await VolumeTriggerService.instance.setEnabled(false);
        return;
      }
    }
    if (volumeEnabled) {
      VolumeTriggerService.instance.startListening(
        onPanicTriggered: _openCountdown,
      );
    }
  }

  void _stopForegroundTriggers() {
    VolumeTriggerService.instance.stopListening();
  }

  void _bindPlatformEvents() {
    EmergencyPlatformService.instance.initialize();
    _platformEventsSubscription = EmergencyPlatformService.instance.events
        .listen((event) async {
          try {
            final type = event['type']?.toString();
            final sessionId = event['sessionId']?.toString();
            if (type == 'checkInGraceStarted') {
              if (sessionId == null ||
                  sessionId == CheckInExpiryCoordinator.checkInSession) {
                await CheckInService.instance.handleNativeGraceStarted();
              }
              return;
            }
            if (type == 'checkInExpired') {
              await _handleCheckInExpired(sessionId: sessionId);
            }
          } catch (_) {
            // Native event handling must never crash the root widget.
            return;
          }
        });
    _consumePendingTrigger();
  }

  Future<void> _consumePendingTrigger() async {
    final pending = await EmergencyPlatformService.instance
        .consumePendingTrigger();
    if (pending == null) {
      return;
    }

    final type = pending['type']?.toString();
    final sessionId = pending['sessionId']?.toString();
    if (type == 'checkInGraceStarted') {
      if (sessionId == null ||
          sessionId == CheckInExpiryCoordinator.checkInSession) {
        await CheckInService.instance.handleNativeGraceStarted();
      }
      return;
    }
    if (type == 'checkInExpired') {
      await _handleCheckInExpired(sessionId: sessionId);
    }
  }

  Future<void> _handleCheckInExpired({String? sessionId}) async {
    final isCheckIn =
        sessionId == null ||
        sessionId == CheckInExpiryCoordinator.checkInSession;
    if (isCheckIn &&
        (CheckInService.instance.isActive ||
            CheckInService.instance.isGracePeriod)) {
      await CheckInService.instance.handleNativeExpired();
      return;
    }
    final resolvedSessionId =
        sessionId ?? CheckInExpiryCoordinator.safeWalkSession;
    if (!CheckInExpiryCoordinator.instance.tryClaim(
      'native_check_in_expired',
      sessionId: resolvedSessionId,
    )) {
      return;
    }
    await _openCountdown();
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
    try {
      await HapticFeedback.heavyImpact();
      await navigator.push(
        MaterialPageRoute(builder: (_) => const CountdownScreen()),
      );
    } finally {
      _countdownOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundTriggers();
    _platformEventsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
