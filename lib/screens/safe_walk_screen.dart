// ============================================================================
// GÜVENLİ YÜRÜYÜŞ EKRANI
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/services/activity_service.dart';
import '../core/services/emergency_platform_service.dart';
import '../core/services/foreground_service.dart';
import '../core/services/notification_service.dart';
// Analytics service removed (offline-first)
import '../core/constants/app_constants.dart';
import '../core/widgets/feature_warning_dialog.dart';
import '../domain/models/activity_event.dart';
import '../widgets/siren_dialog.dart';
import 'countdown_screen.dart';

class SafeWalkScreen extends StatefulWidget {
  const SafeWalkScreen({super.key});

  @override
  State<SafeWalkScreen> createState() => _SafeWalkScreenState();
}

class _SafeWalkScreenState extends State<SafeWalkScreen>
    with WidgetsBindingObserver {
  static const String _activeKey = 'safe_walk_active';
  static const String _endAtKey = 'safe_walk_end_at';
  static const String _durationMinutesKey = 'safe_walk_duration_minutes';

  int _selectedMinutes = 15;
  bool _isActive = false;
  Timer? _timer;
  DateTime? _endTime;
  int _remainingSeconds = 0;
  bool _preWarningFired = false;
  bool _timerExpiredHandled = false;

  final List<int> _durations = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background, recalculate remaining time from _endTime
    if (state == AppLifecycleState.resumed && _isActive && _endTime != null) {
      final remaining = _endTime!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _timer?.cancel();
        _onTimerExpired();
      } else {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _restoreState();
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_activeKey) ?? false;
    final endAtRaw = prefs.getString(_endAtKey);
    final duration = prefs.getInt(_durationMinutesKey) ?? _selectedMinutes;
    final endAt = endAtRaw == null ? null : DateTime.tryParse(endAtRaw);

    if (!active || endAt == null) {
      return;
    }

    final remaining = endAt.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      await _clearPersistedState();
      _onTimerExpired();
      return;
    }

    setState(() {
      _selectedMinutes = duration;
      _isActive = true;
      _endTime = endAt;
      _remainingSeconds = remaining.inSeconds;
    });
    _startTicker();
  }

  Future<void> _startSafeWalk() async {
    // İlk kullanımda uyarı dialogu göster
    final shown = await FeatureWarningHelper.showIfNeeded(
      context,
      prefKey: AppConstants.prefWarningWalk,
      featureName: 'safe_walk',
      title: FeatureWarningHelper.checkinTitle,
      content: FeatureWarningHelper.checkinContent,
    );
    if (!shown || !mounted) return;
    HapticFeedback.mediumImpact();
    final endTime = DateTime.now().add(Duration(minutes: _selectedMinutes));
    setState(() {
      _isActive = true;
      _endTime = endTime;
      _remainingSeconds = _selectedMinutes * 60;
    });

    // Analytics removed (offline-first)
    ActivityService.logEvent(
      type: ActivityType.locationShared,
      title: "safe_walk_started_activity".tr(),
      description: "safe_walk_started_desc".tr(
        namedArgs: {"minutes": "$_selectedMinutes"},
      ),
    );

    await KoruBeniForegroundService.start();
    await EmergencyPlatformService.instance.scheduleCheckIn(
      phase: 'grace',
      deadline: endTime,
      graceDuration: Duration.zero,
    );
    await _persistState();
    _updateForegroundStatus();

    _preWarningFired = false;
    _startTicker();
  }

  void _firePreExpiryWarning() {
    // Haptic alert
    HapticFeedback.heavyImpact();
    // Local notification (works even when screen is off)
    NotificationService.instance.showEmergencyAlert(
      id: 200,
      title: 'safe_walk_pre_warning_title'.tr(),
      body: 'safe_walk_pre_warning_body'.tr(),
    );
  }

  Future<void> _onTimerExpired() async {
    // RACE-3: Prevent double trigger from timer + native grace alarm race
    if (_timerExpiredHandled) return;
    _timerExpiredHandled = true;

    // Timer expired without user checking in - trigger emergency
    HapticFeedback.heavyImpact();
    setState(() {
      _isActive = false;
      _timer?.cancel();
    });
    EmergencyPlatformService.instance.cancelCheckIn();
    await _clearPersistedState();

    // Auto-play siren before navigating to countdown
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SirenDialog(),
    );

    // Navigate to countdown after short delay to let siren start
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close siren dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CountdownScreen()),
        );
      }
    });
  }

  Future<void> _checkIn() async {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    KoruBeniForegroundService.stop();
    EmergencyPlatformService.instance.cancelCheckIn();
    await _clearPersistedState();
    // Analytics removed (offline-first)
    ActivityService.logEvent(
      type: ActivityType.safetyCheck,
      title: "safe_walk_completed_activity".tr(),
      description: "safe_walk_completed_desc".tr(),
    );

    setState(() {
      _isActive = false;
      _endTime = null;
      _remainingSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              "safe_walk_safe_recorded".tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _cancelWalk() async {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    KoruBeniForegroundService.stop();
    EmergencyPlatformService.instance.cancelCheckIn();
    await _clearPersistedState();
    setState(() {
      _isActive = false;
      _endTime = null;
      _remainingSeconds = 0;
    });
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endTime == null) {
        timer.cancel();
        return;
      }
      final remaining = _endTime!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        timer.cancel();
        _onTimerExpired();
      } else {
        setState(() {
          _remainingSeconds = remaining.inSeconds;
        });
        if (_remainingSeconds % 30 == 0 || _remainingSeconds <= 60) {
          _updateForegroundStatus();
        }
        final warningThreshold = _selectedMinutes >= 4
            ? 120
            : (_selectedMinutes * 60 * 0.1).round();
        if (!_preWarningFired &&
            _remainingSeconds <= warningThreshold &&
            _remainingSeconds > 0) {
          _preWarningFired = true;
          _firePreExpiryWarning();
        }
      }
    });
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, _isActive);
    await prefs.setInt(_durationMinutesKey, _selectedMinutes);
    if (_endTime != null) {
      await prefs.setString(_endAtKey, _endTime!.toIso8601String());
    }
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_endAtKey);
    await prefs.remove(_durationMinutesKey);
  }

  String _formatTime(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _updateForegroundStatus() {
    KoruBeniForegroundService.updateNotification(
      'KoruBeni Aktif',
      'Güvenli yürüyüş — ${_formatTime(_remainingSeconds)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "semantics_safe_walk".tr(),
      hint: "semantics_safe_walk_hint".tr(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text("safe_walk_title".tr()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (_isActive) {
                _showExitWarning();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isActive ? _buildActiveView() : _buildSetupView(),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  size: 40,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "safe_walk_title".tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "safe_walk_desc".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "safe_walk_select_duration".tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _durations.map((min) {
            final isSelected = _selectedMinutes == min;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedMinutes = min);
              },
              child: AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    "safe_walk_minutes".tr(namedArgs: {"min": "$min"}),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startSafeWalk,
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: Text(
              "safe_walk_start".tr(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActiveView() {
    final progress = _remainingSeconds / (_selectedMinutes * 60);
    final isUrgent = _remainingSeconds <= 30;

    return Column(
      children: [
        const SizedBox(height: 40),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 14,
                backgroundColor: AppColors.border.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUrgent ? AppColors.emergency : AppColors.accent,
                ),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              children: [
                Icon(
                  isUrgent
                      ? Icons.warning_rounded
                      : Icons.directions_walk_rounded,
                  size: 36,
                  color: isUrgent ? AppColors.emergency : AppColors.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: isUrgent
                        ? AppColors.emergency
                        : AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUrgent
                      ? "safe_walk_hurry".tr()
                      : "safe_walk_remaining".tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isUrgent
                        ? AppColors.emergency
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 50),
        if (isUrgent)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emergency.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.emergency.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.emergency,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "safe_walk_urgent_warning".tr(),
                    style: const TextStyle(
                      color: AppColors.emergency,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _checkIn,
            icon: const Icon(Icons.check_circle_rounded, size: 24),
            label: Text(
              "safe_walk_safe".tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancelWalk,
          child: Text(
            "safe_walk_cancel".tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showExitWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "safe_walk_exit_title".tr(),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          "safe_walk_exit_message".tr(),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("safe_walk_exit_stay".tr()),
          ),
          TextButton(
            onPressed: () {
              _cancelWalk();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              "safe_walk_exit_cancel".tr(),
              style: const TextStyle(color: AppColors.emergency),
            ),
          ),
        ],
      ),
    );
  }
}
