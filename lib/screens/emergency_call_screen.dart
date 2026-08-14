// ============================================================================
// ACIL DURUM DURUM EKRANI — HONEST STATUS DISPLAY
// ============================================================================

import '../core/design_tokens.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_colors.dart';
import '../core/widgets/dispatch_outcome_list.dart';
import '../core/services/android_intent_service.dart';
import '../core/services/call_service.dart';
import '../core/services/dispatch_outcome.dart';
import '../core/services/foreground_service.dart';
import '../core/services/reduced_motion_policy.dart';

class EmergencyCallScreen extends StatefulWidget {
  final String name;
  final String phone;
  final EmergencyCallResult callResult;

  /// Per-target outcomes for the dispatch that produced [callResult].
  ///
  /// Null only for entry points that predate the ledger (none in the emergency
  /// path). When present and NOT uniformly successful, the per-target list is
  /// rendered: a dispatch where the call was handed off and the alert
  /// notification was suppressed must not read as plain success (MP-01-027).
  final DispatchOutcomeLedger? dispatchLedger;
  final String? emergencyMessage;
  final String? foregroundOwner;

  const EmergencyCallScreen({
    super.key,
    this.name = '',
    this.phone = '',
    required this.callResult,
    this.dispatchLedger,
    this.emergencyMessage,
    this.foregroundOwner,
  });

  @override
  State<EmergencyCallScreen> createState() => _EmergencyCallScreenState();
}

class _EmergencyCallScreenState extends State<EmergencyCallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _confirmedCallAutoDismissDelay = Duration(seconds: 12);

  late AnimationController _pulseController;
  Timer? _failSafeTimer;
  Timer? _autoDismissTimer;
  bool _failSafeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Keep the CPU/screen awake while the user resolves the emergency call.
    // Idempotent with any wakelock acquired by CountdownScreen; the matching
    // disable lives in dispose() so every entry path releases the lock.
    unawaited(
      WakelockPlus.enable().catchError((Object e) {
        debugPrint('EmergencyCallScreen: WakelockPlus.enable failed: $e');
      }),
    );

    // FAIL-SAFE TRUTH MODE: If nothing is confirmed after 5 seconds,
    // show fullscreen red alert.
    _scheduleFailSafe();
    _scheduleAutoDismiss();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded (e.g. Android honored a call/dialer request): release the
    // wakelock and stop the emergency
    // foreground service. That path has no auto-dismiss, so otherwise the
    // CPU/screen lock and the persistent "running" notification would linger
    // until the user manually returns home.
    if (state != AppLifecycleState.paused) return;
    unawaited(
      WakelockPlus.disable().catchError((Object e) {
        debugPrint('EmergencyCallScreen: lifecycle wakelock disable: $e');
      }),
    );
    unawaited(_releaseForegroundOwner());
  }

  void _scheduleFailSafe() {
    if (widget.callResult.isConfirmed) return;

    // Call requires user action or failed — trigger fail-safe after 5s
    _failSafeTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _failSafeShown) return;
      _failSafeShown = true;
      _showFailSafeAlert();
    });
  }

  void _scheduleAutoDismiss() {
    if (!widget.callResult.isConfirmed) return;

    _autoDismissTimer = Timer(_confirmedCallAutoDismissDelay, _returnHome);
  }

  Future<void> _returnHome() async {
    _autoDismissTimer?.cancel();
    await _releaseForegroundOwner();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showFailSafeAlert() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2C0000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: AppColors.emergency,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              // Screen heading (MP-12-017).
              Semantics(
                header: true,
                child: Text(
                  'failsafe_title'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'failsafe_body'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.phone.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.phone,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (widget.emergencyMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    widget.emergencyMessage!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (widget.phone.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await AndroidIntentService.openDialer(widget.phone);
                  },
                  icon: const Icon(Icons.call, size: IconSizes.action),
                  label: Text(
                    'emergency_manual_call_now'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (widget.emergencyMessage != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.emergencyMessage!),
                    );
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('emergency_message_copied'.tr()),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: IconSizes.listItem),
                  label: Text('emergency_copy_message'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'emergency_dismiss'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _releaseForegroundOwner() async {
    final owner = widget.foregroundOwner;
    if (owner == null || owner.isEmpty) return;
    await KoruBeniForegroundService.stop(owner: owner);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambient loops start HERE, not in initState: initState runs before
    // the MediaQuery is readable, so a controller started there has
    // already ignored the platform's reduce-motion preference by the time
    // anything can consult it. didChangeDependencies also re-runs when the
    // user toggles the setting, so the change takes effect without a
    // restart. ReducedMotionPolicy.pulse is idempotent by contract.
    ReducedMotionPolicy.pulse(
      _pulseController,
      reduced: ReducedMotionPolicy.isReduced(context),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _failSafeTimer?.cancel();
    _autoDismissTimer?.cancel();
    _pulseController.dispose();
    // Release the wakelock acquired here (and any inherited from the
    // CountdownScreen handoff). Idempotent: a no-op if already disabled.
    unawaited(
      WakelockPlus.disable().catchError((Object e) {
        debugPrint('EmergencyCallScreen: WakelockPlus.disable failed: $e');
      }),
    );
    unawaited(_releaseForegroundOwner());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callPresentation = _buildCallPresentation(widget.callResult);
    final requiresAttention = callPresentation.requiresAction;
    final hasFailure = callPresentation.isFailure;
    final callConfirmed = widget.callResult.isConfirmed;

    final headerPresentation = _buildHeaderPresentation(
      requiresAttention: requiresAttention,
      hasFailure: hasFailure,
      anythingConfirmed: callConfirmed,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1C1C1E), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1 + (_pulseController.value * 0.04),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[850],
                                boxShadow: [
                                  BoxShadow(
                                    color: headerPresentation.color.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 28,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 70,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              widget.name.isEmpty
                                  ? "pin_verify_emergency_contact".tr()
                                  : widget.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (widget.phone.isNotEmpty)
                              Text(
                                widget.phone,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildHeaderBanner(headerPresentation),
                      const SizedBox(height: 18),
                      _buildStatusCard(
                        title: 'emergency_status_call'.tr(),
                        presentation: callPresentation,
                      ),
                      ...DispatchOutcomeList.build(widget.dispatchLedger),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    Text(
                      "emergency_call_disclaimer".tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      button: true,
                      label: "emergency_call_end".tr(),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _returnHome,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.home_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "emergency_call_end".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(_StatusPresentation presentation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: presentation.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: presentation.color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(presentation.icon, color: presentation.color, size: IconSizes.action),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  presentation.detail,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required _StatusPresentation presentation,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: presentation.color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(presentation.icon, color: presentation.color, size: IconSizes.emphasis),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  presentation.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  presentation.detail,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusPresentation _buildHeaderPresentation({
    required bool requiresAttention,
    required bool hasFailure,
    required bool anythingConfirmed,
  }) {
    // If ANYTHING requires user action, header is WARNING — never green
    if (requiresAttention) {
      return _StatusPresentation(
        icon: Icons.touch_app_rounded,
        color: AppColors.warning,
        summary: 'emergency_flow_attention_title'.tr(),
        detail: 'emergency_flow_attention_body'.tr(),
        requiresAction: true,
      );
    }

    if (hasFailure) {
      return _StatusPresentation(
        icon: Icons.error_outline_rounded,
        color: AppColors.emergency,
        summary: 'emergency_flow_partial_title'.tr(),
        detail: 'emergency_flow_partial_body'.tr(),
      );
    }

    // Only show green if at least one action was CONFIRMED (not just "opened")
    if (anythingConfirmed) {
      return _StatusPresentation(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        summary: 'emergency_flow_confirmed_title'.tr(),
        detail: 'emergency_flow_confirmed_body'.tr(),
      );
    }

    // Fallback: nothing confirmed, nothing requires action, nothing failed
    // This shouldn't happen, but treat as warning
    return _StatusPresentation(
      icon: Icons.info_outline_rounded,
      color: AppColors.warning,
      summary: 'emergency_flow_attention_title'.tr(),
      detail: 'emergency_flow_attention_body'.tr(),
      requiresAction: true,
    );
  }

  _StatusPresentation _buildCallPresentation(EmergencyCallResult result) {
    switch (result.status) {
      case EmergencyCallStatus.callRequested:
        return _StatusPresentation(
          icon: Icons.phone_in_talk_rounded,
          color: AppColors.warning,
          summary: result.statusMessage,
          detail: 'emergency_call_requested_hint'.tr(),
          requiresAction: true,
        );
      case EmergencyCallStatus.dialerRequested:
        return _StatusPresentation(
          icon: Icons.touch_app_rounded,
          color: AppColors.warning,
          summary: result.statusMessage,
          detail: 'emergency_call_manual_hint'.tr(),
          requiresAction: true,
        );
      case EmergencyCallStatus.failed:
        return _StatusPresentation(
          icon: Icons.call_end_rounded,
          color: AppColors.emergency,
          summary: result.statusMessage,
          detail: 'emergency_call_failed_hint'.tr(),
          isFailure: true,
        );
    }
  }
}

class _StatusPresentation {
  final IconData icon;
  final Color color;
  final String summary;
  final String detail;
  final bool requiresAction;
  final bool isFailure;

  const _StatusPresentation({
    required this.icon,
    required this.color,
    required this.summary,
    required this.detail,
    this.requiresAction = false,
    this.isFailure = false,
  });
}
