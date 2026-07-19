import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AndroidIntentService {
  AndroidIntentService._();

  static const MethodChannel _channel = MethodChannel(
    'com.poyrazoncel.korubeni/android_intents',
  );

  static String normalizePhoneNumber(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.startsWith('+')) {
      return '+${normalized.substring(1).replaceAll('+', '')}';
    }
    return normalized.replaceAll('+', '');
  }

  /// Returns one canonical callable target, or null when [raw] contains URI
  /// syntax, dial-string commands, extensions, control characters, Unicode
  /// numerals, a misplaced `+`, or a non-phone length.
  static String? normalizedCallableOrNull(String raw) {
    var sawDigit = false;
    var sawPlus = false;
    const safeFormatting = <String>{' ', '-', '(', ')', '.'};

    for (final rune in raw.runes) {
      final character = String.fromCharCode(rune);
      final isAsciiDigit = rune >= 0x30 && rune <= 0x39;
      if (isAsciiDigit) {
        sawDigit = true;
      } else if (character == '+') {
        if (sawDigit || sawPlus) return null;
        sawPlus = true;
      } else if (!safeFormatting.contains(character)) {
        return null;
      }
    }

    final normalized = normalizePhoneNumber(raw);
    final digits = normalized.startsWith('+')
        ? normalized.substring(1)
        : normalized;
    if (digits.length < 7 || digits.length > 15) return null;
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return null;
    return normalized;
  }

  static Future<bool> openDialer(String number) async {
    final normalized = normalizedCallableOrNull(number);
    if (normalized == null) return false;

    if (Platform.isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>('openDialer', {
          'number': normalized,
        });
        if (opened == true) {
          return true;
        }
      } on PlatformException {
        // Fallback handled below.
      }
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
