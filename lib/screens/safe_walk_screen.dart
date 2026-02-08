// ============================================================================
// GUVENLI YURUYUS EKRANI
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/services/activity_service.dart';
import '../core/services/analytics_service.dart';
import '../domain/models/activity_event.dart';
import 'countdown_screen.dart';

class SafeWalkScreen extends StatefulWidget {
  const SafeWalkScreen({super.key});

  @override
  State<SafeWalkScreen> createState() => _SafeWalkScreenState();
}

class _SafeWalkScreenState extends State<SafeWalkScreen> {
  int _selectedMinutes = 15;
  bool _isActive = false;
  Timer? _timer;
  DateTime? _endTime;
  int _remainingSeconds = 0;

  final List<int> _durations = [5, 10, 15, 30, 60];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSafeWalk() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isActive = true;
      _endTime = DateTime.now().add(Duration(minutes: _selectedMinutes));
      _remainingSeconds = _selectedMinutes * 60;
    });

    AnalyticsService.logSafeWalkStarted(minutes: _selectedMinutes);
    ActivityService.logEvent(
      type: ActivityType.locationShared,
      title: "Guvenli Yuruyus Basladi",
      description: "$_selectedMinutes dakikalik guvenli yuruyus aktif",
    );

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
      }
    });
  }

  void _onTimerExpired() {
    // Timer expired without user checking in - trigger emergency
    HapticFeedback.heavyImpact();
    setState(() {
      _isActive = false;
      _timer?.cancel();
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CountdownScreen()),
    );
  }

  void _checkIn() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    AnalyticsService.logSafeWalkCompleted();
    ActivityService.logEvent(
      type: ActivityType.safetyCheck,
      title: "Guvenli Yuruyus Tamamlandi",
      description: "Guvenli sekilde hedefe ulastiniz",
    );

    setState(() {
      _isActive = false;
      _endTime = null;
      _remainingSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              "Guvende oldugunuz kaydedildi!",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _cancelWalk() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _isActive = false;
      _endTime = null;
      _remainingSeconds = 0;
    });
  }

  String _formatTime(int totalSeconds) {
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Guvenli Yuruyus"),
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
              const Text(
                "Guvenli Yuruyus",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Bir zamanlayici baslatin. Sure doldugunuzda\n'Guvendeyim' butonuna basmazsiniz, otomatik\nolarak acil kisilerinize bildirim gonderilir.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Sure Secin",
            style: TextStyle(
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
              child: Container(
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
                ),
                child: Text(
                  "$min dk",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
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
            label: const Text(
              "Yuruyuse Basla",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                backgroundColor: AppColors.border,
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
                  isUrgent ? "Acele edin!" : "Kalan sure",
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
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.emergency),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Sure dolmak uzere! 'Guvendeyim' butonuna basin.",
                    style: TextStyle(
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
            label: const Text(
              "Guvendeyim",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
          child: const Text(
            "Iptal Et",
            style: TextStyle(
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
        title: const Text(
          "Dikkat",
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          "Guvenli yuruyus aktif. Cikarsiniz geri sayim devam eder ve sure dolunca acil durum tetiklenir.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kal"),
          ),
          TextButton(
            onPressed: () {
              _cancelWalk();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              "Iptal Et ve Cik",
              style: TextStyle(color: AppColors.emergency),
            ),
          ),
        ],
      ),
    );
  }
}
