import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AndroidIntentService {
  AndroidIntentService._();

  static const MethodChannel _channel = MethodChannel(
    'com.poyrazoncel.korubeni/android_intents',
  );

  static String normalizePhoneNumber(String raw) {
    return raw.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
  }

  static Future<bool> composeSms({
    required List<String> recipients,
    required String message,
  }) async {
    final numbers = recipients
        .map(normalizePhoneNumber)
        .where((number) => number.isNotEmpty)
        .toList(growable: false);

    if (numbers.isEmpty) {
      return false;
    }

    if (Platform.isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>('composeSms', {
          'numbers': numbers,
          'message': message,
        });
        if (opened == true) {
          return true;
        }
      } on PlatformException {
        // Fallback handled below.
      }
    }

    final joined = numbers.join(',');
    final uri = Uri(
      scheme: 'sms',
      path: joined,
      queryParameters: {'body': message},
    );

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openDialer(String number) async {
    final normalized = normalizePhoneNumber(number);
    if (normalized.isEmpty) {
      return false;
    }

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
