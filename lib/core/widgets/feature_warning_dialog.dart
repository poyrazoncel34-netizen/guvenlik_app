// ============================================================================
// ÖZELLİK UYARI DİALOGU — KVKK Md. 5: Veri işleme öncesi bildirim
// İlk kullanımda bir kez gösterilir; SharedPreferences flag ile kontrol edilir.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../services/legal_log_service.dart';

class FeatureWarningHelper {
  FeatureWarningHelper._();

  /// Özelliğin ilk kullanımında uyarı dialogu gösterir.
  /// [prefKey]: SharedPreferences flag key (AppConstants.prefWarning*)
  /// [featureName]: Log kaydı için teknik isim (örn. 'panic_button')
  /// [title]: Dialog başlığı
  /// [content]: Dialog içeriği
  ///
  /// Dönüş değeri: Kullanıcı "Anladım" deyip dialog kapatıldıysa `true`,
  /// dialog gösterilmeden geçildiyse (flag zaten true) `true`,
  /// dialog açıkken uygulama mount'tan çıktıysa `false`.
  static Future<bool> showIfNeeded(
    BuildContext context, {
    required String prefKey,
    required String featureName,
    required String title,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(prefKey) ?? false;
    if (alreadyShown) return true;

    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FeatureWarningDialog(
        title: title,
        content: content,
        onAccepted: () async {
          await prefs.setBool(prefKey, true);
          await LegalLogService.instance.logEvent(
            'warning_shown_and_accepted',
            feature: featureName,
          );
        },
      ),
    );

    return true;
  }

  // ── Hazır içerikler ──────────────────────────────────────────────────────

  static const String panicTitle = '🚨 Panik Butonu — Bilgilendirme';
  static const String panicContent =
      'Bu özellik GERÇEK ACİL DURUMLARDA kullanılmak için tasarlanmıştır.\n\n'
      'Nasıl çalışır:\n'
      '• Butonu basılı tut → bırak → PIN girmezsen acil kişilerine SMS gider\n'
      '• SMS; internet bağlantısı ve operatör altyapısına bağlıdır\n'
      '• Yanlışlıkla tetiklenirse acil kişilerin gereksiz uyarılmasından sen sorumlusun\n\n'
      '⚠️ Bu uygulama 112\'nin YERİNİ TUTMAZ.\n'
      'Gerçek tehlikede önce 112\'yi ara.';

  static const String checkinTitle = '🚶 Check-in Zamanlayıcı — Bilgilendirme';
  static const String checkinContent =
      'Bu özellik fiziksel koruma SAĞLAMAZ.\n'
      'Yalnızca belirlediğin kişilere otomatik bildirim göndermeye yardımcı olur.\n\n'
      '• Çalışması internet ve GPS bağlantısına bağlıdır\n'
      '• Bildirimler SMS ile gönderilir; operatör gecikmesi yaşanabilir\n'
      '• Fiziksel güvenliğin için her zaman resmi acil servisleri kullan';

  static const String sirenTitle = '🔊 Alarm Sireni — Bilgilendirme';
  static const String sirenContent =
      'Yüksek sesli alarm çalmadan önce şunu bil:\n\n'
      '• Kamuya açık alanlarda kullanımda yerel gürültü yönetmeliği geçerlidir\n'
      '• Gereksiz kullanım çevre sakinlerini rahatsız edebilir\n'
      '• Bu özellikten doğacak şikayetler kullanıcının sorumluluğundadır';

  static const String locationTitle = '📍 Konum Paylaşımı — Bilgilendirme';
  static const String locationContent =
      'Konum bilginiz seçtiğiniz kişilere SMS ile gönderilecektir.\n\n'
      '• GPS doğruluğu cihaz ve çevre koşullarına bağlıdır; geliştirici garanti vermez\n'
      '• Konum bilginizi kiminle paylaştığınız sizin sorumluluğunuzdadır\n'
      '• Konum bilgisinin yetersiz, hatalı veya gecikmeli olmasından geliştirici sorumlu tutulamaz\n'
      '• Konum paylaşımından doğan sonuçların tüm sorumluluğu kullanıcıya aittir\n\n'
      '⚠️ Gerçek acil durumda mutlaka 112\'yi arayın.';

}

class _FeatureWarningDialog extends StatelessWidget {
  final String title;
  final String content;
  final Future<void> Function() onAccepted;

  const _FeatureWarningDialog({
    required this.title,
    required this.content,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await onAccepted();
              if (context.mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Anladım, devam et',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
