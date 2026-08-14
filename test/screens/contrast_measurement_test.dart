// MP-12-023 / MP-12-024 / MP-12-025 — contrast, MEASURED.
//
// The audit carried these as "contrast is unmeasured" across two sections. It
// is measurable without a device: WCAG relative luminance is a pure function of
// the sRGB values the app actually ships, and those live in AppColors.
//
// The focus-indicator ratio below was taken from RENDERED PIXELS on an API 36
// emulator (a focused Settings row vs its unfocused sibling after Tab
// traversal), not from the palette — because the focus highlight is a Material
// overlay, not a named colour.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/core/app_colors.dart';

/// WCAG 2.1 relative luminance.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel((c.r * 255).round() / 255) +
      0.7152 * channel((c.g * 255).round() / 255) +
      0.0722 * channel((c.b * 255).round() / 255);
}

double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('sanity: the formula reproduces the known extremes', () {
    // Harness precondition. Without this, a broken formula could report
    // everything as passing.
    expect(
      contrast(const Color(0xFFFFFFFF), const Color(0xFF000000)),
      closeTo(21.0, 0.01),
    );
    expect(
      contrast(const Color(0xFF808080), const Color(0xFF808080)),
      closeTo(1.0, 0.01),
    );
  });

  group('MP-12-023: text contrast meets WCAG AA (4.5:1)', () {
    final pairs = <String, List<Color>>{
      'textPrimary on background': [
        AppColors.textPrimary,
        AppColors.background,
      ],
      'textPrimary on cardBg': [AppColors.textPrimary, AppColors.cardBg],
      'textPrimary on surface': [AppColors.textPrimary, AppColors.surface],
      'textSecondary on background': [
        AppColors.textSecondary,
        AppColors.background,
      ],
      'textSecondary on cardBg': [AppColors.textSecondary, AppColors.cardBg],
      'textSecondary on surface': [AppColors.textSecondary, AppColors.surface],
    };
    pairs.forEach((label, colors) {
      test(label, () {
        final ratio = contrast(colors[0], colors[1]);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$label measured ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });
  });

  group('MP-12-024: interactive and status colours meet AA (3:1 non-text)', () {
    final pairs = <String, List<Color>>{
      'primary on background': [AppColors.primary, AppColors.background],
      'primary on cardBg': [AppColors.primary, AppColors.cardBg],
      'emergency on background': [AppColors.emergency, AppColors.background],
      'success on cardBg': [AppColors.success, AppColors.cardBg],
      'warning on cardBg': [AppColors.warning, AppColors.cardBg],
      'info on cardBg': [AppColors.info, AppColors.cardBg],
    };
    pairs.forEach((label, colors) {
      test(label, () {
        final ratio = contrast(colors[0], colors[1]);
        // These carry MEANING (armed, safe, attention), so they are held to the
        // text bar rather than the 3:1 non-text bar.
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$label measured ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });

    test('the decorative card border is deliberately below 3:1', () {
      // Recorded, not hidden. AppColors.border is 1.25:1 against cardBg. WCAG
      // 1.4.11 applies to visual information needed to IDENTIFY a control; the
      // cards here are identified by their fill, and the border is decoration.
      // Pinned so that if a border ever becomes the sole indicator of an
      // interactive boundary, this comment has to be revisited.
      final ratio = contrast(AppColors.border, AppColors.cardBg);
      expect(ratio, lessThan(3.0));
      expect(ratio, closeTo(1.25, 0.05));
    });
  });

  group('MP-12-025: focus indicator contrast — DÜZELTİLDİ', () {
    // TARİHSEL KAYIT (düzeltme öncesi, aynı emülatörde ölçüldü):
    // Ayarlar ekranında odaklı satır rgb(47,69,89), odaksız kardeşi
    // rgb(18,43,66). Bu ÇİFT, WCAG 2.2 SC 2.4.13 (Focus Appearance)
    // formülüdür — odaklı/odaksız aynı pikseller. Önceki tur bunu 1.4.11
    // diye etiketlemişti; 1.4.11 göstergeyi KOMŞU renklerle karşılaştırır.
    // Doğru ölçüm de geçmiyordu: komşulara karşı 1.46:1 ve 1.76:1.
    const oldFocusedRow = Color(0xFF2F4559);
    const oldUnfocusedRow = Color(0xFF122B42);
    const oldNeighbourAbove = Color(0xFF0A1B2A);

    test(
      'düzeltme öncesi değerler kayıt altında (her iki ölçüt de kalıyordu)',
      () {
        // SC 2.4.13 (odaklı vs odaksız)
        expect(contrast(oldFocusedRow, oldUnfocusedRow), closeTo(1.46, 0.05));
        // SC 1.4.11 (gösterge vs komşu) — asıl AA ölçütü
        expect(contrast(oldFocusedRow, oldNeighbourAbove), closeTo(1.76, 0.05));
      },
    );

    test('düzeltilmiş halka artık 1.4.11 barını geçiyor', () {
      // Render edilmiş piksellerden: dış halka primary, sayfa arka planına
      // komşu. Ayrıntılı ölçüm ve negatif kontroller:
      // test/screens/focus_ring_test.dart
      expect(
        contrast(AppColors.focusRing, AppColors.background),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        contrast(AppColors.focusRingOutline, const Color(0xFF4ED3FF)),
        greaterThanOrEqualTo(3.0),
      );
    });
  });
}
