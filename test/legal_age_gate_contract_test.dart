// Yaş kapısının kaynak sözleşmesi.
//
// NEDEN BU TEST VAR. Kullanım Sözleşmesi v4.0.0 Madde 10.1 uygulamayı yalnızca
// 18 yaşını doldurmuş kişilere açıyor ve Madde 7.1 kullanıcıya bunu beyan
// ettiriyor. Bu, dekoratif bir hüküm değil: TMK m.16 uyarınca sınırlı
// ehliyetsiz küçük, yasal temsilcisinin rızası olmadan borç altına giremez --
// yani 18 altı bir kullanıcıya karşı sözleşmenin HİÇBİR hükmü işlemez.
// Sorumluluk devrinin tamamı bu kapıya yaslanıyor.
//
// Kapı 2026-08-26'da denetlendiğinde MEVCUTTU ve doğru çalışıyordu, ama onu
// koruyan hiçbir test yoktu. Bir refaktör `_canProceed`'den yaş koşulunu
// düşürse ya da seçeneği kaldırsa, paket yeşil kalarak yayına giderdi.
//
// KASTEN DOĞUM TARİHİ İSTENMİYOR. Doğum tarihi daha güçlü delil olurdu ama
// KVKK veri minimizasyonu ilkesine aykırı düşer: yaşın 18'den büyük olduğunu
// bilmek yeterliyken tam doğum tarihi toplamak, uygulamanın gizlilik
// mimarisiyle çelişir. Olumlu beyan + tarihli kayıt bilinçli takastır.
//
// Bu bir KAYNAK sözleşmesidir (widget testi değil): kapının varlığını ve
// bağlandığı yeri pinler, pikselleri değil.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final consent = File(
    'lib/screens/legal/unified_consent_screen.dart',
  ).readAsStringSync();
  final splash = File('lib/screens/splash_screen.dart').readAsStringSync();

  group('yaş kapısı ilerlemeyi bloke eder', () {
    test('_canProceed yaş beyanını şart koşar', () {
      // Bu satır düşerse kapı sessizce açılır.
      expect(
        consent,
        contains('_selectedAgeOption != null'),
        reason: '_canProceed yaş koşulunu kaybetmiş -- '
            'kullanıcı beyan vermeden devam edebilir',
      );
    });

    test('devam butonu _canProceed ile kapalı tutuluyor', () {
      expect(
        consent,
        contains('_canProceed && !_loading ? _complete : null'),
        reason: 'Devam butonu _canProceed kapısından koparılmış',
      );
    });

    test('yalnızca "18+" seçeneği sunulur; "18 altı" seçilebilir bir yol değil', () {
      // legal_age_minor metinleri sözlükte duruyor ama BU EKRANDA
      // render EDİLMEMELİ: seçilebilir bir "18 altındayım" yolu, kapıyı
      // tek tıkla geçilen bir forma çevirir.
      expect(consent, contains("'legal_age_adult'"));
      expect(
        consent,
        isNot(contains("'legal_age_minor'")),
        reason: 'Bu ekrana seçilebilir bir 18-altı seçeneği eklenmiş',
      );
    });
  });

  group('beyan ispatlanabilir şekilde kaydedilir', () {
    test('tarihli rıza kaydı yazılıyor', () {
      // İspat yükü satıcıda (TKHK m.10) ve illiyet bağının kesildiğini
      // ispat da sorumluda (Yargıtay HGK). Kayıt olmadan beyan savunmada
      // kullanılamaz.
      expect(
        consent,
        contains("grantConsent('age_verification'"),
        reason: 'Yaş beyanı artık rıza kaydına yazılmıyor -- ispatlanamaz',
      );
    });

    test('kalıcı bayrak yazılıyor', () {
      expect(consent, contains('prefAgeVerified'));
    });
  });

  group('kapı tek canlı yasal yolda duruyor', () {
    test('splash yeniden onay dahil UnifiedConsentScreen kullanır', () {
      // Kapı yalnızca bu ekranda. Splash başka bir onay ekranına yönelirse
      // yaş beyanı atlanabilir hale gelir.
      expect(splash, contains('UnifiedConsentScreen'));
      // Eski ekranin DOSYASINA atif aranir, sinif adina degil:
      // 'UnifiedConsentScreen(' zaten 'ConsentScreen(' alt dizgesini icerir,
      // dolayisiyla sinif adiyla yapilan negatif kontrol her zaman kirmizi
      // verirdi -- ilk yazimda tam olarak bu oldu.
      expect(
        splash,
        isNot(contains('legal/consent_screen.dart')),
        reason: 'Splash yaş kapısı olmayan eski onay ekranını import etmiş',
      );
      expect(
        splash,
        isNot(contains('legal_disclaimer_screen.dart')),
        reason: 'Splash eski yasal uyarı ekranına yönelmiş',
      );
    });
  });

  group('sözleşme ile arayüz aynı yaşı söyler', () {
    test('TR ve EN metinleri 18 beyanını taşır', () {
      for (final path in const [
        'assets/translations/tr-TR.json',
        'assets/translations/en-US.json',
      ]) {
        final map =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        expect(
          map['legal_age_adult'],
          contains('18'),
          reason: '$path: yaş etiketi 18 demiyor',
        );
        // Beyanın doğruluğunun kullanıcıda olduğu bildirimi, sözleşme
        // Madde 7.1 ile aynı şeyi söylemek zorunda.
        expect(
          (map['legal_age_notice'] as String).toLowerCase(),
          anyOf(contains('sorumlu'), contains('responsible')),
          reason: '$path: yaş bildirimi sorumluluğu kullanıcıya bağlamıyor',
        );
      }
    });
  });
}
