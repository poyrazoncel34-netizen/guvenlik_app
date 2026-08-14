# Cihaz dogrulamasi — 2026-08-14, klavye/odak/kare olcumleri

Emulator `Medium_Phone_API_36.1` (arm64, API 36, 1080x2400 @ 420dpi -> dpr 2.625).
Yapi: `flutter build apk --profile --flavor play --target-platform android-arm64`
(kare olcumleri icin PROFILE; a11y olcumleri ayni yapida). Uygulama verisi
`pm clear` ile sifirlanip onboarding bastan yururuldu, PIN 2468.

## Neden bu aletler

**`adb shell uiautomator dump` bu Flutter uygulamasinda calisiyor** ve ~36 dugumluk
gercek semantik agac veriyor: `focused`, `bounds`, `checkable`, `checked`,
`clickable`. Bu sayede "hangi dugum odakta" sorusu ekran goruntusu yorumlayarak
degil DUGUM KIMLIGIYLE yanitlandi. Bos odak ciktisi hicbir yerde "gecti" sayilmadi.

`adb shell input keyevent` modifier tasimiyor; Shift+Tab icin
`adb shell input keycombination KEYCODE_SHIFT_LEFT KEYCODE_TAB` gerekti.
Ham `sendevent` SELinux'a takiliyor (production build, `adb root` yok).

**`dumpsys gfxinfo` kare olcumu icin YANLIS alet.** Flutter icerigini kendi raster
thread'inde ciziyor; gfxinfo yalnizca HWUI'yi gorur ve bu uygulama icin 7 kare
raporladi. Dogru kaynak, uygulamanin kendi BLAST SurfaceView katmani icin
`dumpsys SurfaceFlinger --latency` present zaman damgalari.

## Odak gostergesi (MP-12-025)

Onceki tur odakli-vs-odaksiz orani 1.46:1'i olcup buna WCAG 1.4.11 demisti. O oran
WCAG 2.2 SC 2.4.13 (Focus Appearance) formulu; 1.4.11 gostergeyi KOMSU renklerle
karsilastirir. Dogru olculdugunde eski gosterge yine kaliyordu.

| Yuzey | Eski gosterge | Komsuya karsi |
|---|---|---|
| Bildirimler satiri | rgb(47,69,89) | 1.76:1 (ust), 1.46:1 (alt) |
| Profil karti | odakli = odaksiz | **1.00:1 — gosterge YOK** |
| KoruBeni Pro satiri | odakli = odaksiz | **1.00:1 — gosterge YOK** |

Profil karti ve Pro satirinda odak gercekten oradaydi (ENTER ikisini de etkinlestirdi,
Profil ve Pro ekranlari acildi); Material'in murekkep vurgusu cocugun opak arka
planinin ALTINDA kaliyordu. Bu WCAG 2.4.7 (Focus Visible) ihlali, kontrast
zayifligindan daha agir.

Duzeltme: halka cocugun USTUNE ciziliyor, iki tonlu. **Sira olcumle secildi:**

| Sira | Profil karti (parlak) | Ayar satiri (koyu) |
|---|---|---|
| koyu disda (ilk deneme) | 1.14:1 / 1.15:1 — sadece ic kenar tasiyordu | 1.02:1 / 4.98:1 |
| **primary disda (secilen)** | **7.71:1 / 10.05:1** | **5.84-8.94:1 dis sinir** |

Render edilen halka renkleri token'larla birebir: dis rgb(46,197,255) = `0x2EC5FF`
= `AppColors.focusRing`, ic rgb(10,27,42) = `AppColors.focusRingOutline`.

DURUST KAYIT: koyu satirlarda IC sinir 1.21-1.76:1 kaliyor. 1.4.11 gostergenin
komsuya karsi 3:1 olmasini ister, HER IKI kenarinin birden gecmesini degil; dis
sinir ve iki ton arasindaki 8.77:1 kenar tasiyor. Bu zayif sayi testte pinli.

## Modal odak kapsamasi (MP-12-004/005/006)

Veri silme onay modali acikken, dugum kimlikleriyle:

- TAB x6 -> yalnizca `Iptal` <-> `Cihaz Verilerini Temizle` arasinda dondu;
  arka plan dugumleri `focused=false` kaldi.
- SHIFT+TAB x5 -> ayni iki dugum ters yonde; disari kacis yok.
- Klavyeyle tam tur: TAB x5 -> `Cihaz Verilerini Temizle` odakta -> ENTER -> modal
  acildi -> ESC -> odak YINE `Cihaz Verilerini Temizle`. Tetikleyene donuyor.

Olcum sirasinda bulunan kusur: **baslangic odagi modalin icinde degildi** — modal
acikken odaklanan tek dugum kok FlutterView'di, tum semantik dugumler
`focused=false`. Iki bagimsiz modalda uretildi.

## Escape (MP-12-007) — IKI BAGIMSIZ KAPI

Ilk olcum: bildirim izni modalinde ESCAPE ekranda **0.0000** degistirdi; sistem
BACK ayni modali kapatti (**0.9996**) ve uygulama null sonucu sorunsuz isledi.
Yani modal kapanabilir, kilit kasitli degil.

**Kapi 1 — `barrierDismissible`.** Flutter'in `_DismissModalAction.isEnabled`
fonksiyonu `route.barrierDismissible` donduruyor; 14 acik `showDialog` cagrisinin
tamami `false` veriyor, eylem devre disi kaliyor. Odak eksikligi olmadigi
kanitlandi: PIN diyalogunda odak modalin ICINDEYDI (EditText `[236,669][845,816]`)
ve Escape yine 0.0000 degistirdi.

**Kapi 2 — baslangic odagi.** `ModalRoute.didPush` yalnizca `setFirstFocus` cagirir;
cevreleyen kapsamda odak yoksa odak modalin icine TASINMAZ. Dokunmatik kullanicinin
gercek durumu budur. O zaman `Actions.maybeFind` modalin kapsamindan baslamaz ve
`barrierDismissible` true OLSA BILE Escape cozulmez. Bu yuzden klavyeyle acilan
diyalog Escape'e yanit verdi, dokunarak acilan bottom sheet vermedi.

Bu ikinci kapi ILK DUZELTMEYI DE DUSURDU: `Focus(autofocus: true)` yalnizca
`FocusScope.autofocus()` ile bir NIYET kaydeder ve kapsam odak kazanmazsa hic
uygulanmaz. Widget testinde geciyordu, cihazda gecmiyordu. Kosulsuz
`requestFocus()` ile duzeltildi.

**Ilk duzeltme cihazda dustu, harness'ta gecti.** `Focus(autofocus: true)`
yalnizca `FocusScope.autofocus()` ile niyet kaydeder; kapsam odak kazanmazsa
uygulanmaz -- yani tam da duzeltmesi gereken kosulda calismiyor. Kosulsuz
`requestFocus()` ile yeniden yazildi ve testine "onceden hic odak yokken" durumu
eklendi.

**Duzeltme sonrasi olcum:** ESCAPE bildirim izni modalinde 0.9996 (once 0.0000),
kisi onam modalinde 0.9690, veri silme onayinda 0.8478.

**KAPSAM SINIRI, olculdu ve yazildi:** Escape yalnizca uygulama klavye odagini
TUTUYORSA cozuluyor. Uygulamayi salt dokunarak surup sonra Escape gondermek hala
0.0000 veriyor; tek bir TAB odagi kurunca ayni modalda Escape calisiyor (0.8478).
Bu, gereksinimin hizmet ettigi kullanici icin bir eksik degil -- donanim klavyesi
veya switch-access kullanicisi her denetime Tab ile ulasir, dolayisiyla odak
zaten kuruludur. Ama adb ile salt dokunmatik suren bir betigin neden YANLIS
NEGATIF gordugunu acikliyor ve bir dahaki sefere yeniden turetilmesin diye
kaydedildi.

Siniflandirma: `PopScope(canPop:false)` tasiyan uc modal (geri sayim iptali, acil
arama uyarisi, siren) BILEREK disarida — onlarda BACK de kapatmiyor, Escape'in de
kapatmamasi tutarlilik. `maybePop` PopScope'a saygi duydugu icin sarmalayici
yanlislikla uygulansa bile kilidi kiramaz.

## Kare sureleri (MP-09-020/021, MP-69-014/015)

PROFILE yapi, 60Hz panel, butce 16.67ms, 744 kare araligi:

| Etkilesim | ort | p90 | en kotu | >=2x butce |
|---|---|---|---|---|
| ayarlar kaydirma | 16.68 | 18.3 | 20.01 | **0** |
| ana sayfa kaydirma / fling | 16.66 | 17.0 | 17.91 | **0** |
| harita pan (en agir ekran) | 16.67 | — | 19.89 | **0** |
| alt gezinme gecisleri | 16.67 | 18.5 | 19.86 | **0** |
| ana sayfa bosta (SOS nefes) | — | — | 19.19 | **0** |

60Hz'de gercekten dusen bir kare ~33ms aralik olarak gorunur; hicbir kosumda
cikmadi. 17-20ms yayilimi emulator present-zaman jitter'i. Gecislerde p90'in
16.7 -> 18.3-18.7ms'e cikmasi tekrarlanabilir; incelendi, kare dusmesi degil.

**Yuksek tazeleme, gercek panelde.** AVD `hw.lcd.vsync=120` yapilip yeniden
baslatildi; panel `supportedRefreshRates [120.00001]`, SurfaceFlinger
`peak-refresh-rate 120.00 Hz` bildirdi. Uygulama orada da dogru ve puruzsuz
(ort 16.66ms, >=2x yok) ama **120Hz'e gecmiyor**, kararli 60fps suyor. Pil
butcesi acisindan savunulabilir bir varsayilan; kasitli olsun diye kaydedildi.
AVD olcum sonrasi 60Hz temeline geri alindi.

## Yasam dongusu (MP-47-002/025, MP-69-016/017)

Dort AYRI senaryo, karistirilmadan:

| Senaryo | Nasil | Sonuc |
|---|---|---|
| Flutter pause/resume | HOME -> geri don | pid 2225 -> 2225, ekran korundu |
| Bellek baskisi bildirimi | `am send-trim-memory` MODERATE/LOW/CRITICAL | pid ayni, cokme yok, ekran korundu |
| Activity yeniden olusturma | `always_finish_activities=1` + arka plan/on plan | pid ayni (surec yasadi), activity yikilip yeniden kuruldu, ekran dogru dondu |
| **Surec olumu** | `am kill` + yeniden baslat | pid 2225 -> 4644 (YENI surec), uygulama **PIN kilit ekranina** dondu |

Surec olumunden sonra uygulamanin kilidi ATLAMAMASI dogru davranis: zorlama
modelinde yeniden kurulan durum kilidin onune gecmemeli.

Basit bir pause/resume testinden "surec olumu guvenli" sonucu CIKARILMADI; dordu
ayri ayri kosuldu.

## Yavas CPU (MP-69-016)

Emulator TEK cekirdek gosteriyor. Dort bosa-donen surecle cekirdek %100'e
sabitlendi (`top`: 100%cpu 100%user 0%idle) ve olcum bu yukun altinda yapildi.

| Olcum | Bosta | %100 CPU yuku altinda |
|---|---|---|
| Soguk baslatma (`am start -W`, 3 kosum) | 664 / 688 / 688 ms | 3592 / 3541 / 3516 ms |
| Kare ort. | 16.67 ms | 22.88 ms |
| Kare p90 | ~17-18 ms | 33.65 ms |
| Kare en kotu | 20.01 ms | 44.48 ms |
| >=2x butce (gercek dusen kare) | %0 | **%16.1** |

Yaklasik 5.2 kat yavasladi ve kare dusurmeye BASLADI -- ama her seferinde
COKMEDEN ve ANR vermeden acildi, PIN ekranini cizdi, PIN'i kabul etti ve ana
ekrana ulasti. Panik butonu icin onemli olan budur: yavasliyor ama erisilebilir
kaliyor. Dusen kareler yumusatilmadan raporlaniyor.

Gercekten dusuk segment FIZIKSEL cihaz (yavas depolama + termal kisma) hala
kapsanmiyor; o gercek-cihaz matrisinde kaliyor.

## Oturum girdisi ve GUVENLIK BULGUSU (MP-01-021)

Kontrol listesinin senaryosu kilit/kilit-acma dongusu. Onu kosmaya calismak
gercek bir guvenlik kusuru ortaya cikardi.

**Ilk kosum.** Profil > Kisisel Bilgiler alanina "Yarim Kalan Metin" yazildi,
uygulama **141 saniye** arka planda tutuldu (esik 120 s) ve donuste
**KILIT EKRANI HIC GELMEDI**.

**Kok neden.** `AppLifecycleState.inactive` yalnizca disari cikarken degil,
`resumed`'dan hemen once GERI GIRERKEN de tetikleniyor. `emergency_trigger_host`
`onPaused()`'u `inactive` icin de cagirdigindan, donus gecisi duraklama zaman
damgasini o anki zamanla eziyordu; gecen sure ~0 hesaplaniyor ve kilit HICBIR
surede acilmiyordu. `app_privacy_shield.dart` tam bu `inactive` / `paused`
ayrimini zaten belgeliyor -- kod tabani kendisiyle celisiyordu.

Zorlama modelinde kimlik dogrulama tamamen yerel PIN'e dayandigi icin
(CLAUDE.md kural 2), hic tetiklenmeyen bir otomatik kilit gercek bir guvenlik
bulgusudur.

**Duzeltme.** `lifecycleStartsBackgroundClock()` (yalnizca paused/hidden/detached)
ve `onPaused()` icinde EN ERKEN zaman damgasinin kazanmasi.

**Duzeltme sonrasi, ayni senaryo.** 135 saniye arka plan -> PIN kilit ekrani geldi
("Uygulama kilidi. PIN ile acin."); PIN girildikten sonra uygulama Kisisel
Bilgiler ekranina dondu ve gonderilmemis metin "Kilit Testi Metni" alanda duruyordu.
Kilit, formun USTUNE bir rota olarak itildigi ve form altta bagli kaldigi icin
girdi korunuyor.

**DURUST KAYIT:** gonderilmemis girdi GERCEK SUREC OLUMUNDEN sagkurtulmuyor.
Ayrica olculdu: arka plandayken `am kill`, ardindan yeniden baslatma -> yeni pid
ve uygulama onboarding 1/5'te, yarim dolu form yok. Uygulamada Flutter durum
geri yukleme (`RestorationMixin` / `restorationScopeId`) yok. Kontrol listesinin
senaryosu kilit/kilit-acma ve o geciyor; surec olumu geri yuklemesi daha buyuk
bir degisiklik ve ima edilmek yerine adiyla yaziliyor.
