// ============================================================================
// SİREN DİYALOGU - 🔊 GERÇEK SES ENTEGRASYONU
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_colors.dart';
import '../core/services/activity_service.dart';
import '../domain/models/activity_event.dart';

class SirenDialog extends StatefulWidget {
  const SirenDialog({super.key});

  @override
  State<SirenDialog> createState() => _SirenDialogState();
}

class _SirenDialogState extends State<SirenDialog> with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _scaleController;
  Timer? _soundTimer;
  int _duration = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startSirenSound();

    _soundTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      HapticFeedback.heavyImpact();
      setState(() => _duration++);
    });
  }

  Future<void> _startSirenSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Reuse ringtone asset as siren to avoid missing file errors
      await _audioPlayer.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      debugPrint("Ses çalma hatası: $e");
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    _scaleController.dispose();
    _soundTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: _colorController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppColors.emergency,
                  AppColors.warning,
                  _colorController.value,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      AppColors.emergency,
                      AppColors.warning,
                      _colorController.value,
                    )!.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_scaleController.value * 0.2),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.volume_up_rounded, size: 60, color: Colors.white),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "🚨 SİREN AKTİF 🚨",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "YÜKSEK SESLİ ALARM ÇALIYOR",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$_duration saniye",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ActivityService.logEvent(
                          type: ActivityType.sirenUsed,
                          title: "Siren Kullanildi",
                          description: "Siren $_duration saniye aktif kaldi",
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.emergency,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        "SİRENİ DURDUR",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
