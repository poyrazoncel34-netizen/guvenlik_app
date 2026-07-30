// ============================================================================
// GÜVENLİ YÜRÜYÜŞ EKRANI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/services/activity_service.dart';
import '../core/services/check_in_expiry_coordinator.dart';
import '../core/services/check_in_service.dart';
import '../core/services/contact_service.dart';
import '../core/services/emergency_session_contract.dart';
import '../core/services/pin_verification_service.dart';
import '../core/utils/emergency_number_validator.dart';
import '../core/services/notification_service.dart';
import '../core/utils/permission_helper.dart';
// Analytics service removed (offline-first)
import '../core/constants/app_constants.dart';
import '../core/widgets/exact_alarm_permission_guard.dart';
import '../core/widgets/feature_warning_dialog.dart';
import '../core/widgets/safety_session_pin_gate.dart';
import '../domain/models/activity_event.dart';
import '../presentation/providers/subscription_provider.dart';
import 'contacts_page.dart';

class SafeWalkScreen extends StatefulWidget {
  const SafeWalkScreen({super.key});

  @override
  State<SafeWalkScreen> createState() => _SafeWalkScreenState();
}

class _SafeWalkScreenState extends State<SafeWalkScreen> {
  // Safe-walk shares the check-in session controller (SPEC §6): same 60s grace
  // machine + same native primary-only backup. No screen-local timer and no
  // separate panic screen on expiry (escalation is primary-only).
  final CheckInService _controller = CheckInService.safeWalk;

  int _selectedMinutes = 15;
  bool _preWarningFired = false;
  bool _safetyIntentInProgress = false;

  final List<int> _durations = [5, 10, 15, 30, 60];

  bool get _isActive => _controller.isActive;
  bool get _isGrace => _controller.isGracePeriod;
  int get _remainingSeconds => _controller.remainingSeconds;
  bool get _nativeScheduleDegraded => _controller.nativeScheduleDegraded;
  int get _totalSeconds => _controller.totalSeconds > 0
      ? _controller.totalSeconds
      : _selectedMinutes * 60;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _maybeFirePreWarning();
    setState(() {});
  }

  void _maybeFirePreWarning() {
    if (!_controller.isActive || _controller.isGracePeriod) {
      return;
    }
    final remaining = _controller.remainingSeconds;
    final warningThreshold = _selectedMinutes >= 4
        ? 120
        : (_selectedMinutes * 60 * 0.1).round();
    if (!_preWarningFired && remaining <= warningThreshold && remaining > 0) {
      _preWarningFired = true;
      _firePreExpiryWarning();
    }
  }

  Future<void> _startSafeWalk() async {
    final currentContext = context;
    if (!await _hasEmergencyContact()) {
      if (!currentContext.mounted) return;
      _showTimerContactRequired(currentContext);
      return;
    }
    if (!currentContext.mounted) return;

    // İlk kullanımda uyarı dialogu göster
    final shown = await FeatureWarningHelper.showIfNeeded(
      currentContext,
      prefKey: AppConstants.prefWarningWalk,
      featureName: 'safe_walk',
      title: FeatureWarningHelper.checkinTitle,
      content: FeatureWarningHelper.checkinContent,
    );
    if (!shown || !currentContext.mounted) return;

    final notificationsAllowed =
        await PermissionHelper.requestNotificationPermission(currentContext);
    if (!currentContext.mounted) return;
    if (!notificationsAllowed) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('notification_session_permission_required'.tr()),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'open_notification_settings'.tr(),
            onPressed: () {
              PermissionHelper.openNotificationSettings();
            },
          ),
        ),
      );
      return;
    }

    final exactAlarmGranted = await requireExactAlarmPermission(currentContext);
    if (!exactAlarmGranted || !currentContext.mounted) return;

    final subscription = currentContext.read<SubscriptionProvider>();
    final accessFuture = subscription.resolveAccess();
    final pinStateFuture = PinVerificationService.instance.loadState();
    final access = await accessFuture;
    final pinState = await pinStateFuture;
    if (!currentContext.mounted) return;

    HapticFeedback.mediumImpact();
    _preWarningFired = false;
    final result = await _controller.startSession(
      minutes: _selectedMinutes,
      entitlementDecision: access.entitlementDecision,
      pinConfigured: pinState == PinState.configured,
    );
    if (!mounted) return;
    if (result is! Armed) {
      _showArmFailure(result, pinState);
    }
  }

  Future<bool> _hasEmergencyContact() async {
    try {
      final contact = await ContactService.getEmergencyContact();
      return contact != null &&
          EmergencyNumberValidator.isCallableEmergencyTarget(contact.phone);
    } catch (_) {
      return false;
    }
  }

  void _showTimerContactRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('timer_emergency_contact_required'.tr()),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'timer_add_contact_action'.tr(),
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ContactsPage()));
          },
        ),
      ),
    );
  }

  void _showArmFailure(ArmResult result, PinState pinState) {
    var messageKey = 'safety_session_not_ready';
    if (result is ArmUnknown) {
      messageKey = 'safety_session_arm_unknown';
    } else if (pinState == PinState.loading) {
      messageKey = 'pin_state_loading';
    } else if (pinState == PinState.absent) {
      messageKey = 'safety_session_pin_required';
    } else if (pinState == PinState.readFailed) {
      messageKey = 'pin_state_read_failed';
    } else if (result is ArmRejected &&
        (result.reasonCode == 'entitlementDenied' ||
            result.reasonCode == 'entitlementUnknown')) {
      messageKey = 'safety_session_entitlement_unverified';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messageKey.tr()),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCancelFailure(CancelResult? result) {
    final messageKey = result is SessionCancelTooLate
        ? 'emergency_cancel_too_late'
        : 'emergency_cancel_unconfirmed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messageKey.tr()),
        backgroundColor: AppColors.emergency,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Future<void> _markSafe() async {
    if (CheckInExpiryCoordinator.instance.isClaimedFor(
      CheckInExpiryCoordinator.safeWalkSession,
    )) {
      return;
    }
    if (!await _verifySafetyIntent()) return;
    HapticFeedback.lightImpact();
    final result = await _controller.stopSession();
    if (!mounted) return;
    if (result == null || !result.isConfirmedCancelled) {
      _showCancelFailure(result);
      return;
    }
    // Analytics removed (offline-first)
    try {
      await ActivityService.logEvent(
        type: ActivityType.safetyCheck,
        title: "safe_walk_completed_activity".tr(),
        description: "safe_walk_completed_desc".tr(),
      );
    } catch (_) {
      // The durable cancellation acknowledgement is authoritative; local
      // history is best-effort and must not turn a safe stop into a failure.
    }
    if (!mounted) return;

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

  Future<bool> _cancelWalk() async {
    if (CheckInExpiryCoordinator.instance.isClaimedFor(
      CheckInExpiryCoordinator.safeWalkSession,
    )) {
      return false;
    }
    if (!await _verifySafetyIntent()) return false;
    HapticFeedback.lightImpact();
    final result = await _controller.stopSession();
    if (!mounted) return result?.isConfirmedCancelled ?? false;
    if (result == null || !result.isConfirmedCancelled) {
      _showCancelFailure(result);
      return false;
    }
    return true;
  }

  Future<bool> _verifySafetyIntent() async {
    if (_safetyIntentInProgress) return false;
    _safetyIntentInProgress = true;
    try {
      return await SafetySessionPinGate.verify(context);
    } finally {
      _safetyIntentInProgress = false;
    }
  }

  String _formatTime(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
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
    return _buildScrollableContent(
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
                duration: Motion.base,
                curve: Motion.enter,
                child: AnimatedContainer(
                  duration: Motion.base,
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
    final progress = _remainingSeconds / _totalSeconds;
    final isUrgent = _isGrace || _remainingSeconds <= 30;

    return _buildScrollableContent(
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
        if (_nativeScheduleDegraded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'timer_scheduling_degraded'.tr(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _markSafe,
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

  Widget _buildScrollableContent({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: Column(children: children)),
          ),
        );
      },
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
            onPressed: () async {
              Navigator.pop(ctx);
              final cancelled = await _cancelWalk();
              if (!mounted) return;
              if (cancelled) Navigator.pop(context);
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
