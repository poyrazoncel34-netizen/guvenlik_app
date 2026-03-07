import 'package:flutter/foundation.dart' show debugPrint;
import 'package:url_launcher/url_launcher.dart';

/// Service for sending SMS.
///
/// Strateji:
/// 1. Varsayılan SMS uygulamasını aç.
/// 2. Alıcıları ve mesaj metnini mümkün olduğunca hazır doldur.
/// 3. Cihaz grup alıcı URI'sını desteklemiyorsa tek tek dene.
///
/// Bu yaklaşım restricted SMS izni gerektirmez ve Play Store ile daha uyumludur.
class SmsService {
  /// Send [message] to all [numbers].
  /// Returns null on success, or an error string on failure.
  static Future<String?> sendSms({
    required List<String> numbers,
    required String message,
  }) async {
    if (numbers.isEmpty) return 'No recipients';
    return _sendViaLauncher(numbers, message);
  }

  /// url_launcher ile SMS uygulamasını açarak gönderim.
  /// Mesaj metni ve alıcı numarası otomatik doldurulur.
  static Future<String?> _sendViaLauncher(
    List<String> numbers,
    String message,
  ) async {
    if (numbers.isEmpty) return 'No recipients';

    final groupedLaunched = await _tryLaunchGroupedSmsUri(numbers, message);
    if (groupedLaunched) return null;

    int successCount = 0;

    for (final number in numbers) {
      // Birden fazla URI formatı dene — cihaz uyumluluğu için
      final launched = await _tryLaunchSmsUri(number, message);
      if (launched) successCount++;
    }

    if (successCount == 0 && numbers.isNotEmpty) {
      return 'SMS uygulaması açılamadı';
    }
    return null;
  }

  static Future<bool> _tryLaunchGroupedSmsUri(
    List<String> numbers,
    String message,
  ) async {
    final recipients = numbers.join(',');

    try {
      final uri1 = Uri(
        scheme: 'sms',
        path: recipients,
        queryParameters: {'body': message},
      );
      if (await launchUrl(uri1, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    try {
      final uri2 = Uri.parse(
        'sms:$recipients?body=${Uri.encodeComponent(message)}',
      );
      if (await launchUrl(uri2, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    try {
      final semicolonRecipients = numbers.join(';');
      final uri3 = Uri.parse(
        'sms:$semicolonRecipients?body=${Uri.encodeComponent(message)}',
      );
      if (await launchUrl(uri3, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    debugPrint('>>> SmsService: Grouped SMS URI failed, trying individual launch');
    return false;
  }

  /// Tek bir numara için SMS URI'sını aç. Başarılıysa true döner.
  static Future<bool> _tryLaunchSmsUri(String number, String message) async {
    // Format 1: sms:+905xx?body=...  (Android için en yaygın)
    try {
      final uri1 = Uri(
        scheme: 'sms',
        path: number,
        queryParameters: {'body': message},
      );
      if (await launchUrl(uri1, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    // Format 2: sms:+905xx&body=... (bazı Samsung/Xiaomi cihazlar)
    try {
      final uri2 = Uri.parse('sms:$number?body=${Uri.encodeComponent(message)}');
      if (await launchUrl(uri2, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    // Format 3: Sadece SMS uygulamasını numara ile aç (mesaj olmadan)
    try {
      final uri3 = Uri(scheme: 'sms', path: number);
      if (await launchUrl(uri3, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    debugPrint('>>> SmsService: All URI formats failed for $number');
    return false;
  }
}
