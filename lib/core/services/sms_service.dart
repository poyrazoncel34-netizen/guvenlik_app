import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for sending SMS.
///
/// On Android: uses native SmsManager via platform channel (background, no UI).
/// On iOS/Web: falls back to url_launcher (opens SMS composer, requires user tap).
class SmsService {
  static const _channel = MethodChannel('com.poyrazoncel.korubeni/sms');

  /// Send [message] to all [numbers].
  /// Returns null on success, or an error string on failure.
  static Future<String?> sendSms({
    required List<String> numbers,
    required String message,
  }) async {
    if (numbers.isEmpty) return 'No recipients';

    // Android: try native background sending first
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _sendNativeAndroid(numbers, message);
    }

    // iOS / Web: fall back to url_launcher
    return _sendViaLauncher(numbers, message);
  }

  static Future<String?> _sendNativeAndroid(
    List<String> numbers,
    String message,
  ) async {
    final List<String> failedNumbers = [];

    for (final number in numbers) {
      try {
        await _channel.invokeMethod('sendSms', {
          'phone': number,
          'message': message,
        });
      } on PlatformException catch (e) {
        if (e.code == 'NO_PERMISSION') {
          // Permission not granted — fall back to url_launcher for all
          return _sendViaLauncher(numbers, message);
        }
        failedNumbers.add(number);
      } catch (_) {
        failedNumbers.add(number);
      }
    }

    if (failedNumbers.isNotEmpty) {
      // Retry failed ones via url_launcher
      return _sendViaLauncher(failedNumbers, message);
    }

    return null; // success
  }

  static Future<String?> _sendViaLauncher(
    List<String> numbers,
    String message,
  ) async {
    for (final number in numbers) {
      final uri = Uri(
        scheme: 'sms',
        path: number,
        queryParameters: {'body': message},
      );
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Best-effort — continue to next number
      }
    }
    return null;
  }
}
