// ============================================================================
// CHECK-IN EKRANI (KONTROL NOKTASI)
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/check_in_service.dart';
import '../core/services/contact_service.dart';
import '../core/utils/permission_helper.dart';
import '../core/widgets/exact_alarm_permission_guard.dart';
import '../core/widgets/feature_warning_dialog.dart';
import 'contacts_page.dart';
// Analytics service removed (offline-first)

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _staggerController;
  final CheckInService _service = CheckInService.instance;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _service.addListener(_onServiceChanged);
    _service.initialize();
    // Analytics removed (offline-first)
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _staggerController.dispose();
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<bool> _hasEmergencyContact() async {
    try {
      final numbers = await ContactService.getAllEmergencyNumbers();
      return numbers.any((number) => number.trim().isNotEmpty);
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

  void _showTimerSchedulingDegraded() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('timer_scheduling_degraded'.tr()),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startCheckIn(int minutes) async {
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
      prefKey: AppConstants.prefWarningCheckin,
      featureName: 'check_in',
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
          content: Text("notification_session_permission_required".tr()),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final exactAlarmAcknowledged = await confirmExactAlarmPermissionOrDegraded(
      currentContext,
    );
    if (!exactAlarmAcknowledged || !currentContext.mounted) return;

    HapticFeedback.mediumImpact();
    final fullyScheduled = await _service.start(minutes);
    if (!mounted) return;
    if (!fullyScheduled) {
      _showTimerSchedulingDegraded();
    }
  }

  Future<void> _confirmSafe() async {
    HapticFeedback.heavyImpact();
    await _service.confirmSafe();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text("check_in_safe_confirmed".tr())),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _stopCheckIn() async {
    HapticFeedback.lightImpact();
    await _service.stop();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("check_in_title".tr()),
        backgroundColor: AppColors.surface,
      ),
      body: _service.isActive ? _buildActiveView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 56,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "check_in_setup_title".tr(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "check_in_setup_desc".tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            "check_in_select_duration".tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              _buildAnimatedDuration(0, 15, "15 dk"),
              _buildAnimatedDuration(1, 30, "30 dk"),
              _buildAnimatedDuration(2, 60, "1 sa"),
              _buildAnimatedDuration(3, 120, "2 sa"),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    "check_in_warning".tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDuration(int index, int minutes, String label) {
    final start = (index * 0.15).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: _buildDurationOption(minutes, label),
      ),
    );
  }

  Widget _buildDurationOption(int minutes, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _startCheckIn(minutes),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView() {
    final isGrace = _service.isGracePeriod;
    final color = isGrace ? AppColors.emergency : AppColors.success;
    final progress = _service.totalSeconds > 0
        ? _service.remainingSeconds / (isGrace ? 60 : _service.totalSeconds)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (isGrace) ...[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emergency.withValues(
                      alpha: 0.1 + (_pulseController.value * 0.15),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.emergency.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.emergency,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "check_in_grace_warning".tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emergency,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (_service.nativeScheduleDegraded) ...[
            Container(
              width: double.infinity,
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
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Countdown circle
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _CheckInProgressPainter(
                progress: progress.clamp(0.0, 1.0),
                color: color,
                bgColor: color.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(_service.remainingSeconds),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGrace
                          ? "check_in_grace_label".tr()
                          : "check_in_remaining".tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Confirm Safe button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmSafe,
              icon: const Icon(Icons.check_circle_rounded, size: 24),
              label: Text(
                "check_in_im_safe".tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Cancel button
          TextButton.icon(
            onPressed: _stopCheckIn,
            icon: const Icon(Icons.close_rounded, size: 20),
            label: Text("check_in_cancel".tr()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: color, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isGrace
                        ? "check_in_grace_info".tr()
                        : "check_in_active_info".tr(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _CheckInProgressPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 10.0;

    // Background circle
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckInProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
