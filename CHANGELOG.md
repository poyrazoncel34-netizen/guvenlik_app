# Degisiklik Gunlugu

Bu dosya her yayin icin **Play "Yenilikler" metninin kaynagidir** — iki ayri
yerde iki farkli surum notu tutmak, ikisinin de yanlis olmasinin en hizli yolu.

Bicim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) tarzi.
Surumleme: `pubspec.yaml` 1.0.0+1'de SABITTIR; gercek `versionCode`
`.github/workflows/release.yml` icinde git tag'inden turer.

## Yayinlanmadi

### Duzeltildi
- Check-In ekrani acikken bekleme suresine girildiginde "Uyari bildirimi
  gosterilemedi" mesaji, bildirim aslinda gosterildigi halde cikiyordu;
  Guvenli Yuruyus'teki 2 dakika uyarisi icin de ayni yanlis mesaj
  gorunebiliyordu. Uygulama sure dolmadan bir saniye kadar erken davranip
  telefonun reddettigi bir istek gonderiyordu. Artik istek tam zamaninda
  gidiyor; arama zamani degismedi.
- Panik butonuyla acilan geri sayim ekrandayken ses tusu, Hizli Ayarlar
  kutucugu veya ana ekran widget'i ikinci bir geri sayim acip gercek geri
  sayimin PIN iptal tuslarini "Guvenlik oturumu hazir degil" uyarisiyla
  ortebiliyordu. Artik ayni anda yalniz bir geri sayim acilabiliyor.
- Uygulama kapaliyken yapilan bir acil arama, uygulama sonra acildiginda
  Guvenlik Zaman Cizelgesi'ne "countdown_emergency_title" gibi cevrilmemis
  teknik metinle kaydediliyordu. Kayit artik Turkce/Ingilizce metinle
  yaziliyor.
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
- Gunler once yarida kalmis bir acil oturum kaydi, uygulama yeniden acildiginda
  yas sinirina bakilmadan aranabiliyordu. Vadesi 5 dakikayi asmis boyle bir
  kayit artik sessizce aranmiyor; kullaniciya bildirimle teklif ediliyor.
- "Verilerimi sil" ayni oturum icinde calistirildiginda silinen acil kisiler
  Kisiler ekraninda gorunmeye devam edebiliyor ve sonraki bir duzenleme eski
  listeyi geri yazabiliyordu. Silme artik ekranlardaki listeleri de bosaltiyor.
- Gecikmeli sahte cagri "zamanlandi" denmesine ragmen hic gelmiyordu: zamanlanmis
  bildirimi teslim edecek alici uygulama manifestinde yoktu. Alici eklendi;
  yeniden baslatmadan sonra da yeniden zamanlaniyor.
- Ses tusu tetikleyici Ayarlar'dan acildiginda bir sonraki uygulama donusune
  kadar hicbir sey yapmiyordu; native taraf tuslari yutuyor, uygulama tarafinda
  karsiligi calismiyordu. Tetikleyici artik acildigi anda calisiyor.
- Arka plan kilidi, guvenli depo okunamadiginda hic gosterilmiyordu (hata
  yutuluyor ve "PIN yok" sayiliyordu). Okuma hatasi artik kilit ekranina
  dusuyor.
- Panik geri sayimi calisirken, PIN bilinmeden ulasilabilen "PIN'imi unuttum"
  sifirlamasi bu oturumu iptal edebiliyordu: aktif oturum kontrolu yalnizca
  check-in ve guvenli yuruyusu goruyor, paniki gormuyordu. Kontrol artik panik
  oturumunu da kapsiyor; okunamadiginda sifirlama reddediliyor.
- PIN deneme sayaclari okunamadiginda kilit tamamen devre disi kaliyordu
  (sayac "0 hata" sayiliyor, hicbir kayit dusulmuyordu). Okunamayan sayac artik
  kilitli kabul ediliyor ve yerel kayda geciyor; "PIN'imi unuttum" erisilebilir
  kaliyor.

### Degistirildi
- Paywall ve magaza metnindeki "Gelismis guvenlik otomasyonlari" faydasi
  kaldirildi: karsiligi olan bir islev yoktu. Gercek otomasyonlar (panik/SOS,
  guvenli yuruyus, check-in, ses tusu tetikleyici) kendi maddeleriyle listeleniyor.

### Eklendi
- Guvenli depodan PIN okunamadiginda uygulama artik cikissiz bir hata
  ekraninda kalmiyor; yeniden deneme ve yazarak onaylanan yerel sifirlama
  sunan bir kurtarma ekrani geliyor.
- `docs/audit/evidence/` altinda makine-okunur kanit artefaktlari ve her biri
  icin negatif kontrollu dogrulayicilar.
- `docs/release/incident_runbook.md`, `SECURITY.md`, bu dosya.
- Boyut x metin-olcegi matrisi (`test/screens/layout_size_matrix_test.dart`).

## 1.0.0 — ilk yayin adayi

Ilk Play Store yayin adayi. Panik butonu, geri sayim, acil kisiler, guvenli
yuruyus, prova, yerel PIN kilidi, KVKK riza akisi, cevrimdisi harita katmani.
