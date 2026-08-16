# Gorsel cila gecisi — emulator, 2026-08-16 (MP-72 ailesi)

Bu kayit, `MP-72-002`, `MP-72-004`..`MP-72-014` ve `MP-72-016` satirlarinin
**"sistematik ekran ekran cila gecisi YAPILMADI"** gerekcesini kaldirmak icin
yapilan gecisin sonucudur. Onceki durum, denetimin kendi standardina gore
gecersiz bir gerekceydi: "yapilmadi" bir dis bagimlilik degildir.

Satirlarin onceki remediation'i **golden test** oneriyordu. Golden testler bu
depoda yasak (`.claude/rules/dart/testing.md`: "NOT used: ... golden tests"),
yani satirlar depoda uygulanmayan bir cozumun arkasina park edilmisti. Golden
gerekmeden olculebilen ne varsa burada olculdu; olculemeyen kismin gerekcesi
`MP-69-012/013` ile ayni bicimde, **gercek panel** olarak yazildi.

## Ortam

| Alan | Deger |
|---|---|
| Cihaz | Android emulator, AVD `Medium_Phone_API_36.1` |
| API | 36 |
| Cozunurluk / yogunluk | 1080x2400, **420 dpi** (`wm size`, `wm density`) |
| Paket | `com.poyrazoncel.korubeni` (play flavor, debug) |
| Kurulum | TEMIZ (`adb uninstall` sonrasi yeniden kurulum) |
| Tarih | 2026-08-16 |
| Yontem | Bastan sona onboarding surusu + her sekmenin tam ekran yakalamasi, ardindan yakalamalarin tek tek incelenmesi |

## Incelenen yuzeyler (8)

1. Kurulum ve Onay (yasal/riza) — ust ve alt kaydirma konumlari
2. Onboarding tanitim kartlari (5 sayfa)
3. Acil kisi adimi — bos, dolu ve **basari** durumlari
4. `Kisi Ekleme Onayi` dialogu — pasif ve aktif buton durumlari
5. PIN belirleme ve PIN tekrar ekranlari
6. Pil optimizasyonu sihirbazi (3 butonlu yigin)
7. Ana Sayfa — **cevrimdisi** ve **cevrimici** durumlarda
8. Harita / Kisiler / Ayarlar sekmeleri

## Sonuclar

| # | Satir | Madde | Sonuc |
|---|---|---|---|
| 1 | MP-72-005 | Kose yaricapi tutarliligi | **KUSUR YOK** — kart yaricaplari tum yuzeylerde ayni aileden; ikon kutucuklari kendi icinde tutarli |
| 2 | MP-72-010 | Buton etiketi ortalama | **KUSUR YOK** — ikonlu ve ikonsuz butonlarda etiket optik olarak ortali |
| 3 | MP-72-011 | Avatar kirpilmasi | **KUSUR YOK** — Kisiler kartindaki ve Ayarlar profilindeki dairesel avatarlar kirpilmiyor |
| 4 | MP-72-012 | Gorsel en-boy orani | **KUSUR YOK** — uygulama fotografik gorsel kullanmiyor; tum grafikler vektor ikon |
| 5 | MP-72-004 | Esit olmayan kart yuksekligi | **KUSUR YOK** — ayni listedeki kartlar icerige gore buyuyor, keyfi fark yok |
| 6 | MP-72-007 | Ikon optik hizalama | **KUSUR YOK** — liste ikonlari ve chevron'lar sabit x'te hizali |
| 7 | MP-72-008 | Ikon cizgi kalinligi | **KUSUR YOK** — tek aile (Material Rounded) kullaniliyor, karisim yok |
| 8 | MP-72-009 | Ikon agirligi | **KUSUR YOK** — ayni |
| 9 | MP-72-002 | 1px kenarlik tutarsizligi | **PANEL GEREKIR** — 420 dpi'da hairline kenarliklar tutarli goruntulendi, ama 1px'in *rasterizasyonu* panelin kendi ozelligidir |
| 10 | MP-72-006 | Metin taban cizgisi | **PANEL GEREKIR** — tek yogunlukta sapma gorulmedi; alt-piksel taban cizgisi farki bu yakalamada olculemez |
| 11 | MP-72-013 | Bulanik varliklar | **PANEL GEREKIR** — 420 dpi (xxhdpi) temiz; diger yogunluk kovalari bu cihazda uretilemez |
| 12 | MP-72-014 | Yanlis cozunurluk | **PANEL GEREKIR** — ayni gerekce |
| 13 | MP-72-016 | Gradyan bantlanmasi | **PANEL GEREKIR** — emulator kare tamponu gercek panelin bit derinligini ve dithering'ini yeniden uretmez |

**8 madde kapandi, 5 madde icin geriye kalan tek sey gercek panel.** Bu ayrim
`MP-69-012/013` ile ayni mantiktir: mantiksal yuzey olculur, fiziksel panel
olculemez.

## YENI KUSUR — cevrimdisi banner sayfa basligini ortuyor

Bu gecisin bulmak icin var oldugu sey. Iki yakalama arasindaki tek fark
baglantidir:

| Durum | Gozlem |
|---|---|
| **Cevrimdisi** (banner gorunur) | `Hos Geldiniz` basliginin ust ~%55'i amber banner'in altinda kaliyor |
| **Cevrimici** (banner yok) | Ayni baslik, ayni kaydirma konumu, **tam ve dogru** goruntuleniyor |

Kaydirma artefakti degildir: liste en uste kaydirildiktan sonra da ayni.

**Mekanizma, kaynakta dogrulandi.**
[`lib/screens/main_navigation.dart:287-292`](../../lib/screens/main_navigation.dart)
banner'i bir `Stack` icinde `Positioned(top: 0)` ile, sayfalari tutan
`IndexedStack`'in **ustune** bindirir. `Positioned` yerlesimde yer kaplamaz,
dolayisiyla altindaki sayfa banner'in yuksekligi kadar bir bosluk ayirmaz.
Banner'in yuksekligi
[`lib/widgets/connectivity_banner.dart:88-95`](../../lib/widgets/connectivity_banner.dart)
icinde `statusBarInset + 12 + icerik + 12`, yani durum cubugunun altinda
yaklasik **42 dp**'dir. Banner gorunurken her sekmenin ilk 42 dp'si ortulur.

- **Kapsam:** uygulama kabugu — dort sekmenin hepsi, yalnizca cevrimdisi durumda.
- **Siddet:** kozmetik (P3). Ortulen ogeler etkilesimli degil; hicbir kontrol
  erisilemez hale gelmiyor ve acil cagri yolu etkilenmiyor.
- **Neden bu gecise kadar gorulmedi:** onceki yurutmeler cevrimici emulatorde
  yapilmisti, banner hic gorunmedi.

**Depoda cozulebilir.** Duzeltme, banner gorunurken icerige banner yuksekligi
kadar ust bosluk vermektir; `ConnectivityService.instance.onStatusChange` zaten
paylasilan kaynaktir, yani ikinci bir durum makinesi gerekmez.

### Duzeltildi ve cihazda dogrulandi (ayni gun, kendi commit'inde)

Degisiklik uygulama kabugunu ve dort sekmenin hepsini birden etkiledigi icin
denetim remediation yiginina karistirilmadi; `PRODUCT_DECISIONS_REQUIRED.md`
D-2'nin ayni sinif icin yazdigi standarda uyularak **kendi commit'i ve kendi
cihaz gecisi** ile yapildi.

- `lib/widgets/connectivity_banner.dart`: banner'in geometrisi
  (`verticalPadding`, `contentHeight`, `reservedHeight`) sabit olarak disari
  acildi ve banner kendi dolgusunda bu sabitleri kullaniyor. `contentHeight`,
  satirin zaten olctugu deger olan `IconSizes.dense`'tir (en uzun cocuk bastaki
  glif), yani bu **mevcut gorunumu sabitler, degistirmez**.
- `lib/screens/main_navigation.dart`: kabuk, banner gorunurken icerige
  `ConnectivityBanner.reservedHeight` kadar ust bosluk ayiriyor
  (`AnimatedPadding`, banner ile ayni `Motion.base` suresi). Cevrimdisi durumu
  banner'in dinledigi ayni kaynaktan (`ConnectivityService.instance`) okunuyor;
  banner'dan parent'a callback ile tasinmadi, cunku bir kare gecikmeli callback
  tam da bu ortusmeyi geri getirirdi.
- Ayrilan yukseklik durum cubugunu **icermez**: sayfalar kendi SafeArea'lari ile
  zaten durum cubugunun altinda basliyor, dolayisiyla inset'i ikinci kez
  saymak her sayfayi fazladan asagi iterdi.

**Cihaz dogrulamasi (2026-08-16, ayni AVD, ucak modu ACIK):** banner gorunur
durumdayken **dort sekmenin dordunde de** ust icerik tam ve kirpilmamis:

| Sekme | Ust oge | Duzeltme oncesi | Duzeltme sonrasi |
|---|---|---|---|
| Ana Sayfa | `Hos Geldiniz` basligi | ust ~%55'i banner altinda | **tam** |
| Kisiler | `Acil Kisiler` baslik cubugu | ortuluyordu | **tam** |
| Harita | `Harita` baslik hapi | ortuluyordu | **tam**, bosluk ya da hizalama kaymasi yok |
| Ayarlar | `Ayarlar` basligi | ortuluyordu | **tam** |

Harita ozellikle kontrol edildi: tam ekran bir yuzey oldugu icin ayrilan
yuksekligin orada bir bosluk birakma riski vardi; birakmiyor. Ilk kosumda
yalnizca Ana Sayfa dogrulanmisti ve satir da yalnizca onu iddia ediyordu;
kalan uc sekme, iddiayi genisletmek icin degil, **kabuk capinda bir degisikligin
tek sekmede dogrulanmasi yeterli sayilmasin diye** ayrica kosuldu.

Regresyon testi: `test/screens/connectivity_banner_reserves_space_test.dart`.
Testin sabitledigi sey duzeltmenin kendisi degil, onu dogru kilan OZELLIK'tir:
kabugun ayirdigi yukseklik ile banner'in bastigi yukseklik tek bir sabit
kumesinden turer ve ayrilan yukseklik durum cubugunun ALTINDAKI yuksekliktir.

## Ek gozlem (kusur degil)

PIN belirleme ile PIN tekrar ekranlari arasinda tus takimi dikey olarak kayiyor,
cunku iki ekranin aciklama metni farkli uzunlukta. Islevsel bir sorun degil ve
listedeki 13 maddeden hicbirine girmiyor; ayni kontrolun iki adimi arasindaki
konum kaymasi olarak buraya not edildi.

## Metin olcegi bulgusu ve duzeltmesi (CERT2-03, 2026-08-16)

Bagimsiz sertifikasyon gecisi banner duzeltmesini **1.5x metin olceginde** yeniden
kostu ve bir kusur buldu: banner'in KENDI etiketi (`Cevrimdisi Mod`) alttan
yaklasik %40 kirpiliyordu. Sebep, duzeltmenin getirdigi sabit yukseklikti --
`SizedBox(height: IconSizes.dense)` = 16 dp. Yorum satiri "en uzun cocuk oncu
glif" diyordu; bu YALNIZCA olcek 1.0'da dogru. `main.dart` Android font
olceklemesini 2.0x'e kadar koruyor ve 13 px etiket 1.5x'te ~23.4 dp istiyor, yani
kutu bir kayit olmaktan cikip kirpici haline geliyordu.

Sayfanin konumu her iki olcekte de DOGRUYDU; kirpilan sey banner'in kendi
icerigiydi.

Duzeltme: `contentHeightFor(context)` / `reservedHeightFor(context)` metin
olceginden turer, kabuk de ayni fonksiyonu okur. Olcek 1.0'da tek piksel
degismez (13 x 1.2 = 15.6 < 16 dp ikon tabani).

| Olcek | Duzeltme oncesi | Duzeltme sonrasi |
|---|---|---|
| 1.0 | etiket tam | **tam** (piksel ayni) |
| 1.5 | etiket alttan ~%40 kirpik | **tam**, `Hos Geldiniz` de tam |

## Kanit saglamasi — YAPI PARMAK IZI ZORUNLU

Bu gecis sirasinda gercek bir tuzak yasandi: sertifikasyon once cihazda KURULU
olan yapiyi kostu, o yapi `d223d95` duzeltmesinden **4 saat once** kurulmustu ve
duzeltme ONCESI kusuru aynen uretti. Kusur koda degil, bayat APK'ya aitti.

Bu yuzden bundan sonra her cihaz dogrulama notu su alanlari tasir; yoksa
"cihazda dogrulandi" cumlesi dogrulanabilir degildir:

| Alan | Bu kayit icin |
|---|---|
| AVD | `Medium_Phone_API_36.1` (ilk gecis), `KoruBeni_API36_16k_ctrl` (CERT2-03 tekrar kosumu) |
| Yogunluk | 1080x2400, 420 dpi |
| Olculen commit | `d223d95` (banner duzeltmesi), CERT2-03 kosumu icin duzeltme sonrasi agac |
| APK kurulum zamani | `adb shell dumpsys package <id> \| grep lastUpdateTime` ile teyit edilir |
| Yontem | `flutter build apk --debug --flavor play` -> `adb install -r` -> ekran yakalama |

Kural: **olculen commit ile kurulu APK'nin zamani celisiyorsa kayit gecersizdir.**
