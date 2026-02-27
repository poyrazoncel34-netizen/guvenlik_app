import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for sending SMS.
///
/// Strateji:
/// 1. Android'de önce native SmsManager'ı dene (arka planda, UI olmadan).
/// 2. SEND_SMS izni yoksa veya gönderim başarısozsa, url_launcher ile
///    kullanıcının varsayılan SMS uygulamasını aç (mesaj+alıcı doldurulur).
/// 3. iOS/Web'de her zaman url_launcher kullan.
///
/// Bu sayede Google Play SEND_SMS iznini reddedse bile SMS gönderimi çalışır.
class SmsService {
  static const _channel = MethodChannel('com.poyrazoncel.korubeni/sms');

  /// Native SEND_SMS izni olup olmadığını tracking eder.
  /// İlk `NO_PERMISSION` hatasından sonra false olur ve bir daha native
  /// denenmez — gereksiz PlatformException overhead'ı engellenir.
  static bool _nativePermissionGranted = true;

  /// Send [message] to all [numbers].
  /// Returns null on success, or an error string on failure.
  static Future<String?> sendSms({
    required List<String> numbers,
    required String message,
  }) async {
    if (numbers.isEmpty) return 'No recipients';

    // Android: native arka plan gönderimi dene
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (_nativePermissionGranted) {
        final result = await _sendNativeAndroid(numbers, message);
        if (result == null) return null; // Başarılı
        // Native başarısız olduysa fallback'e devam et
        debugPrint('>>> SmsService: Native failed, falling back to launcher');
      }
      // Native izin yok veya başarısız → url_launcher fallback
      return _sendViaLauncher(numbers, message);
    }

    // iOS / Web: url_launcher
    return _sendViaLauncher(numbers, message);
  }

  /// Native Android SmsManager ile gönderim.
  /// Başarı: null, Hata: hata mesajı döner.
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
          // İzin kalıcı olarak reddedilmiş — bir daha deneme
          _nativePermissionGranted = false;
          debugPrint('>>> SmsService: SEND_SMS permission denied permanently');
          return 'NO_PERMISSION'; // Caller fallback'e geçecek
        }
        failedNumbers.add(number);
      } catch (e) {
        debugPrint('>>> SmsService native error: $e');
        failedNumbers.add(number);
      }
    }

    if (failedNumbers.isNotEmpty) {
      // Kısmen başarısız — başarısız olanları fallback ile gönder
      debugPrint('>>> SmsService: ${failedNumbers.length} failed, retrying via launcher');
      return _sendViaLauncher(failedNumbers, message);
    }

    return null; // Tüm SMS'ler başarılı
  }

  /// url_launcher ile SMS uygulamasını açarak gönderim.
  /// SEND_SMS izni gerektirmez — Google Play reddedse bile çalışır.
  /// Mesaj metni ve alıcı numarası otomatik doldurulur.
  static Future<String?> _sendViaLauncher(
    List<String> numbers,
    String message,
  ) async {
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

