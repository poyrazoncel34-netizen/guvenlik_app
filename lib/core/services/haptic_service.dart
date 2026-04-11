// ============================================================================
// HAPTIC FEEDBACK SERVİSİ
// ============================================================================
// Kullanıcı ekranı göremese bile fiziksel geri bildirim almasını sağlar.
// Acil durum akışının her adımında farklı titreşim pattern'leri kullanılır.
// ============================================================================

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

/// Merkezi haptic/titreşim servisi.
/// Farklı acil durum durumları için özelleştirilmiş titreşim pattern'leri sağlar.
class HapticService {
  HapticService._();

  static bool _hasVibrator = false;
  static bool _hasAmplitudeControl = false;
  static bool _initialized = false;

  /// Cihazın vibrasyon yeteneklerini kontrol et (app başlangıcında çağır).
  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      final vibrator = await Vibration.hasVibrator();
      _hasVibrator = vibrator == true;
      final amplitude = await Vibration.hasAmplitudeControl();
      _hasAmplitudeControl = amplitude == true;
      _initialized = true;
      debugPrint(
        '>>> HapticService: vibrator=$_hasVibrator, amplitude=$_hasAmplitudeControl',
      );
    } catch (e) {
      debugPrint('>>> HapticService init failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 1. VOLUME PANIC TRIGGER — çok belirgin, kullanıcı hissedecek
  // ─────────────────────────────────────────────────────────────────
  /// Ses tuşu ile panik tetiklendiğinde çağrılır.
  /// 3 kısa güçlü titreşim: ••• (kullanıcıya "algıladım" hissi verir)
  static Future<void> volumePanicTrigger() async {
    if (!_hasVibrator) {
      await HapticFeedback.heavyImpact();
      return;
    }
    try {
      if (_hasAmplitudeControl) {
        // Güçlü 3'lü titreşim pattern: vib-bek-vib-bek-vib
        await Vibration.vibrate(
          pattern: [0, 120, 80, 120, 80, 120],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      } else {
        await Vibration.vibrate(pattern: [0, 120, 80, 120, 80, 120]);
      }
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. COUNTDOWN TICK — her saniyede hafif tıklama hissi
  // ─────────────────────────────────────────────────────────────────
  /// Geri sayımın her saniyesinde çağrılır.
  /// Son 5 saniyede yoğunluk artar.
  static Future<void> countdownTick({required int secondsRemaining}) async {
    if (secondsRemaining <= 3) {
      // Son 3 saniye: güçlü ve uzun
      if (_hasVibrator) {
        try {
          await Vibration.vibrate(
            duration: 80,
            amplitude: _hasAmplitudeControl ? 200 : -1,
          );
        } catch (_) {
          await HapticFeedback.heavyImpact();
        }
      } else {
        await HapticFeedback.heavyImpact();
      }
    } else if (secondsRemaining <= 5) {
      // 4-5 saniye: orta
      await HapticFeedback.mediumImpact();
    } else {
      // 6-10 saniye: hafif
      await HapticFeedback.lightImpact();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. EMERGENCY TRIGGERED — alarm başlatıldığında uzun uyarı
  // ─────────────────────────────────────────────────────────────────
  /// Acil arama akışı başlatıldığında çağrılır.
  static Future<void> emergencyTriggered() async {
    if (!_hasVibrator) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      return;
    }
    try {
      if (_hasAmplitudeControl) {
        // Uzun-kısa-uzun pattern (SOS hissi)
        await Vibration.vibrate(
          pattern: [0, 400, 150, 150, 100, 150, 100, 400],
          intensities: [0, 255, 0, 200, 0, 200, 0, 255],
        );
      } else {
        await Vibration.vibrate(
          pattern: [0, 400, 150, 150, 100, 150, 100, 400],
        );
      }
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 4. EMERGENCY CANCELLED — iptal onayı
  // ─────────────────────────────────────────────────────────────────
  /// Alarm iptal edildiğinde hafif onay titreşimi.
  static Future<void> emergencyCancelled() async {
    if (_hasVibrator) {
      try {
        await Vibration.vibrate(
          duration: 50,
          amplitude: _hasAmplitudeControl ? 100 : -1,
        );
      } catch (_) {
        await HapticFeedback.lightImpact();
      }
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 5. WARNING — uyarı titreşimi (genel amaçlı)
  // ─────────────────────────────────────────────────────────────────
  /// Uyarı durumlarında (timeout yaklaşıyor vb.) çağrılır.
  static Future<void> warning() async {
    if (_hasVibrator) {
      try {
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200],
          intensities: _hasAmplitudeControl ? [0, 180, 0, 180] : [],
        );
      } catch (_) {
        await HapticFeedback.mediumImpact();
      }
    } else {
      await HapticFeedback.mediumImpact();
    }
  }
}
