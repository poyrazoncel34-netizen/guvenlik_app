// ============================================================================
// AYARLAR DETAY SAYFASI
// ============================================================================

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/constants/app_constants.dart';

class SettingsDetailPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const SettingsDetailPage({
    super.key,
    required this.title,
    required this.icon,
  });

  List<_DetailSection> _sectionsForTitle() {
    switch (title) {
      case "Uygulama Hakkında":
        return [
          const _DetailSection(
            heading: "Misyonumuz",
            body:
                "KoruBeni, kisisel guvenligi guclendirmek icin tasarlanmis bir acil durum platformudur. Amacimiz, "
                "kritik anlarda hizli aksiyon almanizi ve guven aginiza tek dokunusla ulasmanizi saglamaktir.",
          ),
          const _DetailSection(
            heading: "Temel Ozellikler",
            body:
                "• Panik Butonu: Basili tutarak acil cagrı baslatma\n"
                "• Acil Kisiler: 5 kisiye kadar acil kisi kaydi\n"
                "• Konum Paylasimi: Gercek zamanli konum paylasimi\n"
                "• Sahte Cagri: Guvenliginiz icin sahte arama simulasyonu\n"
                "• Siren: Yuksek sesli alarm\n"
                "• Hizli Mesaj: Tek dokunusla acil mesaj gonderimi\n"
                "• Guvenli Yuruyus: Zamanlayicili guvenlik kontrolu",
          ),
          const _DetailSection(
            heading: "Surum Bilgisi",
            body:
                "Surum: ${AppConstants.appVersion}\n"
                "Build: ${AppConstants.buildNumber}\n"
                "Platform: iOS & Android\n"
                "Gelistirici: KoruBeni Team",
          ),
          const _DetailSection(
            heading: "Sorumluluk",
            body:
                "Uygulama, acil durumlarda destekleyici bir aractir. Operator/kurum yanit sureleri ve iletisim "
                "altyapisi, uygulama kontrolu disindadir. Gercek tehlike durumlarinda 112, 155 veya 110 numaralarini "
                "dogrudan aramaniz onerilir.",
          ),
        ];
      case "Gizlilik Politikası":
        return const [
          _DetailSection(
            heading: "1. Genel Bakis",
            body:
                "KoruBeni olarak gizliliginize onem veriyoruz. Bu politika, uygulamamizi kullanirken "
                "toplanan, kullanilan ve korunan kisisel verileri aciklar. Uygulamayi kullanarak bu "
                "politikayi kabul etmis sayilirsiniz.",
          ),
          _DetailSection(
            heading: "2. Toplanan Veriler",
            body:
                "• Telefon Numarasi: Firebase Authentication ile giris icin\n"
                "• Konum Verileri: Acil durumlarda paylasim icin (izin ile)\n"
                "• Acil Kisi Bilgileri: Cihazda guvenli depolama ile saklanir\n"
                "• PIN Kodu: Sifrelenerek cihazda saklanir, sunucuya gonderilmez\n"
                "• Aktivite Gecmisi: Uygulama icindeki islemlerinizin yerel kaydi\n"
                "• Cihaz Bilgileri: Cokme raporlari icin (Firebase Crashlytics)",
          ),
          _DetailSection(
            heading: "3. Konum Kullanimi",
            body:
                "Konum verileri yalnizca asagidaki durumlarda kullanilir:\n"
                "• Acil durum butonuna basildiginda konum paylasimi\n"
                "• Kullanicinin konum paylasimini aktif etmesi durumunda\n"
                "• Harita gorunumunde mevcut konumun gosterilmesi\n\n"
                "Konum verileri arka planda toplanmaz. Konum paylasimini istediginiz zaman "
                "ayarlardan kapatabilirsiniz.",
          ),
          _DetailSection(
            heading: "4. Veri Guvenligi",
            body:
                "• Hassas veriler (PIN, acil kisiler) AES sifreleme ile korunur\n"
                "• Veriler cihazin guvenli depolama alaninda saklanir (iOS Keychain / Android Keystore)\n"
                "• Firebase iletisimi SSL/TLS ile sifrelidir\n"
                "• Sunucu tarafinda erisimsiz veriler duzeli olarak temizlenir",
          ),
          _DetailSection(
            heading: "5. Ucuncu Taraf Hizmetleri",
            body:
                "Uygulama asagidaki ucuncu taraf hizmetlerini kullanir:\n"
                "• Firebase Authentication: Kullanici kimlik dogrulamasi\n"
                "• Firebase Firestore: Acil durum kayitlari\n"
                "• Firebase Crashlytics: Uygulama cokme raporlari\n"
                "• Firebase Analytics: Anonim kullanim istatistikleri\n"
                "• Firebase Cloud Messaging: Bildirimler\n\n"
                "Bu hizmetlerin gizlilik politikalari icin Google'in gizlilik politikasina basvurun.",
          ),
          _DetailSection(
            heading: "6. Veri Saklama ve Silme",
            body:
                "• Yerel veriler: Uygulamayi silerseniz tum yerel veriler silinir\n"
                "• Sunucu verileri: Hesabinizi sildiginizde sunucu verileri 30 gun icinde silinir\n"
                "• Aktivite gecmisi: Yalnizca cihazda saklanir, maksimum 50 kayit\n"
                "• Cikmis yaptiginizda oturum verileri hemen silinir",
          ),
          _DetailSection(
            heading: "7. Kullanici Haklari",
            body:
                "Asagidaki haklara sahipsiniz:\n"
                "• Verilerinize erisim isteme\n"
                "• Verilerinizin duzeltilmesini isteme\n"
                "• Verilerinizin silinmesini isteme\n"
                "• Veri islemeye itiraz etme\n\n"
                "Bu haklarinizi kullanmak icin destek@korubeni.com adresine ulasabilirsiniz.",
          ),
          _DetailSection(
            heading: "8. Iletisim",
            body:
                "Gizlilik ile ilgili sorulariniz icin:\n"
                "E-posta: destek@korubeni.com\n\n"
                "Bu politika en son 7 Subat 2026 tarihinde guncellenmistir.",
          ),
        ];
      case "Yardım & Destek":
        return const [
          _DetailSection(
            heading: "Nasil Kullanilir?",
            body:
                "1. Acil Kisi Secin: Kisiler sekmesinden guvendiginiz kisileri ekleyin\n"
                "2. PIN Belirleyin: Ilk giriste otomatik olarak istenir\n"
                "3. Izinleri Verin: Konum ve rehber izinlerini aktif edin\n"
                "4. Panik Butonu: Ana sayfada butonu basili tutun, biraktiktan sonra geri sayim baslar\n"
                "5. PIN ile Iptal: Yanlis alarm ise 10 saniye icinde PIN girin",
          ),
          _DetailSection(
            heading: "Sik Sorulan Sorular",
            body:
                "S: PIN'imi unuttum, ne yapmaliyim?\n"
                "C: Cikis yapip tekrar giris yapin, yeni PIN olusturmaniz istenecektir.\n\n"
                "S: Konum paylasimi pil tuketiyor mu?\n"
                "C: Hayir, konum yalnizca aktif olarak paylastiginizda kullanilir. Arka planda calismaz.\n\n"
                "S: Sahte cagri gercek mi gorunuyor?\n"
                "C: Evet, gercek bir arama ekrani gibi gorunur. Istediginiz isim ve numarayi girebilirsiniz.\n\n"
                "S: Acil kisilerim bildirim aliyor mu?\n"
                "C: Panik butonu tetiklendiginde acil kisilerinize SMS gonderilir ve birincil kisi aranir.",
          ),
          _DetailSection(
            heading: "Destek Kanallari",
            body:
                "E-posta: destek@korubeni.com\n\n"
                "Teknik sorunlar, oneriler ve geri bildirimler icin destek ekibimize ulasabilirsiniz. "
                "Yanit suresi genellikle 24 saat icerisindedir.",
          ),
          _DetailSection(
            heading: "Acil Durum Notu",
            body:
                "Bu uygulama acil durumlarda yardimci bir aractir. Gercek bir tehlike durumunda:\n"
                "• 112 - Genel Acil Yardim\n"
                "• 155 - Polis\n"
                "• 110 - Itfaiye\n"
                "numaralarini dogrudan aramaniz onerilir.",
          ),
        ];
      default:
        return const [
          _DetailSection(
            heading: "Bilgilendirme",
            body:
                "Bu bolum, yakin zamanda ayrintili iceriklerle guncellenecektir. "
                "Geri bildirimlerinizi bizimle paylasabilirsiniz.",
          ),
        ];
    }
  }

  String _introForTitle() {
    switch (title) {
      case "Uygulama Hakkında":
        return "Kurumsal guvenlik yaklasimimiz ve urun vizyonumuz hakkinda genel bilgi.";
      case "Gizlilik Politikası":
        return "KVKK ve GDPR uyumlu kisisel verilerin korunmasi politikamiz.";
      case "Yardım & Destek":
        return "Kullanim rehberi, SSS ve destek kanallari.";
      default:
        return "Bu bolumle ilgili bilgilere buradan erisebilirsiniz.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sectionsForTitle();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _introForTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...sections.map(
            (section) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection {
  final String heading;
  final String body;

  const _DetailSection({required this.heading, required this.body});
}
