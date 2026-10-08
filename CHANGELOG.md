# Degisiklik Gunlugu

Bu dosya her yayin icin **Play "Yenilikler" metninin kaynagidir** — iki ayri
yerde iki farkli surum notu tutmak, ikisinin de yanlis olmasinin en hizli yolu.

Bicim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) tarzi.
Surumleme: `pubspec.yaml` 1.0.0+1'de SABITTIR; gercek `versionCode`
`.github/workflows/release.yml` icinde git tag'inden turer.

## Yayinlanmadi

### Duzeltildi
- Panik geri sayimi veya Test Modu provasi surerken bir baglantiyla baska
  bir ekran acilirsa, geri sayim bitince yanlislikla O ekran kapaniyordu;
  prova "0 saniye"de kalip geri tusu ve PIN ile kapatilamiyordu, gercek panikte
  ise ust uste acik kilit ekrani arama sonucu ekraniyla degistirilebiliyordu.
  Geri sayim artik yalnizca kendisini kapatiyor; geri sayim surerken gelen
  baglantilar ve odeme ekrani geri sayim bitene kadar bekliyor.
- Widget, Hizli Ayarlar veya ses tuslariyla baslatilan panikten sonra arama
  sonucu ekranindaki "bitir" dugmesi, 2 dakikadan uzun arka plandan donuste
  acilan PIN kilidini de kapatiyordu. Kilit artik yalnizca dogru PIN ile veya
  "PIN'i unuttum" ile verilerin silinmesiyle kalkiyor; kilit, calisan bir
  panik geri sayiminin ustune acilmiyor, geri sayim bitince geliyor.
- Panik geri sayiminin son aninda girilen dogru PIN, dogrulama arama baslatildiktan
  sonra bittiyse yanlis PIN sayiliyordu.
- Telefon yeniden baslarken saat agdan guncellenirse, suren bir Check-In veya
  Guvenli Yuruyus oturumunun son tarihi telefonun onceki acik kalma suresi
  kadar (gunlerce) ileri kayabiliyordu. Yeniden baslatma sonrasi son tarih
  artik saatin guncellenme sirasindan bagimsiz olarak dogru hesaplaniyor.
- Siren calarken uygulama sistem tarafindan kapatilirsa alarm ses seviyesi
  en yuksekte kaliyordu. Uygulama bir sonraki acilisinda, siz arada degistirmediyseniz,
  eski seviyeyi geri yukluyor.
- Ayni anda kaydedilen iki guvenlik olayindan biri Guvenlik Zaman
  Cizelgesi'nden dusebiliyordu.
- Guvenlik kayitlari okunamazsa Zaman Cizelgesi surekli yukleniyor gorunuyor,
  notlariniz da gosterilmiyordu. Artik notlar gosteriliyor ve listenin eksik
  olabilecegi belirtiliyor.
- Acil kisi kayitliyken hazirlik karti hala "Once acil kisini ekleyelim"
  diyordu.
- Check-In suresine veya Guvenli Yuruyus "Basla"ya iki kez hizlica dokunulunca
  oturum basladigi halde "Guvenlik oturumu kurulmadi" uyarisi cikiyordu.
- Bir ozellik icin gereken onay verilmemisken uygulama yalnizca "ilgili onay
  gereklidir" diyordu. Artik onayin nereden verilecegini (Ayarlar > Yasal
  Bilgiler & KVKK > Riza Yonetimi) soyluyor.
- Telefonun guvenli anahtar deposunda bir okuma hatasi olursa uygulama
  PIN'i (ayni sekilde acil kisileri veya PIN deneme sayacini) sessizce
  siliyor ve PIN sormadan yeni PIN kurulumunu aciyordu. Artik uygulama kilitli
  kaliyor; "Yeniden Dene" veya bilincli "Yerel Verileri Sifirla" secenegi
  sunuluyor, veri kendiliginden silinmiyor.
- Profil veya "Verilerimi Sil" ekranindan cihaz verileri silindikten sonra
  Android uygulamayi arka planda kapatip yeniden actiginda "Bir sorun olustu"
  hata ekrani geliyordu. Silme sonrasi uygulama artik her durumda ilk kurulum
  ekranina donuyor.
- Uygulama kilit ekrani (2 dakikadan uzun arka plan sonrasi PIN) acikken
  gelen bir baglanti veya bildirim dokunusu, Guvenlik Zaman Cizelgesi gibi
  ekranlari PIN sorulmadan kilidin ustunde aciyordu. Artik hedef ekran ancak
  PIN girildikten sonra aciliyor.
- Test Modu provasinda PIN iptal tuslari hic gorunmuyor, ekranda surekli
  "Guvenlik PIN'i dogrulaniyor…" yaziyordu. Prova artik PIN ile iptal
  edilebiliyor; gercek arama yapilmiyor.
- Panik geri sayimi cok nadiren, son milisaniyede arama ekranini (dialer) da
  acip ayni anda otomatik arama istegi gonderebiliyordu. Geri sayim artik
  tam suresinde bitiyor; arama zamani degismedi.
- Harita sekmesi hic acilmasa bile uygulama her acilista OpenStreetMap'ten
  harita karolari indiriyordu. Karolar artik yalnizca Harita sekmesi
  acildiginda isteniyor.
- Siren cok hizli durdurulursa telefonun alarm ses seviyesi en yuksekte
  kalabiliyordu. Alarm ses seviyesi artik her durumda eski haline donuyor.
- Panik, Check-In veya Guvenli Yuruyus suresi dolmak uzereyken telefon saati
  geri alinirsa, nadir bir zamanlamada arama istegi gonderilmeden oturum
  takili kalabiliyordu. Sure dolduysa istek artik gonderiliyor; 5 dakikadan
  fazla gecikmis bir oturum aranmiyor, bildirimle oneriliyor.
- Prova (Test Modu) iptali artik Guvenlik Zaman Cizelgesi'ne "acil durum
  iptal edildi" olarak yazilmiyor.
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
