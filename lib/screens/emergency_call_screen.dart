// ============================================================================
// ACIL DURUM DURUM EKRANI — HONEST STATUS DISPLAY
// ============================================================================

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/services/android_intent_service.dart';
import '../core/services/call_service.dart';
import '../core/services/foreground_service.dart';
import '../core/services/sms_service.dart';

class EmergencyCallScreen extends StatefulWidget {
  final String name;
  final String phone;
  final EmergencyCallResult callResult;
  final SmsComposeResult? smsResult;
  final String? locationStatusMessage;
  final String? emergencyMessage;

  const EmergencyCallScreen({
    super.key,
    this.name = '',
    this.phone = '',
    required this.callResult,
    this.smsResult,
    this.locationStatusMessage,
    this.emergencyMessage,
  });

  @override
  State<EmergencyCallScreen> createState() => _EmergencyCallScreenState();
}

class _EmergencyCallScreenState extends State<EmergencyCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _failSafeShown = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    // FAIL-SAFE TRUTH MODE: If nothing is confirmed after 5 seconds,
    // show fullscreen red alert.
    _scheduleFailSafe();
  }

  void _scheduleFailSafe() {
    final smsConfirmed = widget.smsResult?.isConfirmed ?? false;
    final callConfirmed = widget.callResult.isConfirmed;

    // If at least one action is confirmed (direct call placed or native SMS sent), no fail-safe needed
    if (smsConfirmed || callConfirmed) return;

    // Everything requires user action or failed — trigger fail-safe after 5s
    Timer(const Duration(seconds: 5), () {
      if (!mounted || _failSafeShown) return;
      _failSafeShown = true;
      _showFailSafeAlert();
    });
  }

  Future<void> _showFailSafeAlert() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2C0000),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.warning_rounded, color: AppColors.emergency, size: 42),
              ),
              const SizedBox(height: 16),
              Text(
                'failsafe_title'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'failsafe_body'.tr(),
                style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
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
                    style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
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
                  icon: const Icon(Icons.call, size: 20),
                  label: Text('emergency_manual_call_now'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (widget.emergencyMessage != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.emergencyMessage!));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('emergency_message_copied'.tr()), backgroundColor: AppColors.success),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('emergency_copy_message'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('emergency_dismiss'.tr(),
                    style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callPresentation = _buildCallPresentation(widget.callResult);
    final smsPresentation = widget.smsResult == null
        ? null
        : _buildSmsPresentation(widget.smsResult!);
    final requiresAttention =
        callPresentation.requiresAction ||
        (smsPresentation?.requiresAction ?? false);
    final hasFailure =
        callPresentation.isFailure || (smsPresentation?.isFailure ?? false);

    // Determine if anything was actually confirmed (no user action needed)
    final smsConfirmed = widget.smsResult?.isConfirmed ?? false;
    final callConfirmed = widget.callResult.isConfirmed;
    final anythingConfirmed = smsConfirmed || callConfirmed;

    final headerPresentation = _buildHeaderPresentation(
      requiresAttention: requiresAttention,
      hasFailure: hasFailure,
      anythingConfirmed: anythingConfirmed,
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
                      if (smsPresentation != null) ...[
                        const SizedBox(height: 14),
                        _buildStatusCard(
                          title: 'emergency_status_message'.tr(),
                          presentation: smsPresentation,
                        ),
                      ],
                      if (widget.locationStatusMessage != null &&
                          widget.locationStatusMessage!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildLocationCard(widget.locationStatusMessage!),
                      ],
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
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await KoruBeniForegroundService.stop();
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            color: AppColors.emergency,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 34,
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
            child: Icon(presentation.icon, color: presentation.color, size: 20),
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
            child: Icon(presentation.icon, color: presentation.color, size: 22),
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

  Widget _buildLocationCard(String locationStatusMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.info,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${'emergency_location_label'.tr()}: $locationStatusMessage',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
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
      case EmergencyCallStatus.directCallStarted:
        return _StatusPresentation(
          icon: Icons.phone_forwarded_rounded,
          color: AppColors.success,
          summary: result.statusMessage,
          detail: 'emergency_call_started_hint'.tr(),
        );
      case EmergencyCallStatus.dialerOpened:
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

  _StatusPresentation _buildSmsPresentation(SmsComposeResult result) {
    switch (result.status) {
      case SmsComposeStatus.nativeDispatched:
        return _StatusPresentation(
          icon: Icons.sms_rounded,
          color: AppColors.success,
          summary: result.statusMessage,
          detail: 'sms_native_dispatched_hint'.tr(),
        );
      case SmsComposeStatus.composerOpened:
        return _StatusPresentation(
          icon: Icons.touch_app_rounded,
          color: AppColors.warning,
          summary: result.statusMessage,
          detail: 'emergency_sms_manual_hint'.tr(),
          requiresAction: true,
        );
      case SmsComposeStatus.composerOpenedPrimaryOnly:
        return _StatusPresentation(
          icon: Icons.content_copy_rounded,
          color: AppColors.warning,
          summary: result.statusMessage,
          detail: 'emergency_sms_partial_hint'.tr(),
          requiresAction: true,
        );
      case SmsComposeStatus.failed:
        return _StatusPresentation(
          icon: Icons.sms_failed_rounded,
          color: AppColors.emergency,
          summary: result.statusMessage,
          detail: 'emergency_sms_failed_hint'.tr(),
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
