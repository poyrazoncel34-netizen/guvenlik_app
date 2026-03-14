// ============================================================================
// YASAL BİLGİLER VE GİZLİLİK - Offline Privacy Policy & Terms of Service
// ============================================================================

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Yasal Bilgiler ve Gizlilik',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'KVKK AYDINLATMA METNİ (6698 Sayılı Kanun Md. 10)',
              body:
                  'VERİ SORUMLUSU\n'
                  'Poyraz Öncel — destek@korubeni.com\n\n'
                  'İŞLEDİĞİMİZ VERİLER VE AMAÇLARI\n'
                  '• Acil kişi bilgileri (ad, telefon): Acil durum SMS gönderimi için.\n'
                  '• Konum verisi: Acil durum SMS mesajına koordinat eklenmesi için.\n'
                  '• PIN / Biyometrik veri: Uygulama kilidi (yalnızca cihazda işlenir, dışarı çıkmaz).\n'
                  '• Sağlık verisi (kan grubu, alerji): Profil kartı oluşturma için.\n'
                  '• Ses kaydı: Kullanıcı tarafından başlatılan kanıt kaydı için.\n\n'
                  'İŞLEMENİN HUKUKİ DAYANAĞI\n'
                  'İlgili kişinin açık rızası (KVKK Md. 5/1, Md. 6/2). '
                  'Tüm veriler YALNIZCA cihazınızda saklanır; hiçbir sunucuya gönderilmez, '
                  'hiçbir üçüncü tarafla paylaşılmaz.\n\n'
                  'İLGİLİ KİŞİ HAKLARI (KVKK Md. 11)\n'
                  'Verilerinizin işlenip işlenmediğini öğrenme, hatalı verilerin düzeltilmesini '
                  'talep etme ve uygulamayı silerek tüm verilerinizi kalıcı olarak kaldırma '
                  'haklarına sahipsiniz. Talepler için: destek@korubeni.com',
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'GİZLİLİK POLİTİKASI',
              body:
                  'KoruBeni, %100 çevrimdışı (offline) çalışan bir uygulamadır. Hiçbir kişisel veriniz '
                  '(konum, telefon numaraları, PIN, aktivite geçmişi) uygulama dışına çıkmaz, hiçbir sunucuya '
                  'gönderilmez ve üçüncü taraflarla paylaşılmaz.\n\n'
                  'Uygulama yalnızca şu izinleri kullanır:\n'
                  '• Kamera/Mikrofon: Sahte arama özelliği için (veriler kaydedilmez).\n'
                  '• SMS Gönderme: Yalnızca sizin belirlediğiniz acil durum kişilerine mesaj iletmek için.\n'
                  '• Konum: Acil durum SMS mesajına koordinat eklemek için (yalnızca cihazda işlenir).\n'
                  '• İvmeölçer (Hareket Sensörü): Sallama ile tetikleme özelliği için.\n\n'
                  'Tüm veriler yalnızca cihazınızda saklanır. Uygulamayı sildiğinizde tüm veriler kalıcı '
                  'olarak silinir.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'KULLANIM ŞARTLARI VE SORUMLULUK REDDİ',
              body:
                  'KoruBeni bir güvenlik yardımcı aracıdır; resmi bir acil servis, güvenlik şirketi veya '
                  'izleme sistemi değildir. Uygulama, acil durumlarda yetkili servisler (112, polis, vb.) '
                  'ile iletişimi desteklemek amacıyla tasarlanmıştır; onların yerine geçmez.\n\n'
                  'Kullanıcı, uygulamanın doğru çalışması için gerekli izinleri verdiğini ve cihazının '
                  'aktif bir telefon hattına sahip olduğunu kabul eder. Geliştirici (Poyraz Öncel), '
                  'teknik arızalar, ağ sorunları veya kullanıcı hatası nedeniyle acil durum '
                  'bildirimlerinin iletilememesinden doğan zararlardan sorumlu tutulamaz.\n\n'
                  'Türk Borçlar Kanunu Madde 136 kapsamında; deprem, sel, elektrik kesintisi, şebeke '
                  'arızası, işletim sistemi güncellemesi gibi mücbir sebeplerle uygulamanın '
                  'çalışmamasından doğan zararlar için geliştirici sorumlu tutulamaz.\n\n'
                  'Bu uygulama "olduğu gibi" (as-is) sunulmaktadır. Bu kullanım koşulları Türk '
                  'Hukuku\'na tabidir. Kullanım riski tamamen kullanıcıya aittir.',
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'KoruBeni v1.0 • Poyraz Öncel • 2025',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
