// ============================================================================
// RENK PALETİ – Premium Glassmorphism + Gradient desteği
// ============================================================================

import 'package:flutter/material.dart';

class AppColors {
  // Noonlight benzeri derin mavi + camgöbeği palet
  static const Color primary = Color(0xFF2EC5FF);
  static const Color primaryDark = Color(0xFF0F6AA3);
  static const Color primaryLight = Color(0xFF74E4FF);
  static const Color accent = Color(0xFF16E0C4);

  static const Color emergency = Color(0xFFFF4D4D);
  static const Color success = Color(0xFF2CB5A0); // WCAG color-blind safe teal
  static const Color warning = Color(0xFFFFB547);
  static const Color info = Color(0xFF4C8DFF);

  static const Color background = Color(0xFF0A1B2A);
  static const Color surface = Color(0xFF10263A);
  static const Color cardBg = Color(0xFF122B42);
  static const Color textPrimary = Color(0xFFF3F7FF);
  static const Color textSecondary = Color(0xFF9BB0C7);
  static const Color border = Color(0xFF1D3B54);

  /// The text input's IDENTIFYING boundary (WCAG 2.1 SC 1.4.11, bar 3:1).
  ///
  /// Split from [border] on purpose -- KARAR D-10 (2026-08-20). One token used
  /// to serve two roles that pull in opposite directions, and the conflict is
  /// provable rather than a matter of taste:
  ///   * SC 1.4.11 wants the input boundary LIGHT enough to clear 3:1 against
  ///     [background], which requires relative luminance >= 0.1305;
  ///   * [focusRing] (= [primary], L = 0.4773) has to stay 3:1 clear of the
  ///     surfaces it sits beside, and [border] is one of them
  ///     (test/screens/focus_ring_test.dart), which caps that tone at <= 0.1258.
  /// 0.1305 > 0.1258, so NO colour of any hue satisfies both. Lightening
  /// [border] would have bought SC 1.4.11 by breaking the focus indicator.
  ///
  /// Splitting the token removes the contradiction instead of trading one
  /// failure for another: [border] keeps its dark tone next to focus rings, and
  /// inputs get a boundary that actually identifies them (3.60:1 against
  /// [background]). Used ONLY by InputDecorationTheme.
  static const Color inputBorder = Color(0xFF3A76A8);
  static const Color shadow = Color(0x40000000);

  /// Shadow for surfaces floating over photographic map tiles, where the token
  /// grey reads too heavy. Measured from the value map_page.dart already
  /// shipped: black at 18% (0x2E), against `shadow`'s 25%.
  static const Color shadowOverlay = Color(0x2E000000);

  // Glassmorphism renkler
  static const Color glass = Color(0x1AFFFFFF);
  static const Color glassLight = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // Gradient başlangıç/bitiş
  static const Color gradientStart = Color(0xFF0D2137);
  static const Color gradientEnd = Color(0xFF0A1B2A);

  // Card hover/pressed
  static const Color cardHover = Color(0xFF163350);

  // Odak göstergesi (WCAG 1.4.11 / 2.4.13). İKİ TONLU olmasının sebebi ölçüm:
  // primary koyu yüzeylerde 7.27:1 veriyor ama parlak camgöbeği profil kartında
  // 1.17:1'e düşüyor; background ise tam tersi (kartta 10.24:1, koyu yüzeyde
  // 1.21:1). Tek renkli bir halka bu uygulamanın yüzeylerinin tamamını
  // geçemiyor, iki tonlu halkada her yüzeyde en az biri 3:1 barını aşıyor.
  static const Color focusRing = primary;
  static const Color focusRingOutline = background;

  // Shimmer renkleri
  static const Color shimmerBase = Color(0xFF1A3550);
  static const Color shimmerHighlight = Color(0xFF2A5070);
}
