# Degisiklik Gunlugu

Bu dosya her yayin icin **Play "Yenilikler" metninin kaynagidir** — iki ayri
yerde iki farkli surum notu tutmak, ikisinin de yanlis olmasinin en hizli yolu.

Bicim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) tarzi.
Surumleme: `pubspec.yaml` 1.0.0+1'de SABITTIR; gercek `versionCode`
`.github/workflows/release.yml` icinde git tag'inden turer.

## Yayinlanmadi

### Duzeltildi
- Acil durum cekirdegiyle baglanti uygulama icinde kurulamadiginda panik geri
  sayimi korumali bir geri sayimdan farksiz basliyor, PIN ile iptal de
  onaylanamiyordu. Artik geri sayim baslamiyor; "Guvenlik oturumu kurulmadi"
  uyarisi acil kisiyi hemen aramak icin "Simdi Ara" dugmesiyle gosteriliyor.
- Hizli Ayarlar kutucugu, ana ekran widget'i veya ses tusuyla PIN sorulmadan
  acilan geri sayim ve arama ekrani acil kisinin tam adini gosteriyordu. Bu
  yuzeylerde ad artik yalnizca bas harfiyle (ornegin "A***") gorunuyor.
- Ayarlar ve profil ekranlarindaki, hicbir zaman doldurulamayan bos e-posta
  satiri kaldirildi. "Verilerimi disa aktar" dosyasi artik bos bir e-posta
  alani icermiyor; eski surumlerde girilmis bir e-posta, profil ekrani hic
  acilmasa bile uygulama acilisinda cihazdan siliniyor.
- Cihaz guvenligi (root) kontrolu, yapamadigi bir denetimi "cihaz guvenli"
  sayiyordu. Kontrol artik uygulamanin kendi kodunda calisiyor; okunamayan
  veya zaman asimina ugrayan her denetim "bilinmiyor" olarak yerel kayda
  geciyor ve hicbir zaman "guvenli" sonucuna donusmuyor.
- Panik butonuna basip geri sayim yuklenirken telefon hemen kilitlenirse
  acil durum oturumu ekran tekrar acilana kadar kurulmayabiliyordu. Kurulum
  artik ekran kapali olsa da en gec 300 ms icinde basliyor.
- Geri sayimda dogru PIN girilip iptal onaylandiktan sonra PIN kilit sayaci
  sifirlanamazsa ekran kapanmiyor ve kullanici uygulamayi kapatmak zorunda
  kaliyordu. Iptal artik her durumda ekrandan cikiyor.
- Platformun "animasyonlari kaldir" tercihi yedi ekranda yok sayiliyordu.
  Sonsuz nabizlar `AnimationController(...)..repeat()` insa kaskadiyla, yani
  MediaQuery okunabilir hale gelmeden basliyordu. Bastirilan nabizlar artik
  gorunur bir ara degerde park ediliyor.
- Guvenlik Gecmisi'nde bir kaydi kalici olarak silmek onay istemiyordu; tek bir
  yanlis dokunus geri alinamaz bir silme yapiyordu. Artik silinecek kaydi adiyla
  soyleyen bir onay var.
- Erisim ayarlari altindaki tasma kusuru kapatildi.
- Dokunma hedefleri 48 dp'ye cikarildi; erisilemez cevrimdisi banneri onarildi.
- Cevrimdisi banneri sayfa basligini ortuyordu; artik kapladigi yeri ayiriyor.
- Buyuk yazi tipi olceginde (1.5x ve uzeri) cevrimdisi banneri kendi
  etiketini alttan kirpiyordu; banner artik metin olcegiyle birlikte buyuyor.
- Arka plan kilidi hic tetiklenmiyordu (`AppLifecycleState.inactive` donus
  yolunda da tetikleniyor ve sayaci sifirliyordu).

### Eklendi
- `docs/audit/evidence/` altinda makine-okunur kanit artefaktlari ve her biri
  icin negatif kontrollu dogrulayicilar.
- `docs/release/incident_runbook.md`, `SECURITY.md`, bu dosya.
- Boyut x metin-olcegi matrisi (`test/screens/layout_size_matrix_test.dart`).

## 1.0.0 — ilk yayin adayi

Ilk Play Store yayin adayi. Panik butonu, geri sayim, acil kisiler, guvenli
yuruyus, prova, yerel PIN kilidi, KVKK riza akisi, cevrimdisi harita katmani.
